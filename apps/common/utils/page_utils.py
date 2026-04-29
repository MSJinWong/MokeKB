# coding=utf-8
"""
    @project: MaxKB
    @Author：虎
    @file： page_utils.py
    @date：2024/11/21 10:32
    @desc:
"""
from math import ceil


def page(query_set, page_size, handler, is_the_task_interrupted=lambda: False):
    """

    @param query_set: 查询query_set
    @param page_size: 每次查询大小
    @param handler:   数据处理器
    @param is_the_task_interrupted: 任务是否被中断
    @return:
    """
    query = query_set.order_by("id")
    count = query_set.count()
    for i in range(0, ceil(count / page_size)):
        if is_the_task_interrupted():
            return
        offset = i * page_size
        paragraph_list = query.all()[offset: offset + page_size]
        handler(paragraph_list)


def page_desc(query_set, page_size, handler, is_the_task_interrupted=lambda: False):
    """

    @param query_set: 查询query_set
    @param page_size: 每次查询大小
    @param handler:   数据处理器
    @param is_the_task_interrupted: 任务是否被中断
    @return:
    """
    query = query_set.order_by("id")
    count = query_set.count()
    for i in sorted(range(0, ceil(count / page_size)), reverse=True):
        if is_the_task_interrupted():
            return
        offset = i * page_size
        paragraph_list = query.all()[offset: offset + page_size]
        handler(paragraph_list)


def page_keyset(query_set, page_size, handler, key_field='id', is_the_task_interrupted=lambda: False):
    """
    用 keyset 取代 offset 的批处理迭代。要求 key_field 单调递增（通常 uuid7 / 自增 id）。

    @param query_set:                 查询 query_set。不要事先 order_by；如果用了 .values(...)，确保
                                      key_field 在 values 列表里。
    @param page_size:                 每次查询大小
    @param handler:                   数据处理器，接收一页 list
    @param key_field:                 排序字段，默认 'id'
    @param is_the_task_interrupted:   任务是否被中断的回调
    """

    def _get_key(row):
        # 同时兼容 dict（.values() 出来）与 model 实例
        if isinstance(row, dict):
            return row[key_field]
        return getattr(row, key_field)

    last_value = None
    while not is_the_task_interrupted():
        qs = query_set.order_by(key_field)
        if last_value is not None:
            qs = qs.filter(**{f'{key_field}__gt': last_value})
        rows = list(qs[:page_size])
        if not rows:
            return
        handler(rows)
        last_value = _get_key(rows[-1])
        if len(rows) < page_size:
            return
