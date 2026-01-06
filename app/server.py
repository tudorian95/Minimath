import logging

import uvicorn

from app.core.config import get_settings


def main() -> None:
    settings = get_settings()
    log_level = settings.log_level.lower()
    workers = settings.uvicorn_workers

    numeric_level = getattr(logging, log_level.upper(), logging.INFO)
    logging.getLogger().setLevel(numeric_level)

    error_logger = logging.getLogger("uvicorn.error")
    access_logger = logging.getLogger("uvicorn.access")
    error_logger.setLevel(numeric_level)
    access_logger.setLevel(numeric_level)

    access_log_enabled = numeric_level < logging.ERROR

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        log_level=log_level,
        access_log=access_log_enabled,
        workers=workers,
    )


if __name__ == "__main__":
    main()
