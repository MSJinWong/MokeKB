# Data migration: remove stale rows that reference the removed `model_local_provider`.
from django.db import migrations


def drop_local_model_rows(apps, schema_editor):
    Model = apps.get_model('models_provider', 'Model')
    Model.objects.filter(provider='model_local_provider').delete()


def noop_reverse(apps, schema_editor):
    return


class Migration(migrations.Migration):
    dependencies = [
        ('models_provider', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(drop_local_model_rows, reverse_code=noop_reverse),
    ]
