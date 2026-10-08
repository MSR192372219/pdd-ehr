from unittest.mock import patch
import pytest
from httpx import ASGITransport, AsyncClient
from app.dependencies.auth import get_current_user
from app.main import app
from app.models.schemas import AuthenticatedUser, UserRole


@pytest.mark.asyncio
async def test_protected_route_missing_token():
    """Verify request without Authorization header is rejected with 401."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.get("/api/v1/ehr/records/patient_123")
    
    assert response.status_code == 401
    assert "Missing Bearer ID token" in response.json()["message"]


@pytest.mark.asyncio
async def test_protected_route_invalid_token():
    """Verify malformed or invalid token is rejected with 401."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.get(
            "/api/v1/ehr/records/patient_123",
            headers={"Authorization": "Bearer invalid_signature_or_expired_token"}
        )
    
    assert response.status_code == 401
    assert "Invalid, expired, or revoked" in response.json()["message"]


@pytest.mark.asyncio
async def test_patient_access_own_records_permitted():
    """Verify a patient can access their own medical records."""
    patient_user = AuthenticatedUser(
        uid="patient_abc",
        email="patient@healthcare.com",
        role=UserRole.PATIENT,
        claims={"uid": "patient_abc", "role": "patient"}
    )

    app.dependency_overrides[get_current_user] = lambda: patient_user

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            response = await ac.get(
                "/api/v1/ehr/records/patient_abc",
                headers={"Authorization": "Bearer mock_valid_token"}
            )
        assert response.status_code == 200
        assert isinstance(response.json(), list)
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_patient_cannot_access_other_patient_records():
    """Verify patient data isolation: Patient cannot access another patient's records."""
    patient_user = AuthenticatedUser(
        uid="patient_abc",
        email="patient@healthcare.com",
        role=UserRole.PATIENT,
        claims={"uid": "patient_abc", "role": "patient"}
    )

    app.dependency_overrides[get_current_user] = lambda: patient_user

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            response = await ac.get(
                "/api/v1/ehr/records/patient_xyz",
                headers={"Authorization": "Bearer mock_valid_token"}
            )
        assert response.status_code == 403
        assert "Patients may only access their own medical records" in response.json()["message"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_patient_cannot_create_medical_record():
    """Verify patients are forbidden from authoring clinical medical records."""
    patient_user = AuthenticatedUser(
        uid="patient_abc",
        email="patient@healthcare.com",
        role=UserRole.PATIENT,
        claims={"uid": "patient_abc", "role": "patient"}
    )

    app.dependency_overrides[get_current_user] = lambda: patient_user

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            payload = {
                "patient_id": "patient_abc",
                "diagnosis": "Self-diagnosed Migraine",
                "notes": "Testing unauthorized create",
            }
            response = await ac.post(
                "/api/v1/ehr/records",
                json=payload,
                headers={"Authorization": "Bearer mock_valid_token"}
            )
        assert response.status_code == 403
        assert "Required role" in response.json()["message"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_doctor_can_create_medical_record():
    """Verify doctor can author clinical medical records."""
    doctor_user = AuthenticatedUser(
        uid="doc_manikanta",
        email="manikanta@healthcare.com",
        role=UserRole.DOCTOR,
        claims={"uid": "doc_manikanta", "role": "doctor", "name": "Dr. Manikanta"}
    )

    app.dependency_overrides[get_current_user] = lambda: doctor_user

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            payload = {
                "patient_id": "patient_abc",
                "diagnosis": "Seasonal Viral Pharyngitis",
                "notes": "Throat congestion observed. Rest and fluids advised.",
                "prescription": "Paracetamol 650mg TDS",
                "medicines": [{"name": "Paracetamol 650mg", "dosage": "1 tablet", "frequency": "TDS"}],
            }
            response = await ac.post(
                "/api/v1/ehr/records",
                json=payload,
                headers={"Authorization": "Bearer mock_valid_token"}
            )
        assert response.status_code == 201
        data = response.json()
        assert data["diagnosis"] == "Seasonal Viral Pharyngitis"
        assert data["patient_id"] == "patient_abc"
        assert data["doctor_id"] == "doc_manikanta"
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_doctor_can_view_patient_records():
    """Verify doctor can view patient records for consultation."""
    doctor_user = AuthenticatedUser(
        uid="doc_manikanta",
        email="manikanta@healthcare.com",
        role=UserRole.DOCTOR,
        claims={"uid": "doc_manikanta", "role": "doctor"}
    )

    app.dependency_overrides[get_current_user] = lambda: doctor_user

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            response = await ac.get(
                "/api/v1/ehr/records/patient_abc",
                headers={"Authorization": "Bearer mock_valid_token"}
            )
        assert response.status_code == 200
        assert isinstance(response.json(), list)
    finally:
        app.dependency_overrides.clear()
