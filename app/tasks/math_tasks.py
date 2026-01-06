from celery.utils.log import get_task_logger
from sqlalchemy.exc import SQLAlchemyError

from app.db.session import SessionLocal
from app.models import MathOperation
from app.services import calc_fact, calc_fib, calc_pow
from app.tasks.celery_app import celery_app

logger = get_task_logger(__name__)


def perform_operation(op: str, a: int, b: int | None = None) -> int:
    if op == "pow":
        if b is None:
            raise ValueError("b is required for power operations")
        return calc_pow(a, b)
    if op == "fib":
        return calc_fib(a)
    if op == "fact":
        return calc_fact(a)
    raise ValueError("Invalid operation")


@celery_app.task(name="mathops.perform_operation")
def perform_operation_task(job_id: str, op: str, a: int, b: int | None = None) -> None:
    db = SessionLocal()
    try:
        db_entry = db.query(MathOperation).filter_by(id=job_id).first()
        if not db_entry:
            logger.warning("Job %s not found; skipping", job_id)
            return

        try:
            result = perform_operation(op, a, b)
        except (OverflowError, ValueError) as exc:
            db_entry.status = "failed"
            db_entry.result = str(exc)
        else:
            db_entry.status = "done"
            db_entry.result = str(result)

        try:
            db.commit()
        except SQLAlchemyError:
            db.rollback()
            logger.exception("Database error while updating job %s", job_id)
            raise
    finally:
        db.close()
