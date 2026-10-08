import logging
import re
import sys
from typing import Any
from app.core.config import settings

# Sensitive pattern redactor
SENSITIVE_PATTERNS = [
    (re.compile(r"Bearer\s+([A-Za-z0-9_\-\.]+)", re.IGNORECASE), "Bearer [REDACTED_TOKEN]"),
    (re.compile(r"password['\"]?\s*[:=]\s*['\"]?([^'\"\s&]+)", re.IGNORECASE), "password=[REDACTED]"),
    (re.compile(r"private_key['\"]?\s*[:=]\s*['\"]?([^'\"\s&]+)", re.IGNORECASE), "private_key=[REDACTED]"),
    (re.compile(r"-----BEGIN PRIVATE KEY-----[\s\S]*?-----END PRIVATE KEY-----"), "[REDACTED_PRIVATE_KEY]"),
]


class SanitizingFilter(logging.Filter):
    """Filters and redacts sensitive data (tokens, passwords, private keys) from all log records."""
    def filter(self, record: logging.LogRecord) -> bool:
        if isinstance(record.msg, str):
            for pattern, replacement in SENSITIVE_PATTERNS:
                record.msg = pattern.sub(replacement, record.msg)
        return True


def setup_logging() -> logging.Logger:
    """Configures structured, sanitized logging for the application."""
    log_level = getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO)
    
    formatter = logging.Formatter(
        fmt="%(asctime)s | %(levelname)-7s | %(name)s:%(lineno)d | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)
    handler.addFilter(SanitizingFilter())

    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    
    # Avoid duplicate handlers if reloaded
    if not root_logger.handlers:
        root_logger.addHandler(handler)
    else:
        root_logger.handlers = [handler]

    # Specific app logger
    app_logger = logging.getLogger("ehr_backend")
    app_logger.setLevel(log_level)
    return app_logger


logger = setup_logging()
