"""
==============================================================================
PHASE 6: PERFORMANCE & LATENCY BENCHMARKING SUITE
==============================================================================
Measures latency (avg, median, p95), throughput, and error rates across:
1. Public Health Endpoint (GET /health)
2. Authenticated EHR API (GET /api/v1/ehr/records/{patient_id})
3. Grounded AI Assistant (POST /api/v1/ai/assistant)
4. EVM Blockchain Proof Creation (POST /api/v1/blockchain/proof)
5. Blockchain Verification (POST /api/v1/blockchain/verify)
==============================================================================
"""

import statistics
import time
import pytest
from httpx import ASGITransport, AsyncClient

from app.dependencies.auth import get_current_user, require_authenticated, require_clinical_staff
from app.main import app
from app.models.schemas import AuthenticatedUser, UserRole
from app.services.ai_service import ai_service
from app.services.blockchain_service import blockchain_service
from app.services.ehr_service import ehr_service

BENCHMARK_USER = AuthenticatedUser(
    uid="pat_perf_bench_01",
    email="perf.bench@healthcare.org",
    role=UserRole.PATIENT,
    is_active=True,
    display_name="Benchmark Patient",
)

BENCHMARK_DOCTOR = AuthenticatedUser(
    uid="doc_perf_bench_02",
    email="dr.bench@healthcare.org",
    role=UserRole.DOCTOR,
    is_active=True,
    display_name="Benchmark Doctor",
)


@pytest.fixture(autouse=True)
def setup_perf_env():
    ai_service._user_requests.clear()
    ehr_service._in_memory_records.clear()


@pytest.mark.asyncio
async def test_performance_benchmarks():
    """Execute controlled benchmark cycles and print latency distributions."""
    results = {}

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Health Endpoint Latency (50 iterations)
        health_latencies = []
        for _ in range(50):
            t0 = time.perf_counter()
            res = await client.get("/health")
            t1 = time.perf_counter()
            assert res.status_code == 200
            health_latencies.append((t1 - t0) * 1000)

        results["FastAPI Health"] = {
            "avg": statistics.mean(health_latencies),
            "median": statistics.median(health_latencies),
            "p95": statistics.quantiles(health_latencies, n=20)[18],
        }

        # 2. Authenticated EHR Retrieval Latency (30 iterations)
        app.dependency_overrides[get_current_user] = lambda: BENCHMARK_USER
        app.dependency_overrides[require_authenticated] = lambda: BENCHMARK_USER

        test_record = {
            "id": "rec_perf_001",
            "patient_id": BENCHMARK_USER.uid,
            "patientId": BENCHMARK_USER.uid,
            "doctor_id": BENCHMARK_DOCTOR.uid,
            "doctorId": BENCHMARK_DOCTOR.uid,
            "diagnosis": "Seasonal Allergic Rhinitis",
            "notes": "Cetirizine 10mg daily as needed.",
            "prescription": "Cetirizine 10mg OD",
            "date": "2026-10-08",
        }
        ehr_service._in_memory_records["rec_perf_001"] = test_record

        ehr_latencies = []
        for _ in range(30):
            t0 = time.perf_counter()
            res = await client.get(f"/api/v1/ehr/records/{BENCHMARK_USER.uid}")
            t1 = time.perf_counter()
            assert res.status_code == 200
            ehr_latencies.append((t1 - t0) * 1000)

        results["EHR API"] = {
            "avg": statistics.mean(ehr_latencies),
            "median": statistics.median(ehr_latencies),
            "p95": statistics.quantiles(ehr_latencies, n=20)[18],
        }

        # 3. AI Assistant Latency (15 iterations, within rate limit)
        ai_latencies = []
        for _ in range(15):
            t0 = time.perf_counter()
            res = await client.post(
                "/api/v1/ai/assistant",
                json={"query": "Summarize my active prescriptions."},
            )
            t1 = time.perf_counter()
            assert res.status_code == 200
            ai_latencies.append((t1 - t0) * 1000)

        results["AI Assistant"] = {
            "avg": statistics.mean(ai_latencies),
            "median": statistics.median(ai_latencies),
            "p95": statistics.quantiles(ai_latencies, n=20)[18],
        }

        # 4. Blockchain Proof Creation Latency (10 iterations with real EVM transaction mining)
        app.dependency_overrides[get_current_user] = lambda: BENCHMARK_DOCTOR
        app.dependency_overrides[require_clinical_staff] = lambda: BENCHMARK_DOCTOR

        bc_proof_latencies = []
        for i in range(10):
            rec_id = f"rec_perf_bc_{i}"
            ehr_service._in_memory_records[rec_id] = {
                "id": rec_id,
                "patient_id": BENCHMARK_USER.uid,
                "patientId": BENCHMARK_USER.uid,
                "doctor_id": BENCHMARK_DOCTOR.uid,
                "diagnosis": f"Condition #{i}",
                "date": "2026-10-08",
            }
            t0 = time.perf_counter()
            res = await client.post(
                "/api/v1/blockchain/proof",
                json={"record_id": rec_id, "record_type": "medical_record", "record_version": 1},
            )
            t1 = time.perf_counter()
            assert res.status_code == 201
            bc_proof_latencies.append((t1 - t0) * 1000)

        results["Blockchain Proof Creation"] = {
            "avg": statistics.mean(bc_proof_latencies),
            "median": statistics.median(bc_proof_latencies),
            "p95": statistics.quantiles(bc_proof_latencies, n=20)[18],
        }

        # 5. Blockchain Verification Latency (20 iterations)
        app.dependency_overrides[get_current_user] = lambda: BENCHMARK_USER
        bc_verify_latencies = []
        for i in range(20):
            target_id = f"rec_perf_bc_{i % 10}"
            t0 = time.perf_counter()
            res = await client.post(
                "/api/v1/blockchain/verify",
                json={"record_id": target_id, "record_type": "medical_record", "record_version": 1},
            )
            t1 = time.perf_counter()
            assert res.status_code == 200
            bc_verify_latencies.append((t1 - t0) * 1000)

        results["Blockchain Verification"] = {
            "avg": statistics.mean(bc_verify_latencies),
            "median": statistics.median(bc_verify_latencies),
            "p95": statistics.quantiles(bc_verify_latencies, n=20)[18],
        }

    app.dependency_overrides.clear()

    print("\n" + "=" * 65)
    print("PHASE 6 BENCHMARK MEASUREMENTS (Local Execution)")
    print("=" * 65)
    for comp, metrics in results.items():
        print(f"{comp:<30} | Avg: {metrics['avg']:6.2f} ms | Med: {metrics['median']:6.2f} ms | p95: {metrics['p95']:6.2f} ms")
    print("=" * 65)
