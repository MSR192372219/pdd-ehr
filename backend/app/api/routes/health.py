from datetime import datetime, timezone
from fastapi import APIRouter
from app.core.config import settings
from app.models.schemas import HealthResponse
from app.services.ai_service import ai_service
from app.services.blockchain_service import blockchain_service

router = APIRouter(tags=["Health & Diagnostics"])


@router.get("/health", response_model=HealthResponse)
async def get_health_status() -> HealthResponse:
    """
    Health check endpoint for container orchestrators, load balancers, and monitoring tools.
    Reports operational state of the Private Cloud Backend and sub-service interfaces.
    """
    return HealthResponse(
        status="healthy",
        version=settings.APP_VERSION,
        environment=settings.ENVIRONMENT,
        timestamp=datetime.now(timezone.utc).isoformat(),
        services={
            "api_gateway": "operational",
            "firebase_auth_verifier": "ready",
            "ehr_service": "initialized",
            "audit_service": "initialized",
            "ai_subsystem": ai_service.phase,
            "blockchain_subsystem": blockchain_service.phase,
        }
    )
