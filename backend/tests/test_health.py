import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app


@pytest.mark.asyncio
async def test_root_health():
    """Verify GET /health returns 200 with operational status."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.get("/health")
    
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data
    assert "environment" in data
    assert data["services"]["api_gateway"] == "operational"
    assert "PHASE 4" in data["services"]["ai_subsystem"]
    assert "PHASE 3" in data["services"]["blockchain_subsystem"]


@pytest.mark.asyncio
async def test_api_v1_health():
    """Verify GET /api/v1/health returns 200 under versioned prefix."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.get("/api/v1/health")
    
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["services"]["firebase_auth_verifier"] == "ready"


@pytest.mark.asyncio
async def test_security_headers():
    """Verify security headers are applied by SecurityHeadersMiddleware."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.get("/health")
    
    assert response.headers.get("x-content-type-options") == "nosniff"
    assert response.headers.get("x-frame-options") == "DENY"
    assert response.headers.get("x-xss-protection") == "1; mode=block"
