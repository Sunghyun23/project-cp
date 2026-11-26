from django.urls import path
from prototype import views

urlpatterns = [
    path("api/v1/health/", views.health),
    path("api/v1/prototype/sessions/", views.create_session),
    path("api/v1/prototype/state/", views.state),
    path("api/v1/prototype/actions/", views.action),
]
