from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class UserRole(str, Enum):
    PATIENT = "patient"
    DOCTOR = "doctor"
    ADMIN = "admin"


class AuthenticatedUser(BaseModel):
    """Represents an authenticated entity derived strictly from verified Firebase token claims."""
    uid: str = Field(..., description="Unique Firebase Authentication user ID")
    email: Optional[str] = Field(default=None, description="Email associated with authenticated account")
    role: UserRole = Field(default=UserRole.PATIENT, description="System authorization role")
    claims: Dict[str, Any] = Field(default_factory=dict, description="Verified token claims")


class HealthResponse(BaseModel):
    """Health check status representation."""
    status: str = "healthy"
    version: str
    environment: str
    timestamp: str
    services: Dict[str, str] = Field(default_factory=dict)


class EHRRecordCreate(BaseModel):
    """Schema for validating creation of electronic medical records."""
    patient_id: str = Field(..., min_length=1, description="Target patient UID")
    diagnosis: str = Field(..., min_length=2, max_length=500, description="Clinical diagnosis or issue")
    notes: Optional[str] = Field(default="", max_length=2000, description="Doctor clinical notes")
    prescription: Optional[str] = Field(default="", max_length=2000, description="Formatted prescription text")
    medicines: Optional[List[Dict[str, Any]]] = Field(default_factory=list, description="Structured medicines schedule")


class EHRRecordResponse(BaseModel):
    """Safe schema for returning EHR records."""
    id: str
    patient_id: str
    doctor_id: str
    doctor_name: Optional[str] = None
    diagnosis: str
    notes: Optional[str] = None
    prescription: Optional[str] = None
    medicines: Optional[List[Dict[str, Any]]] = None
    created_at: Optional[str] = None


class AuditEvent(str, Enum):
    RECORD_CREATED = "RECORD_CREATED"
    RECORD_UPDATED = "RECORD_UPDATED"
    RECORD_ACCESSED = "RECORD_ACCESSED"
    PRESCRIPTION_CREATED = "PRESCRIPTION_CREATED"
    APPOINTMENT_CREATED = "APPOINTMENT_CREATED"
    APPOINTMENT_CANCELLED = "APPOINTMENT_CANCELLED"
    BLOCKCHAIN_PROOF_CREATED = "BLOCKCHAIN_PROOF_CREATED"
    BLOCKCHAIN_VERIFICATION_SUCCESS = "BLOCKCHAIN_VERIFICATION_SUCCESS"
    BLOCKCHAIN_VERIFICATION_FAILED = "BLOCKCHAIN_VERIFICATION_FAILED"
    BLOCKCHAIN_TRANSACTION_FAILED = "BLOCKCHAIN_TRANSACTION_FAILED"
    BLOCKCHAIN_UNAVAILABLE = "BLOCKCHAIN_UNAVAILABLE"
    BLOCKCHAIN_VERIFIED = "BLOCKCHAIN_VERIFIED"
    AI_PROCESSED = "AI_PROCESSED"
    AI_SUMMARY_REQUESTED = "AI_SUMMARY_REQUESTED"
    AI_SUMMARY_COMPLETED = "AI_SUMMARY_COMPLETED"
    AI_PRESCRIPTION_EXPLANATION_REQUESTED = "AI_PRESCRIPTION_EXPLANATION_REQUESTED"
    AI_PRESCRIPTION_EXPLANATION_COMPLETED = "AI_PRESCRIPTION_EXPLANATION_COMPLETED"
    AI_ASSISTANT_REQUESTED = "AI_ASSISTANT_REQUESTED"
    AI_ASSISTANT_COMPLETED = "AI_ASSISTANT_COMPLETED"
    AI_REQUEST_DENIED = "AI_REQUEST_DENIED"
    AI_PROVIDER_ERROR = "AI_PROVIDER_ERROR"
    AI_RESPONSE_VALIDATION_FAILED = "AI_RESPONSE_VALIDATION_FAILED"
    AI_RATE_LIMIT_EXCEEDED = "AI_RATE_LIMIT_EXCEEDED"


class AuditLogEntry(BaseModel):
    """Audit log entry schema preventing exposure of sensitive patient PII/credentials."""
    id: str
    event_type: AuditEvent
    actor_uid: str
    actor_role: UserRole
    target_id: Optional[str] = None
    timestamp: str
    status: str
    metadata_hash: Optional[str] = None


class BlockchainProof(BaseModel):
    """
    Immutable cryptographic proof anchored to the blockchain.
    Contains strictly non-identifying integrity metadata. NO medical records or PII.
    """
    proof_id: str = Field(..., description="Unique proof identifier")
    record_id: str = Field(..., description="Off-chain record ID")
    record_type: str = Field(default="medical_record", description="Type of record")
    record_version: int = Field(default=1, description="Version of the anchored record")
    record_hash: str = Field(..., description="Deterministic SHA-256 digest")
    hash_algorithm: str = Field(default="SHA-256", description="Cryptographic hashing algorithm")
    transaction_id: str = Field(..., description="On-chain Ethereum transaction hash (0x...)")
    block_number: int = Field(..., description="Confirmed block number")
    blockchain_network: str = Field(..., description="Blockchain network identifier")
    contract_address: str = Field(..., description="Smart contract registry address")
    blockchain_status: str = Field(default="CONFIRMED", description="Transaction confirmation status")
    created_at: str = Field(..., description="Timestamp of proof creation")
    created_by_uid: str = Field(..., description="Authenticated UID of registering clinician")


class BlockchainProofCreateRequest(BaseModel):
    """Request model for authoring an integrity proof."""
    record_id: str = Field(..., min_length=1, description="Target record ID to anchor")
    record_type: str = Field(default="medical_record", description="Record type")
    record_version: int = Field(default=1, ge=1, description="Record version")


class BlockchainVerifyRequest(BaseModel):
    """Request model for verifying a record's cryptographic integrity."""
    record_id: str = Field(..., min_length=1, description="Target record ID to verify")
    record_type: str = Field(default="medical_record", description="Record type")
    record_version: int = Field(default=1, ge=1, description="Record version")


class BlockchainVerifyResponse(BaseModel):
    """Authoritative response confirming cryptographic match or tampering."""
    verified: bool = Field(..., description="True if off-chain record hash matches on-chain proof")
    status: str = Field(..., description="Status: INTEGRITY_VERIFIED, INTEGRITY_MISMATCH, PROOF_NOT_FOUND, RECORD_NOT_FOUND, BLOCKCHAIN_UNAVAILABLE")
    record_id: str
    current_hash: Optional[str] = None
    on_chain_hash: Optional[str] = None
    transaction_id: Optional[str] = None
    block_number: Optional[int] = None
    blockchain_network: Optional[str] = None
    timestamp: str
    details: Optional[str] = None


class AIStatusResponse(BaseModel):
    """Operational status response for Phase 4 AI module."""
    module: str = "AI Clinical Analysis & Assistant"
    phase: str = "PHASE 4 — ACTIVE"
    status: str = "Phase 4 AI Clinical Assistant and Summarization subsystem operational."
    provider: str = "clinical_engine"
    model: str = "gpt-4o-mini"
    is_active: bool = True


class AISummarizeRequest(BaseModel):
    """Request model for summarizing an electronic health record."""
    record_id: str = Field(..., min_length=1, description="Target EHR record ID")
    record_type: str = Field(default="medical_record", description="Record type")


class AISummarizeResponse(BaseModel):
    """Authoritative response providing structured AI clinical highlights."""
    success: bool = True
    record_id: str
    summary: str
    key_points: List[str] = Field(default_factory=list)
    generated_by: str = "AI"
    provider: str
    model: str
    disclaimer: str = (
        "This summary is AI-generated for informational assistance only and is not a medical diagnosis. "
        "The official EHR remains authoritative."
    )


class AIPrescriptionExplainRequest(BaseModel):
    """Request model for explaining a medication prescription in patient-friendly terms."""
    prescription_id: Optional[str] = Field(default=None, description="Optional prescription ID")
    medicine_name: Optional[str] = Field(default=None, description="Medicine name and strength")
    dosage: Optional[str] = Field(default=None, description="Prescribed dose (e.g. 1 tablet)")
    frequency: Optional[str] = Field(default=None, description="Frequency (e.g. Twice Daily)")
    instructions: Optional[str] = Field(default=None, description="Special instructions")
    diagnosis: Optional[str] = Field(default=None, description="Associated clinical condition")


class AIPrescriptionExplainResponse(BaseModel):
    """Patient-friendly explanation of a prescription with clinical safety disclaimers."""
    success: bool = True
    medicine: str
    explanation: str
    schedule_guidance: str
    precautions: List[str] = Field(default_factory=list)
    generated_by: str = "AI"
    provider: str
    model: str
    disclaimer: str = (
        "AI-generated explanation — follow the doctor's prescription. "
        "Do not modify or discontinue medication without consulting your doctor."
    )


class AIAssistantRequest(BaseModel):
    """Request query sent to the grounded AI health assistant."""
    query: str = Field(..., min_length=2, max_length=1000, description="Health or EHR inquiry")
    patient_id: Optional[str] = Field(default=None, description="Optional target patient ID for authorized doctors")


class AIAssistantResponse(BaseModel):
    """Safe, grounded response from the AI health assistant."""
    success: bool = True
    answer: str
    key_points: List[str] = Field(default_factory=list)
    source_context: str = "authorized_ehr"
    generated_by: str = "AI"
    provider: str
    model: str
    confidence_note: Optional[str] = None
    disclaimer: str = (
        "AI-generated health assistance is for informational and educational guidance only. "
        "It does not replace professional medical evaluation, diagnosis, or care from a licensed healthcare provider."
    )


class BlockchainStatusResponse(BaseModel):
    """Operational status response for Phase 3 Blockchain subsystem."""
    module: str = "Blockchain Integrity & Verification Registry"
    phase: str = "PHASE 3 — ACTIVE"
    status: str = "EVM Smart Contract Registry operational. Deterministic SHA-256 anchoring active. Off-chain EHR integrity."
    network: str
    contract_address: Optional[str] = None
    connected: bool
    latest_block: int
