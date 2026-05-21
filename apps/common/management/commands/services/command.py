import math
import os

from django.core.management.base import BaseCommand
from django.db.models import TextChoices

from .utils import ServicesUtil
from ops.celery.routing import all_queues


class Services(TextChoices):
    gunicorn = 'gunicorn', 'gunicorn'
    celery_default = 'celery_default', 'celery_default'
    web = 'web', 'web'
    celery = 'celery', 'celery'
    task = 'task', 'task'
    all = 'all', 'all'

    @classmethod
    def get_service_object_class(cls, name):
        from . import services
        if name == cls.gunicorn.value:
            return services.GunicornService
        if name == cls.celery_default.value:
            return services.CeleryDefaultService
        if name.startswith('celery_'):
            queue = name[len('celery_'):]
            if queue in all_queues():
                return services.make_queue_service(queue)
        return None

    @classmethod
    def web_services(cls):
        return [cls.gunicorn.value]

    @classmethod
    def celery_services(cls):
        if os.environ.get('MAXKB_TASK_QUEUE_PREFIX_ENABLED'):
            return [f'celery_{q}' for q in all_queues()]
        return [cls.celery_default.value]

    @classmethod
    def task_services(cls):
        return cls.celery_services()

    @classmethod
    def all_services(cls):
        return cls.web_services() + cls.task_services()

    @classmethod
    def export_services_values(cls):
        per_queue = [f'celery_{q}' for q in all_queues()]
        base = [cls.all.value, cls.web.value, cls.task.value,
                cls.gunicorn.value, cls.celery_default.value]
        # 去重保序
        seen = set()
        result = []
        for v in base + per_queue:
            if v not in seen:
                seen.add(v)
                result.append(v)
        return result

    @classmethod
    def get_service_objects(cls, service_names, **kwargs):
        """Resolve service-name strings (with shortcut groups like 'all') to instances."""
        names = []
        seen = set()
        for raw in service_names:
            method_name = f'{raw}_services'
            if hasattr(cls, method_name):
                expanded = getattr(cls, method_name)()
            elif hasattr(cls, raw):
                expanded = [getattr(cls, raw).value]
            elif raw.startswith('celery_'):
                expanded = [raw]
            else:
                continue
            for n in expanded:
                if n in seen:
                    continue
                seen.add(n)
                names.append(n)

        service_objects = []
        for n in names:
            service_class = cls.get_service_object_class(n)
            if service_class is None:
                continue
            kwargs_with_name = {**kwargs, 'name': n}
            service_objects.append(service_class(**kwargs_with_name))
        return service_objects


class Action(TextChoices):
    start = 'start', 'start'
    status = 'status', 'status'
    stop = 'stop', 'stop'
    restart = 'restart', 'restart'


class BaseActionCommand(BaseCommand):
    help = 'Service Base Command'

    action = None
    util = None

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def add_arguments(self, parser):
        parser.add_argument(
            'services', nargs='+', choices=Services.export_services_values(), help='Service',
        )
        parser.add_argument('-d', '--daemon', nargs="?", const=True)
        parser.add_argument('-w', '--worker', type=int, nargs="?",
                            default=3 if os.cpu_count() > 6 else max(1, math.floor(os.cpu_count() / 2)))
        parser.add_argument('-f', '--force', nargs="?", const=True)

    def initial_util(self, *args, **options):
        service_names = options.get('services')
        service_kwargs = {
            'worker_gunicorn': options.get('worker')
        }
        services = Services.get_service_objects(service_names=service_names, **service_kwargs)

        kwargs = {
            'services': services,
            'run_daemon': options.get('daemon', False),
            'stop_daemon': self.action == Action.stop.value and Services.all.value in service_names,
            'force_stop': options.get('force') or False,
        }
        self.util = ServicesUtil(**kwargs)

    def handle(self, *args, **options):
        self.initial_util(*args, **options)
        assert self.action in Action.values, f'The action {self.action} is not in the optional list'
        _handle = getattr(self, f'_handle_{self.action}', lambda: None)
        _handle()

    def _handle_start(self):
        self.util.start_and_watch()
        os._exit(0)

    def _handle_stop(self):
        self.util.stop()

    def _handle_restart(self):
        self.util.restart()

    def _handle_status(self):
        self.util.show_status()
