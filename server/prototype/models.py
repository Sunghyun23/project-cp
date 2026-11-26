from django.db import models


class PrototypeSession(models.Model):
    token_hash = models.CharField(max_length=64, unique=True)
    state = models.JSONField()
    version = models.PositiveIntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)
