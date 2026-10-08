# Security Architecture & Trust Boundaries

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## 1. Security Boundaries & Zero-Trust Principles

```
[ UNTRUSTED ZONE: CLIENT ]
  Flutter Mobile / Web App
  - Only holds ephemeral user tokens
  - NO private keys, NO service accounts, NO AI provider secrets
        │
        │ HTTPS / TLS 1.3
        │ Authorization: Bearer <Firebase_ID_Token>
        ▼
[ PRIVATE CLOUD GATEWAY: FASTAPI ]
  - Firebase Token Verification via Firebase Admin SDK
  - Cryptographic identity extraction (UID extracted from verified token claims)
  - Role-Based Access Control (RBAC): Patient / Doctor / Admin
  - Rate Limiting per UID (Sliding window abuse protection)
  - Security Headers (HSTS, X-Content-Type-Options, X-Frame-Options, Content-Security-Policy)
        │
        ├────────────────────────────┬────────────────────────────┐
        ▼                            ▼                            ▼
[ ISOLATED DATA STORE ]     [ BLOCKCHAIN NOTARIZATION ]   [ AI CLINICAL ENGINE ]
  Cloud Firestore             EVM Smart Contract            Stateless Processing
  - Strict firestore.rules    - Off-chain data rule         - Zero-retention
  - No public read/write      - SHA-256 hashes only         - Data minimization
  - Patient isolation         - No medical data on-chain    - Safety response validation
```

---

## 2. Role-Based Access Control (RBAC) Matrix

| Entity / Resource | Patient | Doctor | Admin | Unauthenticated |
|---|---|---|---|---|
| **Own Medical Records** | Read Only | Read / Write | Read / Manage | Denied (401) |
| **Other Patient Records** | Denied (403) | Denied (403) (unless assigned) | Audit / Manage | Denied (401) |
| **Create Medical Record** | Denied (403) | Allowed | Allowed | Denied (401) |
| **Create Blockchain Proof** | Denied (403) | Allowed | Allowed | Denied (401) |
| **Verify Blockchain Proof** | Allowed (Self) | Allowed (Authorized) | Allowed | Denied (401) |
| **AI EHR Summarization** | Allowed (Self) | Allowed (Authorized) | Allowed | Denied (401) |
| **AI Prescription Explain**| Allowed (Self) | Allowed | Allowed | Denied (401) |
| **AI Health Assistant** | Allowed (Self) | Allowed (Assigned Context) | Allowed | Denied (401) |
| **Audit Log Trail** | Read (Self Only)| Read (Assigned Patient) | Read (System-wide) | Denied (401) |

---

## 3. Threat Mitigation Strategy

1. **Client Identity Spoofing:** The backend rejects any client-supplied `user_id`, `role`, or `patient_id` as the identity authority. The UID is extracted strictly from the cryptographically verified JWT token signed by Google Firebase.
2. **Medical Record Tampering:** If a malicious insider or compromised database directly mutates Firestore clinical fields, the SHA-256 canonical hash computation fails comparison with the immutable on-chain block receipt, immediately raising an `INTEGRITY_MISMATCH` alert.
3. **AI Hallucination & Illegal Medical Practice:** The AI service enforces strict prompt-level and application-level guardrails. It explicitly refuses to provide diagnoses, alter dosages, or recommend discontinued medications, enforcing disclaimers and advising doctor consultation.
4. **Denial-of-Service / Abuse:** An in-memory sliding-window rate limiter throttles calls per caller UID (`AI_RATE_LIMIT_PER_MINUTE=20`).
5. **PII Leakage in Auditing:** The `AuditService` automatically sanitizes metadata, redacting passwords, session tokens, private keys, and clinical narrative notes prior to database commitment.
