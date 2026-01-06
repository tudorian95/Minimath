from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import get_settings

settings = get_settings()

autocommit = False
autoflush = False

connect_args = {}
if settings.database_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(settings.database_url, connect_args=connect_args)
SessionLocal = sessionmaker(bind=engine, autocommit=autocommit, autoflush=autoflush)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
