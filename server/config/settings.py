import os

SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
DEBUG = False
ALLOWED_HOSTS = ["localhost", "127.0.0.1", "api", "testserver"]
INSTALLED_APPS = ["django.contrib.contenttypes", "rest_framework", "prototype"]
MIDDLEWARE = ["django.middleware.security.SecurityMiddleware", "django.middleware.common.CommonMiddleware"]
ROOT_URLCONF = "config.urls"
DATABASES = {"default": {
    "ENGINE": "django.db.backends.postgresql",
    "HOST": os.environ.get("DB_HOST", "db"),
    "PORT": os.environ.get("DB_PORT", "5432"),
    "NAME": os.environ.get("POSTGRES_DB", "camping"),
    "USER": os.environ.get("POSTGRES_USER", "camping"),
    "PASSWORD": os.environ["POSTGRES_PASSWORD"],
    "OPTIONS": {"connect_timeout": 5},
}}
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
REST_FRAMEWORK = {"UNAUTHENTICATED_USER": None, "DEFAULT_AUTHENTICATION_CLASSES": [], "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"]}
