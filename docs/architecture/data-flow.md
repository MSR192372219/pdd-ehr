# End-to-End Data Flow Architecture

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## 1. Authentication & Identity Data Flow

```text
Flutter App                Firebase Auth              FastAPI Backend              EHR Service
    │                            │                           │                          │
    ├─► Credentials (Email/Pass)─┼─►                         │                          │
    │   SignInWithPassword()     │                           │                          │
    │◄──JWT ID Token (Signed)────┤                           │                          │
    │                            │                           │                          │
    ├─► HTTP Request (Header: "Authorization: Bearer <ID_TOKEN>")───────────────────────┤
    │                            │                           │                          │
    │                            │◄──Verify ID Token Key─────┤                          │
    │                            ├───Decoded Claims (UID)───►│                          │
    │                            │                           ├──► Resolve User Role────►│
```

---

## 2. Clinical Record & Blockchain Proof Notarization Data Flow

```text
Doctor Portal               FastAPI Backend             Cloud Firestore             EHRIntegrityRegistry
    │                              │                           │                     (EVM Smart Contract)
    ├─► Create Record (Diagnosis)─►│                           │                              │
    │   POST /api/v1/ehr/records   ├──► Write Record (Off-Chain)─────────────────────────────►│
    │                              │    /medical_records/{id}  │                              │
    │◄──Record Created (ID)────────┤                           │                              │
    │                              │                           │                              │
    ├─► Anchor Integrity Proof────►│                           │                              │
    │   POST /api/v1/blockchain/proof                          │                              │
    │                              ├──► Canonicalize JSON      │                              │
    │                              ├──► Compute SHA-256 Hash   │                              │
    │                              ├──► Invoke storeProof(id, hash)──────────────────────────►│
    │                              │◄──Confirmed Block Receipt & TxHash───────────────────────┤
    │                              ├──► Store Proof Metadata──►│                              │
    │                              │    /blockchain_proofs/{id}│                              │
    │◄──Proof Confirmed (TxHash)───┤                           │                              │
```

---

## 3. Cryptographic Verification & Tamper Detection Data Flow

```text
Patient / Doctor            FastAPI Backend             Cloud Firestore             EHRIntegrityRegistry
    │                              │                           │                     (EVM Smart Contract)
    ├─► Verify Record Integrity───►│                           │                              │
    │   POST /api/v1/blockchain/verify                         │                              │
    │                              ├──► Fetch Clinical Record─►│                              │
    │                              │◄──Current Field Values────┤                              │
    │                              ├──► Compute Current SHA-256│                              │
    │                              ├──► Query getProof(id)───────────────────────────────────►│
    │                              │◄──Anchored On-Chain Hash─────────────────────────────────┤
    │                              │                                                          │
    │                              ├──► Compare Hashes:                                       │
    │                              │    - Current == On-Chain: INTEGRITY_VERIFIED             │
    │                              │    - Current != On-Chain: INTEGRITY_MISMATCH (TAMPERING) │
    │◄──Verification Result────────┤                                                          │
```

---

## 4. Grounded AI Health Inquiry & Data Minimization Data Flow

```text
Patient                     FastAPI Backend             Cloud Firestore             AI Clinical Engine
    │                              │                           │                           │
    ├─► Ask AI Health Assistant───►│                           │                           │
    │   POST /api/v1/ai/assistant  ├──► Fetch Authorized EHR──►│                           │
    │                              │◄──Patient Records─────────┤                           │
    │                              ├──► DATA MINIMIZATION FILTER                           │
    │                              │    - Strip patient names, emails, phones              │
    │                              │    - Strip auth tokens, database metadata             │
    │                              │    - Extract minimal clinical context                 │
    │                              ├──► Minimized Context + Prompt────────────────────────►│
    │                              │◄──Raw Assistive Response──────────────────────────────┤
    │                              ├──► SAFETY & RESPONSE VALIDATION                       │
    │                              │    - Check for illegal diagnosis claims               │
    │                              │    - Check for dosage alteration suggestions          │
    │                              │    - Append mandatory clinical disclaimers            │
    │                              ├──► Log AI Audit Event (Sanitized)                     │
    │◄──Grounded Answer + Note─────┤                                                       │
```
