"""공개 배포 버전을 로컬 산출물과 비교한다. 인증이나 사용자 진행은 사용하지 않는다."""
import json
import ssl
import sys
import urllib.request
from pathlib import Path

base = sys.argv[1].rstrip("/")
context = ssl.create_default_context()
if sys.platform == "darwin":
    context = ssl.create_default_context(cafile="/etc/ssl/cert.pem")


def request(path, method="GET"):
    return urllib.request.urlopen(
        urllib.request.Request(base + path, method=method), context=context, timeout=30
    )


with request("/build-info.json") as response:
    actual = json.load(response)
expected = json.loads(Path("builds/web/build-info.json").read_text())
if actual != expected:
    raise SystemExit("공개 웹 버전이 이번 빌드와 다릅니다.")
manifest = Path("builds/web/deployment.json")
if manifest.exists():
    with request("/deployment.json") as response:
        if json.load(response) != json.loads(manifest.read_text()):
            raise SystemExit("공개 배포 커밋/실행 정보가 이번 배포와 다릅니다.")
with request("/api/v1/health/") as response:
    health = json.load(response)
if health.get("status") != "ok" or health.get("database") != "ok":
    raise SystemExit("공개 API/DB 상태 확인 실패")
for path in ("/play.html", "/index.pck", "/camping-intro.mp4"):
    with request(path, "HEAD") as response:
        if response.status != 200:
            raise SystemExit(f"파일 응답 오류: {path}")
print("PASS public web version / API / database / game files / intro video")
