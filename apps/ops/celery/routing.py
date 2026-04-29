"""
Celery 任务到队列的映射表。

任务名 prefix（celery_app.task 中 name= 字段的前缀）-> 队列名。
未匹配的回落到默认 'celery' 队列，兼容老部署。
"""
import os

# 任务名前缀 -> 队列后缀
TASK_NAME_PREFIX_TO_QUEUE = {
    'celery:embedding_': 'rag_embedding',
    'celery:sync_web_': 'rag_parse',
    # Exact-name match: 同类工作流但不共用 sync_web_ 前缀
    'celery:sync_replace_web_knowledge': 'rag_parse',
    'celery:generate_related_': 'rag_embedding',
    'celery:create_knowledge_index': 'rag_index',
    'celery:drop_knowledge_index': 'rag_index',
    'celery:deploy_scheduled_trigger': 'maintenance',
    'celery:undeploy_scheduled_trigger': 'maintenance',
}

DEFAULT_QUEUE = 'celery'

QUEUE_KEYS = sorted(set(TASK_NAME_PREFIX_TO_QUEUE.values())) + [DEFAULT_QUEUE]


def queue_for_task(task_name: str) -> str:
    """
    给定任务名，返回它该进入的队列名。

    若 MAXKB_TASK_QUEUE_PREFIX_ENABLED 环境变量未设置/为假值，强制返回 DEFAULT_QUEUE
    （兼容老部署：所有任务进 celery 队列）。
    若设置了开关，按 TASK_NAME_PREFIX_TO_QUEUE 路由；未匹配回落 DEFAULT_QUEUE。
    """
    if not os.environ.get('MAXKB_TASK_QUEUE_PREFIX_ENABLED'):
        return DEFAULT_QUEUE
    for prefix, queue in TASK_NAME_PREFIX_TO_QUEUE.items():
        if task_name.startswith(prefix):
            return queue
    return DEFAULT_QUEUE


def task_router(name, args, kwargs, options, task=None, **kw):
    """Celery task router callable: returns a routing dict per Celery's API."""
    return {'queue': queue_for_task(name)}


def all_queues() -> list:
    """All queue names this app knows about (used to declare Queue objects)."""
    return QUEUE_KEYS
