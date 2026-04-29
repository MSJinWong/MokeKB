from django.db import migrations, models


def backfill_workspace_id(apps, schema_editor):
    """从 Knowledge 表回填 workspace_id 到 Embedding。
    按 knowledge_id 分批，每个 knowledge_id 一个事务，避免单一长事务在大表上阻塞写入。
    """
    conn = schema_editor.connection
    with conn.cursor() as c:
        c.execute(
            "SELECT DISTINCT knowledge_id FROM embedding "
            "WHERE workspace_id IS NULL OR workspace_id = 'default'"
        )
        kids = [r[0] for r in c.fetchall()]
    for kid in kids:
        with conn.cursor() as c:
            c.execute(
                """
                UPDATE embedding
                   SET workspace_id = COALESCE(
                       (SELECT workspace_id FROM knowledge WHERE id = %s),
                       'default')
                 WHERE knowledge_id = %s
                   AND (workspace_id IS NULL OR workspace_id = 'default')
                """,
                [kid, kid],
            )


class Migration(migrations.Migration):

    atomic = False  # chunk-by-chunk commit prevents long-held locks on large tables

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
