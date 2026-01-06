from fastapi import FastAPI

from app.api import router
from app.core.config import get_settings
from app.core.exceptions import add_exception_handlers


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name)
    add_exception_handlers(app)
    app.include_router(router)
    return app


app = create_app()
