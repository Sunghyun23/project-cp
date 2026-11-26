import hashlib
import secrets
from django.db import connection, transaction
from django.db.utils import OperationalError
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import PrototypeSession
from .rules import initial_state, transition


def digest(token):
    return hashlib.sha256(token.encode()).hexdigest()


def session_for(request, lock=False):
    token = request.headers.get("Authorization", "").removeprefix("Bearer ")
    query = PrototypeSession.objects.select_for_update() if lock else PrototypeSession.objects
    return query.get(token_hash=digest(token))


def payload(session):
    return {"state": session.state, "version": session.version}


@api_view(["GET"])
def health(request):
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except OperationalError:
        return Response({"status": "unavailable"}, status=503)
    return Response({"status": "ok", "database": "ok"})


@api_view(["POST"])
def create_session(request):
    token = secrets.token_urlsafe(32)
    session = PrototypeSession.objects.create(token_hash=digest(token), state=initial_state())
    return Response({"token": token, **payload(session)}, status=201)


@api_view(["GET"])
def state(request):
    try:
        return Response(payload(session_for(request)))
    except PrototypeSession.DoesNotExist:
        return Response({"error": "테스트 세션을 찾을 수 없어요."}, status=401)


@api_view(["POST"])
@transaction.atomic
def action(request):
    if not isinstance(request.data, dict):
        return Response({"error": "행동 형식이 올바르지 않아요."}, status=400)
    try:
        session = session_for(request, lock=True)
    except PrototypeSession.DoesNotExist:
        return Response({"error": "테스트 세션을 찾을 수 없어요."}, status=401)
    if request.data.get("version") != session.version:
        return Response({"error": "다른 요청이 먼저 저장됐어요. 다시 불러와 주세요."}, status=409)
    try:
        session.state = transition(session.state, request.data.get("command"), request.data.get("choice", ""))
    except ValueError as exc:
        return Response({"error": str(exc)}, status=400)
    session.version += 1
    session.save()
    return Response(payload(session))
