from django.db import migrations


class Migration(migrations.Migration):

    # CONCURRENTLY 不能在事务里跑，必须关掉 atomic
    atomic = False

    dependencies = [
        ('knowledge', '0009_embedding_workspace_id'),
    ]

    operations = [
        migrations.RunSQL(
            sql=[
                # 检索热路径：knowledge_id + is_active + source_type
                """CREATE INDEX CONCURRENTLY IF NOT EXISTS embedding_kid_active_stype_idx
                   ON embedding (knowledge_id, is_active, source_type)""",
                # 删除/统计热路径：document_id
                """CREATE INDEX CONCURRENTLY IF NOT EXISTS embedding_document_id_idx
                   ON embedding (document_id)""",
                # paragraph_id（已有 FK 但建独立索引便于反查）
                """CREATE INDEX CONCURRENTLY IF NOT EXISTS embedding_paragraph_id_idx
                   ON embedding (paragraph_id)""",
                # GIN: 关键词检索（大表上同步建会长时间锁写）
                """CREATE INDEX CONCURRENTLY IF NOT EXISTS embedding_search_vector_gin
                   ON embedding USING gin (search_vector)""",
            ],
            reverse_sql=[
                "DROP INDEX CONCURRENTLY IF EXISTS embedding_kid_active_stype_idx",
                "DROP INDEX CONCURRENTLY IF EXISTS embedding_document_id_idx",
                "DROP INDEX CONCURRENTLY IF EXISTS embedding_paragraph_id_idx",
                "DROP INDEX CONCURRENTLY IF EXISTS embedding_search_vector_gin",
            ],
        ),
    ]
