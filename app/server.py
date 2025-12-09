import os
import logging
import uvicorn

def main():
    # Read LOG_LEVEL from env, default to "info"
    log_level = os.getenv("LOG_LEVEL", "info").lower()

    print(f"*** server.py starting with LOG_LEVEL={log_level} ***")

    numeric_level = getattr(logging, log_level.upper(), logging.INFO)
    logging.getLogger().setLevel(numeric_level)

    error_logger = logging.getLogger("uvicorn.error")
    access_logger = logging.getLogger("uvicorn.access")
    error_logger.setLevel(numeric_level)
    access_logger.setLevel(numeric_level)

    access_log_enabled = numeric_level < logging.ERROR

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        log_level=log_level,
        access_log=access_log_enabled,
    )

if __name__ == "__main__":
    main()
