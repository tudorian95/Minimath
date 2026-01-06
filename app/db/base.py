from sqlalchemy.orm import declarative_base

Base = declarative_base()

# Import models for Alembic autogenerate support.
from app.models.math_operation import MathOperation  # noqa: E402,F401
