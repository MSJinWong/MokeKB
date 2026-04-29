from django.db import migrations


class Migration(migrations.Migration):

    atomic = False  # CREATE INDEX CONCURRENTLY 不能在事务中

    dependencies = [
        ('knowledge', '0007_remove_knowledgeworkflowversion_workflow_and_more'),
    ]

    operations = [
        migrations.RunSQL(
            sql=[
                """CREATE INDEX CONCURRENTLY IF NOT EXISTS file_sha256_hash_idx
                   ON file (sha256_hash)
                   WHERE sha256_hash <> ''""",
            ],
            reverse_sql=[
                "DROP INDEX IF EXISTS file_sha256_hash_idx",
            ],
        ),
    ]
