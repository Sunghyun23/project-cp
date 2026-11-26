from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True
    dependencies = []
    operations = [migrations.CreateModel(name="PrototypeSession", fields=[
        ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
        ("token_hash", models.CharField(max_length=64, unique=True)),
        ("state", models.JSONField()),
        ("version", models.PositiveIntegerField(default=0)),
        ("updated_at", models.DateTimeField(auto_now=True)),
    ])]
