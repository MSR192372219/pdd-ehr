from typing import Any, Dict
import pytest
from httpx import ASGITransport, AsyncClient

from app.dependencies.auth import get_current_user
from app.main import app
from app.models.schemas import AuthenticatedUser, EHRRecordCreate, UserRole
from app.services.blockchain_service import blockchain_service, calculate_record_hash
from app.services.ehr_service import ehr_service


@pytest.fixture
def sample_ehr_record() -> Dict[str, Any]:
    return {
        "patientId": "pat_101",
        "doctorId": "doc_manikanta",
        "diagnosis": "Type 2 Diabetes Mellitus - Early Stage",
        "notes": "Fasting blood sugar 142 mg/dL. Metformin prescribed. Lifestyle modification advised.",
        "prescription": "Metformin 500mg Once Daily with dinner",
        "medicines": [
            {
                "name": "Metformin 500mg",
                "dosage": "1 tablet",
                "frequency": "Once Daily (Dinner)",
            }
        ],
        "date": "08-10-2026",
    }


def test_canonical_record_hashing_deterministic(sample_ehr_record):
    """Verify that identical logical records with different key ordering produce the EXACT same hash."""
    # Reordered keys in outer dict and inner list
    reordered_record = {
        "date": "08-10-2026",
        "diagnosis": "Type 2 Diabetes Mellitus - Early Stage",
        "prescription": "Metformin 500mg Once Daily with dinner",
        "notes": "Fasting blood sugar 142 mg/dL. Metformin prescribed. Lifestyle modification advised.",
        "medicines": [
            {
                "frequency": "Once Daily (Dinner)",
                "name": "Metformin 500mg",
                "dosage": "1 tablet",
            }
        ],
        "doctorId": "doc_manikanta",
        "patientId": "pat_101",
    }

    hash_original = calculate_record_hash(sample_ehr_record)
    hash_reordered = calculate_record_hash(reordered_record)

    assert hash_original == hash_reordered
    assert len(hash_original) == 64


def test_transient_fields_do_not_affect_hash(sample_ehr_record):
    """Transient database metadata (like id, createdAt, lastViewed) must not alter the clinical hash."""
    record_with_metadata = dict(sample_ehr_record)
    record_with_metadata["id"] = "mongo_or_firestore_doc_id_999"
    record_with_metadata["createdAt"] = "2026-10-08T09:30:00Z"
    record_with_metadata["updatedAt"] = "2026-10-08T10:15:00Z"
    record_with_metadata["viewCount"] = 5

    assert calculate_record_hash(sample_ehr_record) == calculate_record_hash(record_with_metadata)


def test_tampering_alters_record_hash(sample_ehr_record):
    """Any modification to clinical content MUST produce a completely different SHA-256 digest."""
    tampered_record = dict(sample_ehr_record)
    tampered_record["diagnosis"] = "Type 1 Diabetes Mellitus - Severe"

    hash_original = calculate_record_hash(sample_ehr_record)
    hash_tampered = calculate_record_hash(tampered_record)

    assert hash_original != hash_tampered


@pytest.mark.asyncio
async def test_blockchain_status_operational():
    """Verify GET /api/v1/blockchain/status returns operational EVM registry status."""
    doctor_user = AuthenticatedUser(
        uid="doc_manikanta",
        email="manikanta@healthcare.com",
        role=UserRole.DOCTOR,
    )
    app.dependency_overrides[get_current_user] = lambda: doctor_user

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            response = await ac.get("/api/v1/blockchain/status")

        assert response.status_code == 200
        data = response.json()
        assert data["connected"] is True
        assert data["contract_address"] is not None
        assert data["contract_address"].startswith("0x")
        assert "EVM" in data["network"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_doctor_can_create_blockchain_proof():
    """Verify authorized doctor can anchor an EHR record hash and receive a confirmed on-chain transaction."""
    doctor_user = AuthenticatedUser(
        uid="doc_manikanta",
        email="manikanta@healthcare.com",
        role=UserRole.DOCTOR,
    )
    app.dependency_overrides[get_current_user] = lambda: doctor_user

    try:
        # 1. Doctor creates an EHR clinical record
        record_in = EHRRecordCreate(
            patient_id="pat_alice",
            diagnosis="Acute Rhinitis",
            notes="Nasal congestion. Saline spray and cetirizine prescribed.",
            prescription="Cetirizine 10mg Once Daily",
            medicines=[{"name": "Cetirizine 10mg", "dosage": "1 tablet", "frequency": "Night"}],
        )
        created_record = await ehr_service.create_patient_record(record_in, doctor_user)
        rec_id = created_record.id

        # 2. Doctor anchors record to blockchain
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            proof_resp = await ac.post(
                "/api/v1/blockchain/proof",
                json={"record_id": rec_id, "record_type": "medical_record", "record_version": 1},
            )

        assert proof_resp.status_code == 201
        proof_data = proof_resp.json()
        assert proof_data["record_id"] == rec_id
        assert proof_data["transaction_id"].startswith("0x")
        assert len(proof_data["transaction_id"]) == 66  # Valid 32-byte 0x-prefixed hex tx hash
        assert proof_data["block_number"] >= 1
        assert proof_data["blockchain_status"] == "CONFIRMED"
        assert proof_data["contract_address"].startswith("0x")
        assert len(proof_data["record_hash"]) == 64
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_patient_cannot_create_blockchain_proof():
    """Verify patients are strictly forbidden from creating blockchain proofs (RBAC)."""
    patient_user = AuthenticatedUser(
        uid="pat_alice",
        email="alice@healthcare.com",
        role=UserRole.PATIENT,
    )
    app.dependency_overrides[get_current_user] = lambda: patient_user

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            proof_resp = await ac.post(
                "/api/v1/blockchain/proof",
                json={"record_id": "rec_dummy_123", "record_type": "medical_record", "record_version": 1},
            )
        assert proof_resp.status_code == 403
        assert "Required role" in proof_resp.json()["message"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_full_tamper_detection_workflow():
    """
    CRITICAL TAMPER-DETECTION TEST:
    1. Create authoritative record.
    2. Anchor hash A to smart contract.
    3. Verify untampered record -> VERIFIED.
    4. Simulate malicious tampering of clinical diagnosis -> Hash becomes Hash B.
    5. Verify tampered record -> INTEGRITY_MISMATCH detected!
    """
    doctor_user = AuthenticatedUser(
        uid="doc_manikanta",
        email="manikanta@healthcare.com",
        role=UserRole.DOCTOR,
    )
    patient_user = AuthenticatedUser(
        uid="pat_bob",
        email="bob@healthcare.com",
        role=UserRole.PATIENT,
    )

    # Step 1: Create legitimate EHR record
    record_in = EHRRecordCreate(
        patient_id="pat_bob",
        diagnosis="Normal Healthy Physical Exam",
        notes="No acute distress. Normal cardiopulmonary exam.",
        prescription="None",
        medicines=[],
    )
    created = await ehr_service.create_patient_record(record_in, doctor_user)
    rec_id = created.id

    # Step 2: Doctor anchors Hash A to blockchain
    app.dependency_overrides[get_current_user] = lambda: doctor_user
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        anchor_resp = await ac.post(
            "/api/v1/blockchain/proof",
            json={"record_id": rec_id, "record_type": "medical_record", "record_version": 1},
        )
    assert anchor_resp.status_code == 201
    original_proof = anchor_resp.json()
    hash_a = original_proof["record_hash"]

    # Step 3: Patient verifies own record -> INTEGRITY_VERIFIED
    app.dependency_overrides[get_current_user] = lambda: patient_user
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        verify_resp_1 = await ac.post(
            "/api/v1/blockchain/verify",
            json={"record_id": rec_id, "record_type": "medical_record", "record_version": 1},
        )
    assert verify_resp_1.status_code == 200
    v1_data = verify_resp_1.json()
    assert v1_data["verified"] is True
    assert v1_data["status"] == "INTEGRITY_VERIFIED"
    assert v1_data["current_hash"] == hash_a
    assert v1_data["on_chain_hash"] == hash_a
    assert v1_data["transaction_id"] == original_proof["transaction_id"]

    # Step 4: Simulate unauthorized tampering in off-chain database (e.g. database injection or breach)
    tampered_record = dict(ehr_service._in_memory_records[rec_id])
    tampered_record["diagnosis"] = "SEVERE UNCONTROLLED HEART DISEASE (TAMPERED)"
    ehr_service._in_memory_records[rec_id] = tampered_record

    # Step 5: Patient verifies tampered record -> INTEGRITY_MISMATCH!
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        verify_resp_2 = await ac.post(
            "/api/v1/blockchain/verify",
            json={"record_id": rec_id, "record_type": "medical_record", "record_version": 1},
        )
    assert verify_resp_2.status_code == 200
    v2_data = verify_resp_2.json()
    assert v2_data["verified"] is False
    assert v2_data["status"] == "INTEGRITY_MISMATCH"
    assert v2_data["current_hash"] != hash_a
    assert v2_data["on_chain_hash"] == hash_a
    assert "Tampering detected" in v2_data["details"]

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_patient_cannot_verify_other_patient_record():
    """Verify patient data isolation: Patient X cannot verify or view records belonging to Patient Y."""
    doctor_user = AuthenticatedUser(
        uid="doc_manikanta",
        email="manikanta@healthcare.com",
        role=UserRole.DOCTOR,
    )
    attacker_patient = AuthenticatedUser(
        uid="pat_eve",
        email="eve@healthcare.com",
        role=UserRole.PATIENT,
    )

    # Doctor creates record for Patient Charlie
    record_in = EHRRecordCreate(
        patient_id="pat_charlie",
        diagnosis="Migraine",
    )
    created = await ehr_service.create_patient_record(record_in, doctor_user)
    rec_id = created.id

    # Patient Eve attempts to verify Charlie's record
    app.dependency_overrides[get_current_user] = lambda: attacker_patient
    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.post(
                "/api/v1/blockchain/verify",
                json={"record_id": rec_id, "record_type": "medical_record", "record_version": 1},
            )
        assert resp.status_code == 403
        data = resp.json()
        assert "Access denied" in data.get("message", data.get("detail", ""))
    finally:
        app.dependency_overrides.clear()
