# coding=utf-8
"""
HNSW 索引异步构建/删除任务，路由到 rag_index 队列（split 部署）或默认 celery 队列（单队列模式）。
"""
from celery_once import QueueOnce

from common.utils.logger import maxkb_logger
from ops import celery_app


@celery_app.task(base=QueueOnce, once={'keys': ['knowledge_id']},
                 name='celery:create_knowledge_index')
def create_knowledge_index_task(knowledge_id):
    from knowledge.serializers.common import create_knowledge_index
    try:
        create_knowledge_index(knowledge_id=knowledge_id)
    except Exception as e:
        maxkb_logger.error(f'create_knowledge_index_task failed knowledge_id={knowledge_id}: {e}')


@celery_app.task(name='celery:drop_knowledge_index')
def drop_knowledge_index_task(knowledge_id):
    from knowledge.serializers.common import drop_knowledge_index
    try:
        drop_knowledge_index(knowledge_id=knowledge_id)
    except Exception as e:
        maxkb_logger.error(f'drop_knowledge_index_task failed knowledge_id={knowledge_id}: {e}')
