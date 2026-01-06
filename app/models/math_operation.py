from datetime import datetime

from sqlalchemy import Column, DateTime, Integer, String

from app.db.base import Base


class MathOperation(Base):
    __tablename__ = "operations"

    id = Column(String, primary_key=True, index=True)
    op = Column(String, nullable=False)
    a = Column(Integer, nullable=False)
    b = Column(Integer, nullable=True)
    result = Column(String, nullable=True)
    status = Column(String, default="pending", nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)
