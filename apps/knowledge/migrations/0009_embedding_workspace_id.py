from django.db import migrations, models


def backfill_workspace_id(apps, schema_editor):
    """从 Knowledge 表回填 workspace_id 到 Embedding。"""
    with schema_editor.connection.cursor() as c:
        c.execute("""
            UPDATE embedding
               SET workspace_id = COALESCE(k.workspace_id, 'default')
              FROM knowledge k
             WHERE embedding.knowledge_id = k.id
               AND (embedding.workspace_id IS NULL OR embedding.workspace_id = 'default')
        """)


class Migration(migrations.Migration):

    dependencies = [
        ('knowledge', '0008_file_sha256_index'),
    ]

    operations = [
        migrations.AddField(
            model_name='embedding',
            name='workspace_id',
            field=models.CharField(default='default', db_default='default', max_length=64,
                                   db_index=True, verbose_name='工作空间id'),
        ),
        migrations.RunPython(backfill_workspace_id, reverse_code=migrations.RunPython.noop),
        # 双保险：Django 5.2 的 db_default 应该已 SET DEFAULT，但显式再写一次确保
        migrations.RunSQL(
            sql="ALTER TABLE embedding ALTER COLUMN workspace_id SET DEFAULT 'default'",
            reverse_sql="ALTER TABLE embedding ALTER COLUMN workspace_id DROP DEFAULT",
        ),
    ]
