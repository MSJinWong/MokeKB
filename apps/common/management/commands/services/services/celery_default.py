import os
import subprocess

from .celery_base import CeleryBaseService
from django.conf import settings

__all__ = ['CeleryDefaultService', 'make_queue_service']


class CeleryDefaultService(CeleryBaseService):
    """Worker service for a single celery queue. Defaults to 'celery' queue."""

    def __init__(self, **kwargs):
        kwargs.setdefault('queue', 'celery')
        super().__init__(**kwargs)

    def open_subprocess(self):
        env = os.environ.copy()
        env['LC_ALL'] = 'C.UTF-8'
        env['PYTHONOPTIMIZE'] = '1'
        env['ANSIBLE_FORCE_COLOR'] = 'True'
        env['PYTHONPATH'] = settings.APPS_DIR
        env['SERVER_NAME'] = 'celery'
        if os.getuid() == 0:
            env.setdefault('C_FORCE_ROOT', '1')
        kwargs = {
            'cwd': self.cwd,
            'stderr': self.log_file,
            'stdout': self.log_file,
            'env': env,
        }
        self._process = subprocess.Popen(self.cmd, **kwargs)


def make_queue_service(queue_name: str):
    """Factory: produce a CeleryDefaultService subclass that consumes `queue_name`."""
    cls = type(
        f'Celery_{queue_name}_Service',
        (CeleryDefaultService,),
        {
            '__init__': lambda self, **kwargs: CeleryDefaultService.__init__(
                self, **{**kwargs, 'queue': queue_name}
            )
        },
    )
    return cls
