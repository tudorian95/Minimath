from enum import Enum
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field, root_validator


class Operation(str, Enum):
    pow = "pow"
    fib = "fib"
    fact = "fact"


class MathRequest(BaseModel):
    op: Operation
    a: int = Field(..., description="Primary operand")
    b: Optional[int] = Field(None, description="Secondary operand (power only)")

    @root_validator
    def validate_operation(cls, values):
        op = values.get("op")
        a = values.get("a")
        b = values.get("b")

        if op == Operation.pow and b is None:
            raise ValueError("b is required for power operations")
        if op in {Operation.fib, Operation.fact} and b is not None:
            raise ValueError("b is not used for fib/fact operations")
        if op in {Operation.fib, Operation.fact} and a is not None and a < 0:
            raise ValueError("a must be >= 0 for fib/fact operations")
        return values


class MathResult(BaseModel):
    result: Optional[str] = Field(None, description="Computed result or error message")
    status: str = Field(..., description="Task status")


class ErrorResponse(BaseModel):
    detail: str


class ValidationErrorResponse(BaseModel):
    detail: str
    errors: List[Dict[str, Any]]
