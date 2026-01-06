import logging
import uuid

from celery.exceptions import CeleryError
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.exceptions import RequestValidationError
from kombu.exceptions import KombuError
from pydantic import ValidationError
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import MathOperation
from app.schemas import (
    ErrorResponse,
    MathRequest,
    MathResult,
    Operation,
    ValidationErrorResponse,
)
from app.tasks.math_tasks import perform_operation_task

router = APIRouter()
logger = logging.getLogger(__name__)


def parse_math_request(
    op: Operation = Query(..., description="Operation to perform"),
    a: int = Query(..., description="Primary operand"),
    b: int | None = Query(None, description="Secondary operand (power only)"),
) -> MathRequest:
    try:
        return MathRequest(op=op, a=a, b=b)
    except ValidationError as exc:
        raise RequestValidationError(exc.errors()) from exc


@router.post(
    "/calculate",
    response_model=str,
    description=(
        "Queue a math operation for asynchronous processing and return a job ID. "
        "The API is I/O bound and delegates heavy computation to the worker."
    ),
    responses={
        400: {"model": ValidationErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Database error"},
        503: {"model": ErrorResponse, "description": "Queue unavailable"},
    },
)
async def calculate(
    req: MathRequest = Depends(parse_math_request),
    db: Session = Depends(get_db),
) -> str:
    job_id = str(uuid.uuid4())

    db_entry = MathOperation(id=job_id, op=req.op.value, a=req.a, b=req.b)
    db.add(db_entry)
    try:
        db.commit()
    except SQLAlchemyError as exc:
        db.rollback()
        logger.exception("Failed to persist job %s", job_id)
        raise HTTPException(status_code=500, detail="Database error") from exc

    try:
        perform_operation_task.delay(job_id=job_id, op=req.op.value, a=req.a, b=req.b)
    except (CeleryError, KombuError) as exc:
        db_entry.status = "failed"
        db_entry.result = "Queue unavailable"
        try:
            db.commit()
        except SQLAlchemyError:
            db.rollback()
            logger.exception("Failed to update failed job %s", job_id)
        raise HTTPException(status_code=503, detail="Queue unavailable") from exc

    return job_id


@router.get(
    "/result/{job_id}",
    response_model=MathResult,
    description="Retrieve the status/result of a previously submitted job.",
    responses={
        404: {"model": ErrorResponse, "description": "Job ID not found"},
        500: {"model": ErrorResponse, "description": "Database error"},
    },
)
async def get_result(job_id: str, db: Session = Depends(get_db)) -> MathResult:
    operation = db.query(MathOperation).filter_by(id=job_id).first()
    if not operation:
        raise HTTPException(status_code=404, detail="Job ID not found")

    return MathResult(result=operation.result, status=operation.status)
