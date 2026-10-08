from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from app.dependencies.auth import (
    get_current_user,
    require_authenticated,
    require_clinical_staff,
)
from app.models.schemas import (
    AuthenticatedUser,
    BlockchainProof,
    BlockchainProofCreateRequest,
    BlockchainStatusResponse,
    BlockchainVerifyRequest,
    BlockchainVerifyResponse,
    UserRole,
)
from app.services.blockchain_service import blockchain_service
from app.services.ehr_service import ehr_service

router = APIRouter(prefix="/blockchain", tags=["Blockchain Integrity & Verification"])


@router.get(
    "/status",
    response_model=BlockchainStatusResponse,
    summary="Get Blockchain subsystem operational status",
)
async def get_blockchain_status(
    _: AuthenticatedUser = Depends(require_authenticated),
) -> BlockchainStatusResponse:
    """Returns the operational status of the EVM smart contract and network connection."""
    return blockchain_service.get_status()


@router.post(
    "/proof",
    response_model=BlockchainProof,
    status_code=status.HTTP_201_CREATED,
    summary="Create on-chain integrity proof for an EHR record",
)
async def create_record_proof(
    request: BlockchainProofCreateRequest,
    current_user: AuthenticatedUser = Depends(require_clinical_staff),
) -> BlockchainProof:
    """
    Submits an immutable cryptographic proof (SHA-256) of an off-chain EHR record to the blockchain.
    Restricted to licensed doctors and system administrators.
    Patients cannot forge or self-submit integrity proofs.
    """
    # 1. Resolve record from authoritative backend
    record_data = await ehr_service.get_record_by_id(request.record_id, current_user)
    if not record_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Medical record '{request.record_id}' not found or access unauthorized."
        )

    # 2. Anchor to blockchain via smart contract
    try:
        proof = await blockchain_service.create_integrity_proof(
            record_id=request.record_id,
            record_type=request.record_type,
            record_version=request.record_version,
            record_data=record_data,
            actor=current_user,
        )
        return proof
    except RuntimeError as e:
        if "BLOCKCHAIN_UNAVAILABLE" in str(e):
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Blockchain network is currently unavailable. Proof creation deferred."
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to anchor proof to blockchain: {e}"
        )


@router.post(
    "/verify",
    response_model=BlockchainVerifyResponse,
    summary="Verify cryptographic integrity of an EHR record",
)
async def verify_record_integrity(
    request: BlockchainVerifyRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> BlockchainVerifyResponse:
    """
    Cryptographically verifies whether an off-chain EHR record has been tampered with.
    1. Re-computes canonical SHA-256 hash of the record data.
    2. Compares against the immutable hash anchored on the blockchain smart contract.
    3. Patients can verify their own records; doctors can verify authorized patient records.
    """
    now_iso = datetime.now(timezone.utc).isoformat()

    # 1. Authoritative record resolution (enforces patient isolation)
    record_data = await ehr_service.get_record_by_id(request.record_id, current_user)
    if not record_data:
        return BlockchainVerifyResponse(
            verified=False,
            status="RECORD_NOT_FOUND",
            record_id=request.record_id,
            timestamp=now_iso,
            details="Record not found in EHR database or user is unauthorized to access it.",
        )

    # 2. Cryptographic verification against smart contract
    return await blockchain_service.verify_integrity_proof(
        record_id=request.record_id,
        record_data=record_data,
        actor=current_user,
        record_version=request.record_version,
    )


@router.get(
    "/proof/{record_id}",
    response_model=Optional[BlockchainProof],
    summary="Get stored blockchain proof metadata for a record",
)
async def get_proof_metadata(
    record_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> Optional[BlockchainProof]:
    """Retrieves proof metadata for a record, checking authorization."""
    # Ensure caller has access to the underlying record
    record_data = await ehr_service.get_record_by_id(record_id, current_user)
    if not record_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Record '{record_id}' not found or access unauthorized."
        )

    proof = await blockchain_service.get_proof(record_id)
    if not proof:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No blockchain proof found for record '{record_id}'."
        )

    return proof
