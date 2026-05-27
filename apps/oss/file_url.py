# coding=utf-8
"""OSS 文件 URL 拼接 / 解析工具。

集中维护 ``oss/file/<id>`` 在前端可访问的写入格式，避免散落在
serializer / handler / step-node 各处的 f-string 各自演化。
"""
import re

from maxkb.const import CONFIG

# 老格式（``./oss/file/<id>``）与新格式（``/<prefix>/api/oss/file/<id>``）通吃
_FILE_URL_PATTERN = re.compile(r'(?:^|[(\s"\'/])(?:\./|/)?(?:[\w-]+/)*oss/file/(?P<file_id>[\w-]+)')


def build_file_url(file_id, scope_prefix: str | None = None) -> str:
    """根据调用入口生成 oss 文件的可访问 URL。

    没有 request 上下文（知识库解析、tool icon、AI 多媒体生成等）默认走 chat 入口——
    chat 网关在所有部署形态下都对外可达，且 admin / chat 两端浏览器都能命中后端
    ``oss.retrieval_urls`` 注册的 ``(.*)/oss/file/<id>``。
    """
    if scope_prefix is None:
        scope_prefix = CONFIG.get_chat_path()
    return f'{scope_prefix}/api/oss/file/{file_id}'


def extract_file_id(text: str) -> str | None:
    """从 ``./oss/file/<id>`` 或 ``/<prefix>/api/oss/file/<id>`` 中提取 file_id。

    兼容历史 markdown 内容里残留的相对路径。
    """
    if not text:
        return None
    match = _FILE_URL_PATTERN.search(text)
    return match.group('file_id') if match else None
