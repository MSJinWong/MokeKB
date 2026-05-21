# coding=utf-8
"""
    @project: MaxKB
    @file： web.py
"""
import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'maxkb.settings')
application = get_wsgi_application()


def post_handler():
    from common.database_model_manage.database_model_manage import DatabaseModelManage
    from common import event
    from common.init import init_template
    event.run()
    DatabaseModelManage.init()
    init_template.run()


post_handler()
