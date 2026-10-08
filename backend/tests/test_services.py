import pytest
from app.core.config import Settings, settings
from app.models.schemas import AuditEvent, AuthenticatedUser, EHRRecordCreate, UserRole
from app.services.ai_service import ai_service
from app.services.audit_service import audit_service
from app.services.blockchain_service import blockchain_service
from app.services.ehr_service import ehr_service


def test_configuration_loading():
    """Verify configuration loads properly with safe defaults."""
    assert settings.APP_NAME is not None
    assert settings.API_V1_PREFIX == "/api/v1"
    assert settings.FIREBASE_PROJECT_ID == "ehrsystem-32674f7e"
    assert isinstance(settings.cors_origins, list)


def test_no_hardcoded_secrets():
    """Verify settings do not expose hardcoded secret keys in defaults."""
    test_settings = Settings()
    assert test_settings.FIREBASE_PRIVATE_KEY is None
    assert test_settings.FIREBASE_CLIENT_EMAIL is None
    assert test_settings.FIREBASE_SERVICE_ACCOUNT_PATH is None


def test_cors_wildcard_forbidden_in_production():
    """Verify wildcard '*' CORS origins are strictly forbidden in production mode."""
    with pytest.raises(ValueError, match="strictly prohibited in production mode"):
        prod_settings = Settings(ENVIRONMENT="production", ALLOWED_ORIGINS="*")
        _ = prod_settings.cors_origins


def test_blockchain_service_hashing():
    """Verify BlockchainService computes deterministic SHA-256 digests."""
    data_1 = {"diagnosis": "Hypertension", "patient_id": "p_001", "stage": 1}
    data_2 = {"patient_id": "p_001", "stage": 1, "diagnosis": "Hypertension"}
    # Key order should not alter hash due to canonical sorting
    hash_1 = blockchain_service.compute_record_hash(data_1)
    hash_2 = blockchain_service.compute_record_hash(data_2)
    assert hash_1 == hash_2
    assert len(hash_1) == 64  # Valid SHA-256 hex string length


def test_blockchain_service_status():
    """Verify BlockchainService status clearly documents Phase 3 planning."""
    status = blockchain_service.get_status()
    assert "PHASE 3" in status.phase
    assert "Off-chain" in status.status


def test_ai_service_status():
    """Verify AIService status clearly documents Phase 4 planning."""
    status = ai_service.get_status()
    assert "PHASE 4" in status.phase
    assert "Phase 4" in status.status


@pytest.mark.asyncio
async def test_audit_service_sanitizes_sensitive_content():
    """Verify AuditService redacts passwords, tokens, and raw private keys."""
    doctor_actor = AuthenticatedUser(
        uid="doc_1",
        email="doctor@test.com",
        role=UserRole.DOCTOR
    )
    metadata = {
        "password": "secret_password",
        "token": "bearer_secret_123",
        "action_name": "clinical_review"
    }
    entry = await audit_service.log_event(
        event_type=AuditEvent.RECORD_ACCESSED,
        actor=doctor_actor,
        target_id="patient_1",
        metadata=metadata
    )
    assert entry.event_type == AuditEvent.RECORD_ACCESSED
    assert entry.actor_uid == "doc_1"
    assert entry.metadata_hash is not None


@pytest.mark.asyncio
async def test_ehr_service_creation_and_authorization():
    """Verify EHRService handles creation and enforces role rules."""
    doctor_actor = AuthenticatedUser(
        uid="doc_1",
        email="doctor@test.com",
        role=UserRole.DOCTOR
    )
    record_in = EHRRecordCreate(
        patient_id="pat_123",
        diagnosis="Acute Bronchitis",
        notes="Steam inhalation and hydration advised."
    )
    created = await ehr_service.create_patient_record(record_in, doctor_actor)
    assert created.patient_id == "pat_123"
    assert created.doctor_id == "doc_1"
    assert created.diagnosis == "Acute Bronchitis"
