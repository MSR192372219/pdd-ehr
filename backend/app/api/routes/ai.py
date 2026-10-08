"""
==============================================================================
AI API ROUTES — EHR SUMMARIZATION, PRESCRIPTION EXPLANATION, HEALTH ASSISTANT
==============================================================================
Phase 4: Protected REST Endpoints for AI Capabilities

SECURITY:
- Requires Firebase ID Token on all endpoints (Authorization: Bearer <token>)
- Enforces Role-Based Access Control and Patient Data Isolation
- Strictly returns non-diagnostic, educational AI assistance with disclaimers
- Enforces rate limiting per caller UID
==============================================================================
"""

from fastapi import APIRouter, Depends, status

from app.dependencies.auth import get_current_user, require_authenticated
from app.models.schemas import (
    AIAssistantRequest,
    AIAssistantResponse,
    AIPrescriptionExplainRequest,
    AIPrescriptionExplainResponse,
    AIStatusResponse,
    AISummarizeRequest,
    AISummarizeResponse,
    AuthenticatedUser,
)
from app.services.ai_service import ai_service

router = APIRouter(prefix="/ai", tags=["AI Clinical Assistant & Summarization"])


@router.get(
    "/status",
    response_model=AIStatusResponse,
    summary="Get operational status of Phase 4 AI subsystem",
)
async def get_ai_status(
    _: AuthenticatedUser = Depends(require_authenticated),
) -> AIStatusResponse:
    """Returns the real-time operational status, active provider, and model of the AI subsystem."""
    return ai_service.get_status()


@router.post(
    "/summarize",
    response_model=AISummarizeResponse,
    status_code=status.HTTP_200_OK,
    summary="Generate data-minimized clinical summary of an authorized EHR record",
)
async def summarize_ehr_record(
    req: AISummarizeRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> AISummarizeResponse:
    """
    Summarizes an electronic health record.
    Enforces authorization:
    - Patients may only summarize their OWN medical records.
    - Authorized doctors may summarize records for patients they manage.
    """
    return await ai_service.summarize_record(
        record_id=req.record_id,
        actor=current_user,
    )


@router.post(
    "/prescription-explanation",
    response_model=AIPrescriptionExplainResponse,
    status_code=status.HTTP_200_OK,
    summary="Explain prescription in clear, patient-friendly terms with safety precautions",
)
async def explain_prescription(
    req: AIPrescriptionExplainRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> AIPrescriptionExplainResponse:
    """
    Explains prescription purpose, timing, and precautions.
    AI cannot modify dosages, recommend discontinuing, or prescribe alternatives.
    """
    return await ai_service.explain_prescription(
        req=req,
        actor=current_user,
    )


@router.post(
    "/assistant",
    response_model=AIAssistantResponse,
    status_code=status.HTTP_200_OK,
    summary="Grounded AI health inquiry based on authorized patient EHR context",
)
async def ask_health_assistant(
    req: AIAssistantRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> AIAssistantResponse:
    """
    Answers health inquiries grounded strictly in the caller's authorized health records.
    Patients receive answers based exclusively on their own records.
    Doctors may query context for authorized patients.
    Never diagnoses medical conditions or replaces doctor consultations.
    """
    return await ai_service.assistant_query(
        req=req,
        actor=current_user,
    )
