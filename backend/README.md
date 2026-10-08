# AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud
## Phase 4: Secure AI Healthcare Assistance Layer (with Blockchain & Private Cloud)

---

### 1. Architectural Overview

The healthcare management system integrates a privacy-preserving, grounded AI clinical assistance layer into the private cloud backend, operating in synergy with EVM blockchain notarization and Cloud Firestore EHR storage.

```
       +-------------------------------------------------------------+
       |               Flutter Client Application                    |
       |  (Patient Portal / Doctor Portal / Admin Dashboard)         |
       +-------------------------------------------------------------+
                                      |
                         Authorization: Bearer <ID_TOKEN>
                                      v
+=============================================================================+
|                      PRIVATE CLOUD BACKEND (FastAPI)                        |
|                                                                             |
|  [Security & Authentication Layer]                                          |
|   - Cryptographic verification via Firebase Admin SDK                       |
|   - Authoritative UID Extraction & Role-Based Access Control (RBAC)         |
|   - Patient Isolation & Clinician Authorization Checks                      |
|                                                                             |
|  [Phase 4 AI Integration Service]                                           |
|   - Data Minimization Filter (Strips PII, keys, auth tokens)               |
|   - Sliding-Window Rate Limiter (Protects against abuse per UID)            |
|   - Clinical Safety & Pharmacology Engine (Deterministic KB)               |
|   - External LLM Adapter (OpenAI / Gemini / Custom Gateway)                 |
|   - Response Safety Validator (Blocks diagnoses, dose changes)             |
|   - Audit Logging (Sanitized, token-redacted event trail)                  |
|                                                                             |
|  [Phase 3 Blockchain Integrity Engine]                                      |
|   - Canonical Record Serializer & SHA-256 Digest Engine                     |
|   - Web3 EVM Smart Contract Driver (EHRIntegrityRegistry)                  |
+=============================================================================+
        |                             |                             |
        | Off-chain Clinical Data     | Minimized Clinical Data     | Cryptographic Hash & Proof
        v                             v                             v
+-----------------------+     +-----------------------+     +-----------------------+
| Cloud Firestore (EHR) |     |   AI Service Layer    |     |   EVM Smart Contract  |
| - medical_records     |     | - EHR Summarization   |     | - storeProof()        |
| - prescriptions       |     | - Rx Explanation      |     | - getProof()          |
| - blockchain_proofs   |     | - Grounded Assistant  |     | (Integrity Registry)  |
+-----------------------+     +-----------------------+     +-----------------------+
```

> **CRITICAL ARCHITECTURAL PRINCIPLES:**
> 1. **ACTUAL MEDICAL RECORDS REMAIN STRICTLY OFF-CHAIN.**
> 2. **AI IS AN ASSISTIVE TOOL AND DOES NOT REPLACE A QUALIFIED HEALTHCARE PROFESSIONAL.**
> 3. **THE AI CANNOT DIAGNOSE DISEASES, PRESCRIBE MEDICATIONS, OR ALTER DOSES.**
> 4. **AI SERVICES ARE EXCLUSIVELY ACCESSED VIA AUTHENTICATED & AUTHORIZED BACKEND ENDPOINTS.**

---

### 2. Canonical Hashing Process

To achieve deterministic SHA-256 digests across platforms, heterogeneous databases, and serialization formats, records are processed through a strict canonicalization pipeline:

1. **Field Whitelisting**: Transient database metadata (`id`, `createdAt`, `updatedAt`, `viewCount`, document timestamps) are excluded. Only approved clinical fields are included:
   - `patientId`, `doctorId`, `diagnosis`, `notes`, `prescription`, `medicines`, `date`
2. **Whitespace Normalization**: String values are stripped of leading/trailing whitespace.
3. **Medicines Array Normalization**: Nested medicine objects are recursively sorted by key and normalized.
4. **Deterministic JSON Serialization**: Keys are alphabetically sorted, separators are normalized to compact format `("," , ":")`, and encoded as UTF-8 bytes.
5. **SHA-256 Hashing**: A 256-bit SHA-256 cryptographic hash is generated as a 64-character lowercase hexadecimal string.

---

### 3. Smart Contract (`EHRIntegrityRegistry.sol`)

A minimal, secure Solidity smart contract acts as the on-chain notarization registry:
- **Contract Name**: `EHRIntegrityRegistry`
- **Compiler Version**: `^0.8.20`
- **Storage**: `bytes32 recordHash`, `string recordType`, `uint256 recordVersion`, `uint256 timestamp`, `address registeredBy`
- **Key Functions**: `storeProof(...)`, `getProof(...)`

---

### 4. Phase 4: AI Healthcare Assistance Architecture

The Phase 4 AI layer provides patient and physician assistance while enforcing zero-trust data minimization, clinical guardrails, and role-based access control.

#### A. Data Minimization
Before any clinical data reaches the AI service:
- Identifiers such as phone numbers, emails, passwords, auth tokens, and full document trees are stripped.
- For **EHR Summaries**, only the authorized diagnosis, clinical notes, and active medicines are provided.
- For **Prescription Explanations**, only the drug name, dosage, frequency, and administration instructions are passed.

#### B. Grounded AI Health Assistant
- Grounded strictly in the authenticated caller's authorized EHR records.
- Cross-patient data access is blocked at the authorization layer (`HTTP 403 Forbidden`).
- If records lack sufficient information, the model returns a safety disclaimer advising the patient to consult their physician.

#### C. Clinical Safety & Response Validation
Every generated response passes through `validate_ai_response`:
- Prohibits diagnosis claims ("You have...", "Diagnosed with...").
- Prohibits unauthorized dosage modifications ("Increase your dose to...", "Stop taking your medication immediately").
- Appends mandatory clinical disclaimers.

#### D. Rate Limiting
- Protected by a sliding-window rate limiter per authenticated caller UID (`AI_RATE_LIMIT_PER_MINUTE=20`).
- Prevents resource exhaustion and denial-of-service attempts.

---

### 5. AI API Specification

| Method | Endpoint | Allowed Roles | Description |
|---|---|---|---|
| `GET` | `/api/v1/ai/status` | Public / Monitoring | Returns AI operational status and configured model (zero secret exposure) |
| `POST` | `/api/v1/ai/summarize` | Patient (own record), Doctor, Admin | Generates safe, structured summary of authorized EHR record |
| `POST` | `/api/v1/ai/prescription-explanation` | Patient (own record), Doctor, Admin | Generates patient-friendly explanation of prescribed medications |
| `POST` | `/api/v1/ai/assistant` | Patient (self), Doctor, Admin | Answers health questions grounded in caller's authorized clinical data |

---

### 6. Blockchain API Specification

| Method | Endpoint | Allowed Roles | Description |
|---|---|---|---|
| `GET` | `/api/v1/blockchain/status` | Public / Monitoring | Returns EVM connection, contract address, latest block |
| `POST` | `/api/v1/blockchain/proof` | Doctor, Admin | Computes hash and anchors proof to EVM smart contract |
| `POST` | `/api/v1/blockchain/verify` | Patient (self), Doctor, Admin | Computes canonical hash and compares against smart contract |
| `GET` | `/api/v1/blockchain/proof/{record_id}` | Patient (self), Doctor, Admin | Retrieves off-chain stored proof metadata |

---

### 7. Audit Logging

Every AI and blockchain event is recorded via `audit_service`:
- `AI_SUMMARY_REQUESTED` / `AI_SUMMARY_COMPLETED`
- `AI_PRESCRIPTION_EXPLANATION_REQUESTED` / `AI_PRESCRIPTION_EXPLANATION_COMPLETED`
- `AI_ASSISTANT_REQUESTED` / `AI_ASSISTANT_COMPLETED`
- `AI_REQUEST_DENIED` / `AI_PROVIDER_ERROR` / `AI_RESPONSE_VALIDATION_FAILED` / `AI_RATE_LIMIT_EXCEEDED`
- `BLOCKCHAIN_PROOF_CREATED` / `BLOCKCHAIN_VERIFICATION_SUCCESS` / `BLOCKCHAIN_VERIFICATION_FAILED`

All audit payloads are automatically sanitized to redact tokens, keys, passwords, and sensitive PII.

---

### 8. Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `AI_PROVIDER` | `clinical_engine` | AI provider (`clinical_engine`, `openai`, `gemini`, `custom`) |
| `AI_API_KEY` | `None` | External provider API key (server-side only) |
| `AI_MODEL` | `healthcare-clinical-v1` | Model identifier |
| `AI_TIMEOUT_SECONDS` | `30` | Request timeout for external AI gateways |
| `AI_RATE_LIMIT_PER_MINUTE`| `20` | Max AI requests per minute per authenticated UID |
| `BLOCKCHAIN_NETWORK` | `LOCAL DEVELOPMENT BLOCKCHAIN (EVM)` | Network display identifier |
| `BLOCKCHAIN_RPC_URL` | `None` (uses in-process EVM) | JSON-RPC provider URL for external EVM nodes |
| `BLOCKCHAIN_CONTRACT_ADDRESS` | `None` (auto-deploys on launch) | Deployed smart contract address |
| `BLOCKCHAIN_CHAIN_ID` | `1337` | EVM network chain ID |

---

### 9. Running Tests

```powershell
# Run the complete backend test suite (Auth, Services, Health, Blockchain, AI)
.\backend\venv\Scripts\pytest.exe backend\tests -v

# Run Flutter tests
flutter test

# Build Flutter debug APK
flutter build apk --debug
```

---

### 1. Architectural Overview

The Blockchain Integrity & Verification Layer guarantees mathematical, tamper-evident proof of Electronic Health Record (EHR) immutability without sacrificing patient privacy or violating health regulations.

```
       +-------------------------------------------------------------+
       |               Flutter Client Application                    |
       |  (Patient Portal / Doctor Portal / Admin Dashboard)         |
       +-------------------------------------------------------------+
                                      |
                         Authorization: Bearer <ID_TOKEN>
                                      v
+=============================================================================+
|                      PRIVATE CLOUD BACKEND (FastAPI)                        |
|                                                                             |
|  [Security & Authentication Layer]                                          |
|   - Cryptographic verification via Firebase Admin SDK                       |
|   - Authoritative UID Extraction & Role-Based Access Control (RBAC)         |
|   - Patient Isolation & Clinician Authorization Checks                      |
|                                                                             |
|  [Phase 3 Blockchain Integrity Engine]                                      |
|   - Canonical Record Serializer (Sorts keys, normalizes whitespace)         |
|   - SHA-256 Cryptographic Digest Engine                                     |
|   - Web3 EVM Smart Contract Driver (EHRIntegrityRegistry)                  |
|   - Tamper-Detection & Verification Comparator                              |
|   - Sanitized Audit Logger                                                  |
+=============================================================================+
                 |                                           |
                 | Off-chain Clinical Data                   | Cryptographic Hash & Proof
                 v                                           v
+-----------------------------------+     +-----------------------------------+
|      Cloud Firestore (HIPAA)      |     |    EVM Smart Contract Registry    |
|   - /medical_records/{recordId}   |     |    (EHRIntegrityRegistry.sol)     |
|   - /blockchain_proofs/{proofId}  |     |   - storeProof(recordId, hash)    |
|                                   |     |   - getProof(recordId)            |
+-----------------------------------+     +-----------------------------------+
```

> **CRITICAL ARCHITECTURAL PRINCIPLE:**
> **ACTUAL MEDICAL RECORDS REMAIN STRICTLY OFF-CHAIN.**
> Under no circumstances are patient names, diagnoses, prescriptions, clinical notes, or medical files written to the blockchain. Only deterministic, canonical SHA-256 cryptographic digests (32-byte hashes) and essential non-PII integrity metadata are stored on-chain.

---

### 2. Canonical Hashing Process

To achieve deterministic SHA-256 digests across platforms, heterogeneous databases, and serialization formats, records are processed through a strict canonicalization pipeline:

1. **Field Whitelisting**: Transient database metadata (`id`, `createdAt`, `updatedAt`, `viewCount`, document timestamps) are excluded. Only approved clinical fields are included:
   - `patientId`, `doctorId`, `diagnosis`, `notes`, `prescription`, `medicines`, `date`
2. **Whitespace Normalization**: String values are stripped of leading/trailing whitespace.
3. **Medicines Array Normalization**: Nested medicine objects are recursively sorted by key and normalized.
4. **Deterministic JSON Serialization**: Keys are alphabetically sorted, separators are normalized to compact format `("," , ":")`, and encoded as UTF-8 bytes.
5. **SHA-256 Hashing**: A 256-bit SHA-256 cryptographic hash is generated as a 64-character lowercase hexadecimal string.

```
Record Data -> Approved Field Filter -> Canonical JSON -> UTF-8 Bytes -> SHA-256 Hex Hash
```

---

### 3. Smart Contract (`EHRIntegrityRegistry.sol`)

A minimal, secure Solidity smart contract acts as the on-chain notarization registry:

- **Contract Name**: `EHRIntegrityRegistry`
- **Compiler Version**: `^0.8.20`
- **Storage**:
  - `bytes32 recordHash`: The 32-byte SHA-256 cryptographic digest.
  - `string recordType`: Logical entity type (e.g., `medical_record`).
  - `uint256 recordVersion`: Monotonic version number.
  - `uint256 timestamp`: Block timestamp at transaction confirmation.
  - `address registeredBy`: EVM account address of the authorized private cloud signer.
- **Key Functions**:
  - `storeProof(string recordId, bytes32 recordHash, string recordType, uint256 recordVersion)`: Stores or updates the record hash and emits `ProofStored`.
  - `getProof(string recordId)`: View function returning the anchored hash, version, timestamp, and registering address.
- **Security**: No patient data or private keys are accepted or stored in the contract.

---

### 4. Blockchain Network & Real EVM Transactions

- **Development Network**: `LOCAL DEVELOPMENT BLOCKCHAIN (EVM)` powered by Python-native `EthereumTesterProvider` / `py-evm`.
- **Real EVM Execution**: Smart contract bytecode is deployed to an active in-process EVM node.
- **Confirmed Transactions**: All proof operations mine real blocks, generate real 0x-prefixed 32-byte transaction hashes (`tx_hash`), and yield real block receipts.
- **RPC Option**: Configurable to connect to external private Ethereum/Polygon/Hyperledger Besu nodes via `BLOCKCHAIN_RPC_URL`.

---

### 5. Proof Storage (Off-Chain Firestore)

Proof metadata is stored in Cloud Firestore under the `blockchain_proofs` collection:

```json
{
  "proof_id": "proof_ehr_12345",
  "record_id": "ehr_12345",
  "record_type": "medical_record",
  "record_version": 1,
  "record_hash": "a1b2c3d4...",
  "hash_algorithm": "SHA-256",
  "transaction_id": "0x7f8a9b...",
  "block_number": 4,
  "blockchain_network": "LOCAL DEVELOPMENT BLOCKCHAIN (EVM)",
  "contract_address": "0xF2E246BB76DF876Cef8b38ae84130F4F55De395b",
  "blockchain_status": "CONFIRMED",
  "created_at": "2026-10-07T18:00:00Z",
  "created_by_uid": "doc_manikanta"
}
```

**Security Rules (`firestore.rules`)**:
- Read: Authenticated patients and doctors can read proofs to verify integrity.
- Write: Denied to general users. Only Admin or the trusted Private Cloud Backend can create/update proofs.

---

### 6. Verification & Tamper-Detection Workflow

1. **Authentication & RBAC**: The user authenticates via Firebase ID token.
2. **Access Authorization**:
   - Patients can only verify records belonging to their own patient ID.
   - Doctors can verify records they are authorized to manage.
   - Unauthorized attempts return `HTTP 403 Forbidden`.
3. **Fetch & Re-Hash**: The current clinical record is retrieved from Firestore and passed through the deterministic canonical hashing engine, yielding `current_hash`.
4. **On-Chain Query**: The smart contract is queried via `getProof(record_id)` on the EVM, yielding `on_chain_hash`.
5. **Cryptographic Comparison**:
   - If `current_hash == on_chain_hash`: Returns `verified: true`, status `INTEGRITY_VERIFIED`.
   - If `current_hash != on_chain_hash`: Returns `verified: false`, status `INTEGRITY_MISMATCH`. Details: `"Tampering detected: Current record hash does not match immutable blockchain registry."`

---

### 7. API Specification

| Method | Endpoint | Allowed Roles | Description |
|---|---|---|---|
| `GET` | `/api/v1/blockchain/status` | Public / Monitoring | Returns EVM connection, contract address, latest block |
| `POST` | `/api/v1/blockchain/proof` | Doctor, Admin | Computes hash and anchors proof to EVM smart contract |
| `POST` | `/api/v1/blockchain/verify` | Patient (self), Doctor, Admin | Computes canonical hash and compares against smart contract |
| `GET` | `/api/v1/blockchain/proof/{record_id}` | Patient (self), Doctor, Admin | Retrieves off-chain stored proof metadata |

---

### 8. Audit Logging

Every blockchain event is recorded via `audit_service`:
- `BLOCKCHAIN_PROOF_CREATED`
- `BLOCKCHAIN_VERIFICATION_SUCCESS`
- `BLOCKCHAIN_VERIFICATION_FAILED`
- `BLOCKCHAIN_TRANSACTION_FAILED`
- `BLOCKCHAIN_UNAVAILABLE`

All audit payloads are automatically sanitized to redact tokens, keys, and PII.

---

### 9. Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `BLOCKCHAIN_NETWORK` | `LOCAL DEVELOPMENT BLOCKCHAIN (EVM)` | Network display identifier |
| `BLOCKCHAIN_RPC_URL` | `None` (uses in-process EVM) | JSON-RPC provider URL for external EVM nodes |
| `BLOCKCHAIN_CONTRACT_ADDRESS` | `None` (auto-deploys on launch) | Deployed smart contract address |
| `BLOCKCHAIN_CHAIN_ID` | `1337` | EVM network chain ID |

---

### 10. Running Tests

```powershell
# Run the complete backend test suite (Auth, Services, Health, Blockchain)
.\backend\venv\Scripts\pytest.exe backend\tests -v

# Run Flutter analysis
flutter analyze --no-fatal-infos --no-fatal-warnings

# Build Flutter debug APK
flutter build apk --debug
```
