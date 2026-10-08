# Final System Data Flow

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## 1. End-to-End Data Flow Overview

This document specifies the authoritative, step-by-step lifecycle of data across the Flutter client application, Firebase Authentication, the FastAPI Private Cloud gateway, Cloud Firestore, the Solidity smart contract integrity ledger, and the AI clinical intelligence engine.

---

## 2. Authentication & Authorization Flow

All operations begin with strong identity assertion and server-verified role checks. The client application is never trusted for authorization.

```
User (Patient / Doctor / Admin)
     │
     ▼
Flutter Client Application (Login Screen)
     │ [HTTPS / TLS 1.3] (Email + Password)
     ▼
Firebase Authentication Service
     │ (Authenticates credentials & signs RS256 JWT)
     ▼
Firebase Auth Token (ID Token) + UID Returned to Client
     │
     ▼
FastAPI Private Cloud Gateway (`Authorization: Bearer <ID_TOKEN>`)
     │
     ▼
Token Verification Engine (`app.core.auth.verify_firebase_token`)
     │ ├── Verifies RS256 signature against Google JWKS public keys
     │ ├── Asserts token audience (`aud == ehrsystem-32674f7e`)
     │ ├── Verifies expiration (`exp > now`) and issuer (`iss == securetoken.google.com`)
     │ └── Extracts verified UID and authoritative role
     ▼
Authoritative Context (`UserContext`)
     │ └── Request proceeds to endpoint handler with verified identity
```

---

## 3. Electronic Health Record (EHR) Lifecycle Flow

Clinical data ingestion is restricted to verified healthcare providers. All operations produce tamper-evident audit records.

```
Authorized Doctor
     │
     ▼
Flutter Doctor Portal (Clinical Entry Form)
     │ [POST /api/v1/ehr/records with Bearer Token]
     ▼
FastAPI Gateway & Role Verification
     │ (Asserts user role == 'doctor' and active status)
     ▼
EHR Service (`app.services.ehr_service.EHRService`)
     │ ├── Sanitizes & validates clinical payload fields (Pydantic schema)
     │ ├── Assigns immutable record metadata (`recordId`, `doctorUid`, `createdAt`)
     │ └── Prepares document for Cloud Firestore persistence
     ▼
Cloud Firestore (`medical_records` collection)
     │ (Stored securely off-chain under firestore.rules)
     ▼
Audit Service Event
     │ (Asynchronously logs action 'CREATE_EHR_RECORD', doctor UID, patient ID, timestamp)
     ▼
HTTP 201 Created Response to Doctor
```

---

## 4. Blockchain Integrity & Verification Flow

The blockchain acts strictly as an off-chain/on-chain notary. Sensitive medical details never touch the ledger.

### 4.1 Proof Creation & Anchoring Flow
```
EHR Record in Firestore
     │
     ▼
Canonical Representation Engine (`blockchain_service.py`)
     │ ├── Extracts immutable fields (`recordId`, `patientId`, `doctorUid`, `diagnosis`, 
     │ │   `clinicalNotes`, `treatmentPlan`, `medicines`)
     │ ├── Recursively sorts all JSON dictionary keys alphabetically
     │ └── Formats JSON string with delimiters (', ', ': ') and UTF-8 encoding
     ▼
SHA-256 Cryptographic Engine
     │ └── Computes deterministic 64-character hexadecimal digest
     ▼
Web3 / Smart Contract Interaction (`EHRIntegrityRegistry.sol`)
     │ ├── Prepares transaction: `anchorRecordProof(bytes32 recordId, bytes32 recordHash)`
     │ ├── Signs transaction using authorized provider private key
     │ └── Submits transaction to EVM network
     ▼
Mined Block & Transaction Receipt
     │ ├── Transaction Hash (`0x...`)
     │ ├── Block Number
     │ └── Block Inclusion Timestamp
     ▼
Proof Metadata Persistence (`blockchain_proofs` collection)
     │ └── Persists proof document linking `recordId`, `recordHash`, `txHash`, `blockNumber`
     ▼
HTTP 201 Response with On-Chain Anchor Proof
```

### 4.2 Tamper Detection & Verification Flow
```
Verification Request (`POST /api/v1/blockchain/verify`)
     │ (Caller provides recordId; caller identity is verified against record ownership)
     ▼
Fetch Stored Record from Firestore
     │
     ▼
Re-Compute Canonical SHA-256 Digest (`calculatedHash`)
     │
     ▼
Query Smart Contract (`eth_call: getRecordProof(recordId)`)
     │ └── Retrieves immutable `onChainHash` stored in the contract
     ▼
Cryptographic Hash Comparison
     │
     ├── If `calculatedHash == onChainHash`:
     │   └── Return `verified: true`, `status: "INTEGRITY_VERIFIED"`
     │
     └── If `calculatedHash != onChainHash`:
         └── Return `verified: false`, `status: "INTEGRITY_MISMATCH"`,
             with calculated vs on-chain hash details
```

---

## 5. Clinical AI Intelligence Flow

The AI pipeline is protected by multi-stage safety boundaries, data minimization, and prompt isolation.

```
Authorized Patient or Doctor
     │
     ▼
Flutter App Request (Summary / Prescription Explanation / Health Assistant)
     │ [POST /api/v1/ai/... with Bearer Token]
     ▼
FastAPI Gateway & Access Authorization
     │ ├── Verifies caller identity
     │ ├── Asserts patient is requesting their OWN record (or doctor is authorized)
     │ └── Applies sliding-window rate limit (20 requests / min / UID)
     ▼
Data Minimization Layer (`app.services.ai_service.DataMinimizer`)
     │ ├── Strips non-essential PII (names, contact numbers, exact addresses)
     │ └── Extracts only relevant clinical tokens (medication, dosage, diagnosis note)
     ▼
Prompt Construction with Clinical Guardrails
     │ ├── Injects strict system prompt forbidding definitive diagnosis
     │ ├── Injects prohibition against modifying medication doses or regimens
     │ └── Appends mandatory clinical disclaimer requirements
     ▼
AI Provider / Clinical Knowledge Model
     │ (Executes offline grounded knowledge base or cloud LLM inference)
     ▼
Post-Inference Safety Validation (`validate_ai_response`)
     │ ├── Scans output for dangerous medical advice or ungrounded claims
     │ └── Appends mandatory clinical disclaimer:
     │     "This information is AI-generated for educational assistance only 
     │      and does not replace consultation with a qualified medical professional."
     ▼
Audit Service Logging
     │ └── Records AI request type, user UID, and latency (prompt & clinical data excluded)
     ▼
JSON Response Returned to Flutter Client
```
