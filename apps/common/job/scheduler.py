from apscheduler.schedulers.background import BackgroundScheduler
from django_apscheduler.jobstores import DjangoJobStore

from maxkb.const import CONFIG

scheduler = BackgroundScheduler()
scheduler.add_jobstore(DjangoJobStore(), "default")

if CONFIG.get_enable_scheduler():
    try:
        scheduler.start()
    except Exception as e:
        from common.utils.logger import maxkb_logger

        maxkb_logger.error(f"Failed to start scheduler: {e}")
