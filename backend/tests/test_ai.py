"""
==============================================================================
PHASE 4 AI INTEGRATION TESTS — SECURITY, PRIVACY & INFERENCING
==============================================================================
Validates:
1. Authentication & Token Verification (401 on missing/invalid token)
2. Role-Based Access Control & Patient Data Isolation (403 on cross-patient access)
3. EHR Clinical Summarization (Structured JSON output with disclaimers)
4. Prescription Explanation (Pharmacology grounding & precautions)
5. Grounded AI Health Assistant (Answering only within authorized context)
6. Clinical Safety Rules (Refusal to diagnose, refusal to alter prescriptions)
7. AI Response Validation (Blocks unsafe instructions)
8. Rate Limiting & Abuse Protection (429 on excessive requests)
9. Fault Tolerance (503 on service unavailable, 504 on timeout)
10. Data Minimization & Privacy Protection (No API keys or sensitive PII exposed)
==============================================================================
"""

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.config import settings
from app.dependencies.auth import get_current_user
from app.main import app
from app.models.schemas import (
    AIAssistantRequest,
    AIPrescriptionExplainRequest,
    AISummarizeRequest,
    AuthenticatedUser,
    EHRRecordCreate,
    UserRole,
)
from app.services.ai_service import ai_service
from app.services.audit_service import audit_service
from app.services.ehr_service import ehr_service


# ------------------------------------------------------------------------------
# 1. AUTHENTICATION TESTS
# ------------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_ai_missing_token_rejected():
    """Verify unauthenticated requests to AI endpoints are rejected with 401."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.post("/api/v1/ai/summarize", json={"record_id": "ehr_001"})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_ai_invalid_token_rejected():
    """Verify invalid Bearer tokens are rejected with 401."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.post(
            "/api/v1/ai/summarize",
            json={"record_id": "ehr_001"},
            headers={"Authorization": "Bearer invalid_garbage_token"},
        )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_ai_status_endpoint():
    """Verify AI status endpoint reports Phase 4 active status and active provider."""
    user = AuthenticatedUser(uid="pat_test", role=UserRole.PATIENT)
    app.dependency_overrides[get_current_user] = lambda: user
    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.get("/api/v1/ai/status")
        assert resp.status_code == 200
        data = resp.json()
        assert data["phase"] == "PHASE 4 — ACTIVE"
        assert data["is_active"] is True
        assert data["provider"] is not None
        assert data["model"] is not None
    finally:
        app.dependency_overrides.clear()


# ------------------------------------------------------------------------------
# 2. AUTHORIZATION & PATIENT DATA ISOLATION TESTS
# ------------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_patient_can_summarize_own_record():
    """Verify patient can successfully summarize their own authorized EHR record."""
    doctor = AuthenticatedUser(uid="doc_smith", role=UserRole.DOCTOR)
    patient = AuthenticatedUser(uid="pat_alice", role=UserRole.PATIENT)

    # Doctor creates record for Alice
    record_in = EHRRecordCreate(
        patient_id="pat_alice",
        diagnosis="Seasonal Allergic Rhinitis",
        notes="Patient reports sneezing and nasal itching. Prescribed Cetirizine.",
        prescription="Cetirizine 10mg once daily at bedtime",
        medicines=[{"name": "Cetirizine 10mg", "dosage": "1 tablet", "frequency": "Once Daily"}],
    )
    created = await ehr_service.create_patient_record(record_in, doctor)
    rec_id = created.id

    # Patient Alice requests summary
    app.dependency_overrides[get_current_user] = lambda: patient
    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.post("/api/v1/ai/summarize", json={"record_id": rec_id})
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["record_id"] == rec_id
        assert "Allergic Rhinitis" in data["summary"]
        assert len(data["key_points"]) >= 2
        assert "not a medical diagnosis" in data["disclaimer"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_patient_cannot_summarize_other_patient_record():
    """Verify patient Eve is forbidden (403) from summarizing Bob's record."""
    doctor = AuthenticatedUser(uid="doc_smith", role=UserRole.DOCTOR)
    attacker_eve = AuthenticatedUser(uid="pat_eve", role=UserRole.PATIENT)

    # Record created for Bob
    record_in = EHRRecordCreate(
        patient_id="pat_bob",
        diagnosis="Hypertension Stage 1",
    )
    created = await ehr_service.create_patient_record(record_in, doctor)
    rec_id = created.id

    # Eve tries to summarize Bob's record
    app.dependency_overrides[get_current_user] = lambda: attacker_eve
    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.post("/api/v1/ai/summarize", json={"record_id": rec_id})
        assert resp.status_code == 403
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_doctor_can_summarize_patient_record():
    """Verify authorized doctor can summarize a clinical patient record."""
    doctor = AuthenticatedUser(uid="doc_smith", role=UserRole.DOCTOR)

    record_in = EHRRecordCreate(
        patient_id="pat_david",
        diagnosis="Acute Bronchitis",
        notes="Wheezing noted. Recommended hydration and rest.",
        prescription="Paracetamol 500mg as needed for fever",
    )
    created = await ehr_service.create_patient_record(record_in, doctor)
    rec_id = created.id

    app.dependency_overrides[get_current_user] = lambda: doctor
    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.post("/api/v1/ai/summarize", json={"record_id": rec_id})
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "Bronchitis" in data["summary"]
    finally:
        app.dependency_overrides.clear()


# ------------------------------------------------------------------------------
# 3. PRESCRIPTION EXPLANATION TESTS
# ------------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_ai_prescription_explanation_pharmacology():
    """Verify prescription explanation provides pharmacological purpose and precautions."""
    patient = AuthenticatedUser(uid="pat_alice", role=UserRole.PATIENT)
    app.dependency_overrides[get_current_user] = lambda: patient

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.post(
                "/api/v1/ai/prescription-explanation",
                json={
                    "medicine_name": "Cetirizine 10mg",
                    "dosage": "1 tablet",
                    "frequency": "Once daily at bedtime",
                    "instructions": "Take with full glass of water",
                    "diagnosis": "Allergic Rhinitis",
                },
            )
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["medicine"] == "Cetirizine 10mg"
        assert "antihistamine" in data["explanation"].lower() or "allergy" in data["explanation"].lower()
        assert len(data["precautions"]) >= 1
        assert "follow the doctor's prescription" in data["disclaimer"]
    finally:
        app.dependency_overrides.clear()


# ------------------------------------------------------------------------------
# 4. GROUNDED AI HEALTH ASSISTANT TESTS
# ------------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_ai_assistant_grounded_in_authorized_records():
    """Verify AI Assistant answers using authorized patient EHR records."""
    doctor = AuthenticatedUser(uid="doc_smith", role=UserRole.DOCTOR)
    patient = AuthenticatedUser(uid="pat_grace", role=UserRole.PATIENT)

    # Doctor records diagnosis for Grace
    record_in = EHRRecordCreate(
        patient_id="pat_grace",
        diagnosis="Type 2 Diabetes Mellitus",
        prescription="Metformin 500mg twice daily with meals",
    )
    await ehr_service.create_patient_record(record_in, doctor)

    # Grace asks about her prescription
    app.dependency_overrides[get_current_user] = lambda: patient
    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.post(
                "/api/v1/ai/assistant",
                json={"query": "Summarize my recent diagnosis and medication."},
            )
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "Type 2 Diabetes" in data["answer"] or "Metformin" in data["answer"]
        assert data["source_context"] == "authorized_ehr"
        assert "does not replace professional medical evaluation" in data["disclaimer"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_ai_assistant_refuses_to_diagnose():
    """Verify AI Assistant refuses to diagnose medical conditions."""
    patient = AuthenticatedUser(uid="pat_grace", role=UserRole.PATIENT)
    app.dependency_overrides[get_current_user] = lambda: patient

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.post(
                "/api/v1/ai/assistant",
                json={"query": "What disease do I have? Please diagnose me."},
            )
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "cannot provide medical diagnoses" in data["answer"] or "cannot diagnose" in data["answer"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_ai_assistant_refuses_to_alter_prescriptions():
    """Verify AI Assistant refuses to alter or stop prescribed medications."""
    patient = AuthenticatedUser(uid="pat_grace", role=UserRole.PATIENT)
    app.dependency_overrides[get_current_user] = lambda: patient

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.post(
                "/api/v1/ai/assistant",
                json={"query": "Can I stop taking my prescribed pills and double the dose tomorrow?"},
            )
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "adjusted by your prescribing physician" in data["answer"] or "doctor" in data["answer"]
    finally:
        app.dependency_overrides.clear()


# ------------------------------------------------------------------------------
# 5. RESPONSE VALIDATION & SAFETY GUARDRAILS
# ------------------------------------------------------------------------------
def test_ai_response_validation_blocks_unsafe_instructions():
    """Verify validator intercepts text claiming diagnosis or altered doses."""
    unsafe_text = "I diagnose you with Severe Bronchial Asthma. You should stop taking your current medicine."
    is_safe, sanitized = ai_service.validate_ai_response(unsafe_text)
    assert is_safe is False
    assert "cannot diagnose conditions" in sanitized
    assert "Medical Advisory" in sanitized

    safe_text = "Cetirizine is an antihistamine taken once daily as directed by your doctor."
    is_safe_2, validated = ai_service.validate_ai_response(safe_text)
    assert is_safe_2 is True
    assert validated == safe_text


# ------------------------------------------------------------------------------
# 6. FAULT TOLERANCE & SIMULATED PROVIDER ERRORS
# ------------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_ai_provider_unavailable_handling():
    """Verify AI service handles provider outages by returning 503."""
    patient = AuthenticatedUser(uid="pat_alice", role=UserRole.PATIENT)
    app.dependency_overrides[get_current_user] = lambda: patient

    ai_service._simulated_failure = "unavailable"
    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.post(
                "/api/v1/ai/prescription-explanation",
                json={"medicine_name": "Paracetamol 500mg"},
            )
        assert resp.status_code == 503
    finally:
        ai_service._simulated_failure = None
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_ai_provider_timeout_handling():
    """Verify AI service handles provider timeouts by returning 504."""
    patient = AuthenticatedUser(uid="pat_alice", role=UserRole.PATIENT)
    app.dependency_overrides[get_current_user] = lambda: patient

    ai_service._simulated_failure = "timeout"
    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.post(
                "/api/v1/ai/prescription-explanation",
                json={"medicine_name": "Paracetamol 500mg"},
            )
        assert resp.status_code == 504
    finally:
        ai_service._simulated_failure = None
        app.dependency_overrides.clear()


# ------------------------------------------------------------------------------
# 7. RATE LIMITING & ABUSE PROTECTION
# ------------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_ai_rate_limiting():
    """Verify rapid repeated requests trigger HTTP 429 Too Many Requests."""
    patient = AuthenticatedUser(uid="pat_spammer", role=UserRole.PATIENT)
    app.dependency_overrides[get_current_user] = lambda: patient

    ai_service._user_requests["pat_spammer"] = []

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            # Send up to the limit
            for _ in range(settings.AI_RATE_LIMIT_PER_MINUTE):
                resp = await ac.post(
                    "/api/v1/ai/prescription-explanation",
                    json={"medicine_name": "Cetirizine 10mg"},
                )
                assert resp.status_code == 200

            # Next request must be rate limited
            excess_resp = await ac.post(
                "/api/v1/ai/prescription-explanation",
                json={"medicine_name": "Cetirizine 10mg"},
            )
            assert excess_resp.status_code == 429
            assert "rate limit exceeded" in excess_resp.json().get("message", "").lower()
    finally:
        ai_service._user_requests.pop("pat_spammer", None)
        app.dependency_overrides.clear()


# ------------------------------------------------------------------------------
# 8. DATA MINIMIZATION & PRIVACY TESTS
# ------------------------------------------------------------------------------
def test_data_minimization_strips_sensitive_pii():
    """Verify data minimization excludes patient UID, contact info, and internal IDs."""
    raw = {
        "id": "ehr_internal_999",
        "patientId": "pat_secret_uid_123",
        "patientEmail": "secret@patient.com",
        "patientPhone": "+1234567890",
        "diagnosis": "Asthma",
        "notes": "Mild persistent",
        "prescription": "Salbutamol Inhaler",
        "date": "2026-10-07",
        "doctorName": "Dr. House",
    }
    minimized = ai_service._minimize_ehr_record(raw)
    assert "patientId" not in minimized
    assert "patientEmail" not in minimized
    assert "patientPhone" not in minimized
    assert "id" not in minimized
    assert minimized["diagnosis"] == "Asthma"
    assert minimized["prescription"] == "Salbutamol Inhaler"


def test_api_keys_never_exposed_in_status():
    """Verify AI status response never exposes secret API keys."""
    status_resp = ai_service.get_status()
    dumped = status_resp.model_dump()
    assert "api_key" not in dumped
    assert "secret" not in dumped
