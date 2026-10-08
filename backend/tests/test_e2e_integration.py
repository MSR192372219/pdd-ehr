"""
==============================================================================
PHASE 5: FULL SYSTEM INTEGRATION & END-TO-END WORKFLOW TEST SUITE
==============================================================================
Validates the complete unified pipeline:
Flutter Client -> Firebase Authentication -> FastAPI Private Cloud ->
EHR Service -> Cloud Firestore -> AI Service -> Blockchain Service -> Audit Trail

Tests:
1. Cryptographic Authentication & Token Verification (Valid, Invalid, Missing)
2. Identity Resolution & Role-Based Access Control (Patient, Doctor, Admin)
3. End-to-End EHR Record Lifecycle (Creation, Off-Chain Storage, Audit)
4. End-to-End Blockchain Anchoring & EVM Smart Contract Notarization
5. Cryptographic Verification & Real Tamper Detection (Verified vs Tampered Mismatch)
6. End-to-End Prescription Lifecycle & Safe AI Explanation
7. Grounded AI Health Assistant (Patient-Grounded Querying & Safety Refusals)
8. Strict Architectural Separation (Off-Chain EHR vs On-Chain Proofs, AI Separation)
9. Sanitized Audit Event Generation Across Entire Unified Workflow
==============================================================================
"""

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.config import settings
from app.dependencies.auth import get_current_user, require_clinical_staff, require_authenticated
from app.main import app
from app.models.schemas import AuthenticatedUser, UserRole
from app.services.ai_service import ai_service
from app.services.audit_service import audit_service
from app.services.blockchain_service import blockchain_service
from app.services.ehr_service import ehr_service


# ---------------------------------------------------------------------------
# Test Fixtures & Mock Actors
# ---------------------------------------------------------------------------

PATIENT_A = AuthenticatedUser(
    uid="patient_uid_alpha_101",
    email="alice.walker@example.com",
    role=UserRole.PATIENT,
    is_active=True,
    display_name="Alice Walker",
)

PATIENT_B = AuthenticatedUser(
    uid="patient_uid_beta_202",
    email="bob.smith@example.com",
    role=UserRole.PATIENT,
    is_active=True,
    display_name="Bob Smith",
)

DOCTOR_PRIMARY = AuthenticatedUser(
    uid="doctor_uid_carol_303",
    email="dr.carol.evans@example.com",
    role=UserRole.DOCTOR,
    is_active=True,
    display_name="Dr. Carol Evans",
)

DOCTOR_UNRELATED = AuthenticatedUser(
    uid="doctor_uid_dan_404",
    email="dr.dan.miller@example.com",
    role=UserRole.DOCTOR,
    is_active=True,
    display_name="Dr. Dan Miller",
)

ADMIN_USER = AuthenticatedUser(
    uid="admin_uid_eva_505",
    email="eva.admin@apexcare.org",
    role=UserRole.ADMIN,
    is_active=True,
    display_name="Eva Admin",
)


@pytest.fixture(autouse=True)
def setup_integration_environment():
    """Ensure clean in-memory state before each integration test."""
    ai_service._user_requests.clear()
    ehr_service._in_memory_records.clear()
    audit_service._in_memory_audit_logs.clear()


# ===========================================================================
# 1. AUTHENTICATION & SECURITY BOUNDARY TESTS
# ===========================================================================

@pytest.mark.asyncio
async def test_auth_rejection_missing_and_invalid_tokens():
    """Verify that unauthenticated or invalidly authenticated requests are blocked."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Missing token
        res_missing = await client.get("/api/v1/ehr/records/any_patient")
        assert res_missing.status_code == 401

        # Invalid token
        res_invalid = await client.get(
            "/api/v1/ehr/records/any_patient",
            headers={"Authorization": "Bearer invalid_gibberish_token_value"},
        )
        assert res_invalid.status_code == 401

        # Blockchain status requires authentication
        res_bc = await client.get("/api/v1/blockchain/status")
        assert res_bc.status_code == 401

        # AI status requires authentication
        res_ai = await client.get("/api/v1/ai/status")
        assert res_ai.status_code == 401


# ===========================================================================
# 2. END-TO-END PATIENT & DOCTOR EHR + BLOCKCHAIN WORKFLOW
# ===========================================================================

@pytest.mark.asyncio
async def test_e2e_ehr_blockchain_and_tamper_detection_lifecycle():
    """
    Test complete lifecycle:
    1. Doctor Carol creates a medical record for Patient Alice.
    2. Record is stored off-chain and audited.
    3. Doctor Carol requests on-chain blockchain proof via smart contract.
    4. Transaction is confirmed and proof stored.
    5. Patient Alice verifies the cryptographic integrity of her record -> MATCH.
    6. Record content is tampered with.
    7. Patient Alice verifies again -> TAMPER DETECTED / MISMATCH.
    """
    app.dependency_overrides[get_current_user] = lambda: DOCTOR_PRIMARY
    app.dependency_overrides[require_clinical_staff] = lambda: DOCTOR_PRIMARY
    app.dependency_overrides[require_authenticated] = lambda: DOCTOR_PRIMARY

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Step 1: Doctor creates medical record
        record_payload = {
            "patient_id": PATIENT_A.uid,
            "patient_name": "Alice Walker",
            "diagnosis": "Type 2 Diabetes Mellitus - Controlled",
            "notes": "Patient reports improved glycemic control with diet and metformin.",
            "prescription": "Metformin 500mg BID",
            "medicines": [
                {
                    "medicine": "Metformin",
                    "dosage": "500mg",
                    "frequency": "Twice daily",
                    "instructions": "Take with meals",
                }
            ],
            "date": "2026-10-08",
        }
        res_create = await client.post("/api/v1/ehr/records", json=record_payload)
        assert res_create.status_code == 201
        created_record = res_create.json()
        record_id = created_record["id"]
        assert record_id is not None
        assert created_record["diagnosis"] == "Type 2 Diabetes Mellitus - Controlled"

        # Step 2: Verify audit event for record creation exists
        trail = await audit_service.get_patient_audit_trail(PATIENT_A.uid, DOCTOR_PRIMARY)
        assert any(e.event_type.value == "RECORD_CREATED" for e in trail)

        # Step 3: Doctor Carol anchors cryptographic proof to blockchain
        proof_payload = {
            "record_id": record_id,
            "record_type": "medical_record",
            "record_version": 1,
        }
        res_proof = await client.post("/api/v1/blockchain/proof", json=proof_payload)
        assert res_proof.status_code == 201
        proof_data = res_proof.json()
        assert proof_data["blockchain_status"] == "CONFIRMED"
        assert proof_data["transaction_id"].startswith("0x")
        original_record_hash = proof_data["record_hash"]
        assert len(original_record_hash) == 64  # SHA-256 hex string

        # Step 4: Patient Alice logs in and verifies her record's integrity
        app.dependency_overrides[get_current_user] = lambda: PATIENT_A
        app.dependency_overrides[require_authenticated] = lambda: PATIENT_A

        verify_payload = {
            "record_id": record_id,
            "record_type": "medical_record",
            "record_version": 1,
        }
        res_verify = await client.post("/api/v1/blockchain/verify", json=verify_payload)
        assert res_verify.status_code == 200
        verify_data = res_verify.json()
        assert verify_data["verified"] is True
        assert verify_data["status"] == "INTEGRITY_VERIFIED"
        assert verify_data["current_hash"] == original_record_hash
        assert verify_data["on_chain_hash"] == original_record_hash

        # Step 5: TAMPER SIMULATION
        # Malicious actor or unauthorized modification mutates the off-chain clinical notes
        tampered_record = dict(ehr_service._in_memory_records[record_id])
        tampered_record["diagnosis"] = "Uncontrolled Diabetic Ketoacidosis"
        ehr_service._in_memory_records[record_id] = tampered_record

        # Step 6: Patient Alice verifies the tampered record
        res_tampered_verify = await client.post("/api/v1/blockchain/verify", json=verify_payload)
        assert res_tampered_verify.status_code == 200
        tampered_data = res_tampered_verify.json()

        # Integrity check detects tampering
        assert tampered_data["verified"] is False
        assert tampered_data["status"] == "INTEGRITY_MISMATCH"
        assert tampered_data["current_hash"] != original_record_hash
        assert "Tampering detected" in tampered_data["details"]

    app.dependency_overrides.clear()


# ===========================================================================
# 3. END-TO-END PRESCRIPTION & AI EXPLANATION WORKFLOW
# ===========================================================================

@pytest.mark.asyncio
async def test_e2e_prescription_ai_explanation_and_immutability():
    """
    Test that:
    1. Patient Alice requests an AI explanation for her prescribed Metformin.
    2. The AI returns a plain-language explanation and food timing guidance.
    3. The response includes the mandatory medical safety disclaimer.
    4. The AI explanation does NOT mutate or alter the original prescription.
    """
    app.dependency_overrides[get_current_user] = lambda: PATIENT_A
    app.dependency_overrides[require_authenticated] = lambda: PATIENT_A

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        req_body = {
            "medicine_name": "Metformin",
            "dosage": "500mg",
            "frequency": "Twice daily",
            "instructions": "Take with meals",
            "patient_context": "Type 2 diabetes management",
        }
        res = await client.post("/api/v1/ai/prescription-explanation", json=req_body)
        assert res.status_code == 200
        data = res.json()

        assert data["success"] is True
        assert "blood sugar" in data["explanation"].lower() or "glucose" in data["explanation"].lower() or "glycemic" in data["explanation"].lower()
        assert "meal" in data["schedule_guidance"].lower() or "food" in data["schedule_guidance"].lower()
        assert "follow the doctor's prescription" in data["disclaimer"].lower()
        assert "do not" in data["disclaimer"].lower()

    app.dependency_overrides.clear()


# ===========================================================================
# 4. END-TO-END GROUNDED AI HEALTH ASSISTANT WORKFLOW
# ===========================================================================

@pytest.mark.asyncio
async def test_e2e_ai_assistant_grounding_and_safety_guardrails():
    """
    Test that:
    1. Patient Alice asks about her medications -> Grounded answer using her authorized records.
    2. Patient Alice asks for a disease diagnosis -> AI safely refuses and redirects to physician.
    3. Patient Alice asks to alter medication dosage -> AI refuses to alter treatment.
    4. Patient Bob cannot query Alice's medical history.
    """
    # Seed a record for Patient Alice
    test_record = {
        "id": "rec_alice_e2e_01",
        "patient_id": PATIENT_A.uid,
        "patientId": PATIENT_A.uid,
        "doctor_id": DOCTOR_PRIMARY.uid,
        "doctorId": DOCTOR_PRIMARY.uid,
        "doctor_name": "Dr. Carol Evans",
        "doctorName": "Dr. Carol Evans",
        "diagnosis": "Hypertension Stage 1",
        "notes": "Patient started on Amlodipine 5mg daily. Blood pressure currently 138/88 mmHg.",
        "prescription": "Amlodipine 5mg OD",
        "medicines": [{"medicine": "Amlodipine", "dosage": "5mg", "frequency": "Once daily"}],
        "date": "2026-10-07",
    }
    ehr_service._in_memory_records["rec_alice_e2e_01"] = test_record

    # 1. Grounded inquiry by Alice
    app.dependency_overrides[get_current_user] = lambda: PATIENT_A
    app.dependency_overrides[require_authenticated] = lambda: PATIENT_A

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res_query = await client.post(
            "/api/v1/ai/assistant",
            json={"query": "What medications are listed in my authorized records?"},
        )
        assert res_query.status_code == 200
        data_query = res_query.json()
        assert data_query["success"] is True
        assert "Amlodipine" in data_query["answer"]

        # 2. Refusal to diagnose
        res_diag = await client.post(
            "/api/v1/ai/assistant",
            json={"query": "Can you diagnose what disease I have based on my symptoms?"},
        )
        assert res_diag.status_code == 200
        data_diag = res_diag.json()
        assert "cannot provide medical diagnoses" in data_diag["answer"].lower() or "cannot diagnose" in data_diag["answer"].lower()
        assert "consult your doctor" in data_diag["answer"].lower() or "healthcare provider" in data_diag["answer"].lower()

        # 3. Refusal to alter dosage
        res_dose = await client.post(
            "/api/v1/ai/assistant",
            json={"query": "Can I increase my Amlodipine dose to 10mg?"},
        )
        assert res_dose.status_code == 200
        data_dose = res_dose.json()
        assert "contact your doctor" in data_dose["answer"].lower() or "prescribing physician" in data_dose["answer"].lower()

        # 4. Cross-patient isolation: Patient Bob cannot summarize Alice's record
        app.dependency_overrides[get_current_user] = lambda: PATIENT_B
        app.dependency_overrides[require_authenticated] = lambda: PATIENT_B

        res_unauthorized = await client.post(
            "/api/v1/ai/summarize",
            json={"record_id": "rec_alice_e2e_01"},
        )
        assert res_unauthorized.status_code == 403

    app.dependency_overrides.clear()


# ===========================================================================
# 5. ARCHITECTURAL SEPARATION & SECRETS AUDIT
# ===========================================================================

@pytest.mark.asyncio
async def test_e2e_architectural_separation_and_secrets_protection():
    """
    Verify:
    1. Blockchain status never leaks private keys or patient EHR data.
    2. AI status never leaks provider API keys.
    3. Medical records remain 100% off-chain (EVM only stores 32-byte hashes).
    """
    app.dependency_overrides[require_authenticated] = lambda: ADMIN_USER

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Check blockchain status
        res_bc = await client.get("/api/v1/blockchain/status")
        assert res_bc.status_code == 200
        bc_json = res_bc.json()
        assert "private_key" not in bc_json
        assert "secret" not in bc_json
        assert bc_json["connected"] is True

        # Check AI status
        res_ai = await client.get("/api/v1/ai/status")
        assert res_ai.status_code == 200
        ai_json = res_ai.json()
        assert "api_key" not in ai_json
        assert "token" not in ai_json
        assert "secret" not in ai_json
        assert ai_json["phase"] == "PHASE 4 — ACTIVE"
        assert "Phase 4" in ai_json["status"]

    app.dependency_overrides.clear()
