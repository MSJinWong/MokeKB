# coding=utf-8
"""
    @project: maxkb
    @file： init_doc.py
"""
from django.urls import path, URLPattern
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from maxkb.const import CONFIG

chat_api_prefix = CONFIG.get_chat_path()[1:] + '/api/'


def init_app_doc(system_urlpatterns):
    system_urlpatterns += [
        path(f'{CONFIG.get_admin_path()[1:]}/api-doc/schema/', SpectacularAPIView.as_view(), name='schema'),
        path(f'{CONFIG.get_admin_path()[1:]}/api-doc/', SpectacularSwaggerView.as_view(url_name='schema'),
             name='swagger-ui'),
    ]


class ChatSpectacularSwaggerView(SpectacularSwaggerView):
    @staticmethod
    def _swagger_ui_resource(filename):
        return f'{CONFIG.get_chat_path()}/api-doc/swagger-ui-dist/{filename}'

    @staticmethod
    def _swagger_ui_favicon():
        return f'{CONFIG.get_chat_path()}/api-doc/swagger-ui-dist/favicon-32x32.png'


def init_chat_doc(system_urlpatterns, chat_urlpatterns):
    system_urlpatterns += [
        path(f'{CONFIG.get_chat_path()[1:]}/api-doc/schema/',
             SpectacularAPIView.as_view(patterns=[
                 URLPattern(pattern=f'{chat_api_prefix}{str(url.pattern)}', callback=url.callback,
                            default_args=url.default_args,
                            name=url.name) for url in chat_urlpatterns if
                 ['chat', 'open', 'profile'].__contains__(url.name)]),
             name='chat_schema'),
        path(f'{CONFIG.get_chat_path()[1:]}/api-doc/', ChatSpectacularSwaggerView.as_view(url_name='chat_schema'),
             name='swagger-ui'),
    ]


def _docs_unlocked() -> bool:
    # Docs require both: MAXKB_ENABLE_API_DOCS=true (checked by caller) AND a non-empty DOC_PASSWORD.
    # DOC_PASSWORD acts as a deploy-time secret so anonymous probes don't get the schema.
    pwd = CONFIG.get('DOC_PASSWORD')
    return bool(pwd)


def init_doc(system_urlpatterns, chat_patterns):
    if not _docs_unlocked():
        return
    init_app_doc(system_urlpatterns)
    init_chat_doc(system_urlpatterns, chat_patterns)
