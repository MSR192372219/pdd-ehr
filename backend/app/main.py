from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app.api.routes import ai, blockchain, ehr, health
from app.core.config import settings
from app.core.logging_config import logger
from app.core.security import initialize_firebase_admin


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle event handler for server startup and teardown."""
    logger.info(f"Starting {settings.APP_NAME} [Environment: {settings.ENVIRONMENT}]")
    # Initialize Firebase server-side Admin SDK
    initialize_firebase_admin()
    yield
    logger.info(f"Shutting down {settings.APP_NAME}")


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=(
        "Production-ready Private Cloud Backend providing a secure API gateway, "
        "Firebase Authentication token verification, strict role-based authorization, "
        "and architectural integration points for Phase 3 (Blockchain) and Phase 4 (AI)."
    ),
    lifespan=lifespan,
    docs_url="/docs" if not settings.is_production else None,
    redoc_url="/redoc" if not settings.is_production else None,
)


# Security Headers Middleware
class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate"
        return response


app.add_middleware(SecurityHeadersMiddleware)

# CORS Configuration — strictly enforced from settings
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept", "X-Requested-With"],
)


# Centralized Exception Handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Centralized handler for HTTPExceptions with consistent error schemas."""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": True,
            "status_code": exc.status_code,
            "message": exc.detail,
        },
        headers=exc.headers,
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Centralized handler for Pydantic input validation failures."""
    errors = []
    for err in exc.errors():
        loc = " -> ".join([str(x) for x in err.get("loc", [])])
        errors.append(f"{loc}: {err.get('msg', 'Invalid value')}")

    logger.warning(f"Request validation failure on {request.url.path}: {errors}")
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": True,
            "status_code": 422,
            "message": "Input validation error",
            "details": errors,
        },
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    """Centralized fallback handler that logs internal errors safely without leaking stack traces."""
    logger.error(f"Unhandled server error on {request.method} {request.url.path}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": True,
            "status_code": 500,
            "message": "Internal server error. The incident has been logged for administrator review.",
        },
    )


# Root Health Check
app.include_router(health.router)

# Versioned API Routes (/api/v1)
from fastapi import APIRouter
api_v1_router = APIRouter(prefix=settings.API_V1_PREFIX)
api_v1_router.include_router(health.router)
api_v1_router.include_router(ehr.router)
api_v1_router.include_router(blockchain.router)
api_v1_router.include_router(ai.router)

app.include_router(api_v1_router)
