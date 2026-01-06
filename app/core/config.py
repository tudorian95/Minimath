from functools import lru_cache
from pydantic import BaseSettings, Field


class Settings(BaseSettings):
    app_name: str = "MathOps Microservice"
    log_level: str = Field("info", env="LOG_LEVEL")
    uvicorn_workers: int = Field(4, env="UVICORN_WORKERS")

    database_url: str = Field("sqlite:///./mathops.db", env="DATABASE_URL")
    celery_broker_url: str = Field(
        "amqp://mathops:mathops@localhost:5672//", env="CELERY_BROKER_URL"
    )
    celery_result_backend: str = Field("rpc://", env="CELERY_RESULT_BACKEND")

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache
def get_settings() -> Settings:
    return Settings()
