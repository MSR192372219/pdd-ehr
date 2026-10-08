from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from app.dependencies.auth import (
    get_current_user,
    require_clinical_staff,
    require_authenticated,
)
from app.models.schemas import (
    AuditEvent,
    AuditLogEntry,
    AuthenticatedUser,
    AIStatusResponse,
    BlockchainStatusResponse,
    EHRRecordCreate,
    EHRRecordResponse,
)
from app.services.ai_service import ai_service
from app.services.audit_service import audit_service
from app.services.blockchain_service import blockchain_service
from app.services.ehr_service import ehr_service

router = APIRouter(prefix="/ehr", tags=["Electronic Health Records"])


@router.get(
    "/records/{patient_id}",
    response_model=List[EHRRecordResponse],
    summary="Get patient medical records",
)
async def get_patient_records(
    patient_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> List[EHRRecordResponse]:
    """
    Securely retrieves longitudinal medical records for a specific patient.
    Enforces patient data isolation:
    - Patients can only retrieve their OWN records.
    - Authorized doctors and administrators can retrieve patient records.
    """
    records = await ehr_service.get_patient_records(patient_id, current_user)

    # Log audit event for access traceability
    await audit_service.log_event(
        event_type=AuditEvent.RECORD_ACCESSED,
        actor=current_user,
        target_id=patient_id,
        metadata={"record_count": len(records)},
    )

    return records


@router.post(
    "/records",
    response_model=EHRRecordResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new medical record",
)
async def create_medical_record(
    record_in: EHRRecordCreate,
    current_user: AuthenticatedUser = Depends(require_clinical_staff),
) -> EHRRecordResponse:
    """
    Creates a new EHR clinical record for a patient.
    Restricted to authenticated Doctors and Administrators.
    Patients cannot self-author medical records.
    """
    record = await ehr_service.create_patient_record(record_in, current_user)

    # Log audit event
    await audit_service.log_event(
        event_type=AuditEvent.RECORD_CREATED,
        actor=current_user,
        target_id=record_in.patient_id,
        metadata={"record_id": record.id, "diagnosis": record.diagnosis},
    )

    return record


@router.get(
    "/audit/{patient_id}",
    response_model=List[AuditLogEntry],
    summary="Get patient access audit trail",
)
async def get_patient_audit_trail(
    patient_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> List[AuditLogEntry]:
    """
    Returns the immutable audit log for a patient's EHR access.
    Patients can audit who accessed their records.
    """
    return await audit_service.get_patient_audit_trail(patient_id, current_user)


@router.get(
    "/ai/status",
    response_model=AIStatusResponse,
    summary="Get AI subsystem architectural status",
)
async def get_ai_status(
    _: AuthenticatedUser = Depends(require_authenticated),
) -> AIStatusResponse:
    """Returns the readiness status of the planned Phase 4 AI module."""
    return ai_service.get_status()


@router.get(
    "/blockchain/status",
    response_model=BlockchainStatusResponse,
    summary="Get Blockchain subsystem architectural status",
)
async def get_blockchain_status(
    _: AuthenticatedUser = Depends(require_authenticated),
) -> BlockchainStatusResponse:
    """Returns the readiness status of the planned Phase 3 Blockchain module."""
    return blockchain_service.get_status()
