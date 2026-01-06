from celery import Celery

from app.core.config import get_settings

settings = get_settings()

celery_app = Celery(
    "mathops",
    broker=settings.celery_broker_url,
    backend=settings.celery_result_backend,
    include=["app.tasks.math_tasks"],
)

celery_app.conf.update(
    task_default_queue="mathops",
    task_acks_late=True,
    worker_prefetch_multiplier=1,
)
