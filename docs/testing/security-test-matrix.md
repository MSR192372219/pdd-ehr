# Security Test Matrix

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## Security Penetration & Compliance Verification Matrix

| # | Security Test Case | Target / Endpoint | Expected Outcome | Actual Result | Status |
|---|---|---|---|---|---|
| 1 | Missing Authentication Header | `GET /api/v1/ehr/records/{id}` | HTTP 401 Unauthorized | HTTP 401 Unauthorized | **PASS** |
| 2 | Invalid Bearer Token | `GET /api/v1/ehr/records/{id}` | HTTP 401 Unauthorized | HTTP 401 Unauthorized | **PASS** |
| 3 | Malformed Authorization Header | `GET /api/v1/ehr/records/{id}` | HTTP 401 Unauthorized | HTTP 401 Unauthorized | **PASS** |
| 4 | Patient Accesses Own Record | `GET /api/v1/ehr/records/{own_id}`| HTTP 200 OK | HTTP 200 OK | **PASS** |
| 5 | Patient Attempts Access to Other Patient (IDOR)| `GET /api/v1/ehr/records/{other_id}`| HTTP 403 Forbidden | HTTP 403 Forbidden | **PASS** |
| 6 | Patient Attempts Role Escalation to Doctor | `POST /api/v1/ehr/records` | HTTP 403 Forbidden | HTTP 403 Forbidden | **PASS** |
| 7 | Patient Attempts to Create Blockchain Proof | `POST /api/v1/blockchain/proof` | HTTP 403 Forbidden | HTTP 403 Forbidden | **PASS** |
| 8 | Identity Spoofing in Request Payload | Any API endpoint | Server uses verified token claims | Client payload ignored | **PASS** |
| 9 | Doctor Creates Legitimate Medical Record | `POST /api/v1/ehr/records` | HTTP 201 Created | HTTP 201 Created | **PASS** |
| 10 | Doctor Creates Blockchain Proof | `POST /api/v1/blockchain/proof` | HTTP 201 Confirmed (0x...) | Block Mined Receipt | **PASS** |
| 11 | Client Injects Forged Hash | `POST /api/v1/blockchain/proof` | Forged hash discarded | Canonical SHA-256 anchored | **PASS** |
| 12 | Tamper Detection (Unaltered Record) | `POST /api/v1/blockchain/verify` | `verified: true`, `INTEGRITY_VERIFIED` | Matches On-Chain Hash | **PASS** |
| 13 | Tamper Detection (Modified Record) | `POST /api/v1/blockchain/verify` | `verified: false`, `INTEGRITY_MISMATCH`| Tampering Detected | **PASS** |
| 14 | Cross-Patient Blockchain Verification | `POST /api/v1/blockchain/verify` | HTTP 403 Forbidden | HTTP 403 Forbidden | **PASS** |
| 15 | AI EHR Summarization (Authorized) | `POST /api/v1/ai/summarize` | HTTP 200 Structured Summary | Non-diagnostic summary + disclaimer | **PASS** |
| 16 | Cross-Patient AI Summarization (IDOR) | `POST /api/v1/ai/summarize` | HTTP 403 Forbidden | HTTP 403 Forbidden | **PASS** |
| 17 | AI Prescription Explanation | `POST /api/v1/ai/prescription-explanation` | HTTP 200 Explanation | Purpose + timing + safety disclaimer | **PASS** |
| 18 | AI Prompt Injection Containment | `POST /api/v1/ai/assistant` | No data leakage | Pre-retrieval boundary contained | **PASS** |
| 19 | AI Refusal: Medical Diagnosis | `POST /api/v1/ai/assistant` | Refusal + Clinical advice | Refusal enforced | **PASS** |
| 20 | AI Refusal: Dose Alteration | `POST /api/v1/ai/assistant` | Refusal + Doctor referral | Refusal enforced | **PASS** |
| 21 | AI Rate Limiting (> 20 req/min) | `POST /api/v1/ai/assistant` | HTTP 429 Too Many Requests | HTTP 429 Rate Limit Exceeded | **PASS** |
| 22 | Malformed / Empty Input Validation | `POST /api/v1/ai/assistant` | HTTP 422 Unprocessable | Safe structured error | **PASS** |
| 23 | Secrets Disclosure in Status Endpoints | `GET /api/v1/ai/status`, `/blockchain/status` | Zero keys / passwords | No secrets in JSON | **PASS** |
| 24 | Double-Booking Concurrency (Atomic Slots)| Cloud Firestore Transaction | 1 Success, 1 Rejection | Atomic slot locking verified | **PASS** |
| 25 | Cloud Storage Rules Enforcement | `storage.rules` | Authenticated + Patient Isolation | No public read/write | **PASS** |
