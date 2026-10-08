# AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud

---

## Abstract

Modern electronic health record (EHR) management systems face three critical challenges: data fragmentation and vulnerability to unauthorized tampering, patient cognitive overload when interpreting clinical jargon, and the need for scalable, zero-trust cloud infrastructure that complies with stringent healthcare privacy regulations (HIPAA, GDPR).

This system presents an integrated solution combining a cross-platform Flutter client, a containerized FastAPI Private Cloud backend, Cloud Firestore for scalable off-chain persistence, decentralized Ethereum smart contracts for cryptographic integrity anchoring, and safety-governed Clinical AI for health literacy enhancement. 

Crucially, the architecture establishes strict segregation between off-chain clinical data and on-chain verification proofs: all sensitive medical records reside off-chain under declarative access rules, while the blockchain records only deterministic SHA-256 hashes of canonicalized clinical records. If an off-chain record is tampered with, the system immediately flags the discrepancy (`INTEGRITY_MISMATCH`). The AI subsystem provides patient-friendly record summarization and medication explanations while enforcing strict guardrails against autonomous medical diagnosis or dosage alteration.

---

## Key Features

- **Multi-Role Healthcare Portals:** Tailored user interfaces for Patients, Doctors, and Administrators with role-based routing.
- **Dual-Identity Mapping:** Decouples internal Firebase Auth UIDs from human-readable clinical identifiers (`PID-xxxx` for patients, `DOC-xxxx` for doctors).
- **Atomic Double-Booking Protection:** Dedicated `appointment_slots` collection with composite keys (`${doctorId}_${date}_${timeSlot}`) locked via transactional writes to prevent scheduling race conditions.
- **Prescription & Compliance Tracking:** Doctors issue structured prescriptions with immutable clinical fields; patients track daily compliance (`takenToday`, `takenLog`) without permission to alter dosages.
- **Blockchain Integrity & Tamper Detection:** Canonical JSON serialization and SHA-256 hashing anchored to the `EHRIntegrityRegistry` Solidity smart contract. Instant verification of record authenticity and detection of off-chain database tampering.
- **Strict Off-Chain Data Privacy:** Zero Protected Health Information (PHI) or Personally Identifiable Information (PII) is stored on the blockchain.
- **Assistive Clinical AI with Safety Guardrails:** Plain-language EHR summarization, pharmacology explanations, and a grounded health assistant. Enforces programmatic refusals against diagnostic pronouncements and dosage modifications, accompanied by mandatory medical disclaimers.
- **Zero-Trust Backend Gateway:** FastAPI private cloud gateway that cryptographically verifies Google-issued RS256 JWT tokens and re-evaluates authorization server-side on every request.
- **PII-Sanitized Audit Logging:** Centralized logging of access events and transactions with automatic redaction of authorization tokens, passwords, and sensitive health data.

---

## Technology Stack

| Layer | Technologies & Tools |
|---|---|
| **Frontend / Client** | Flutter 3.x, Dart, Material 3 Design |
| **Authentication** | Firebase Authentication (Email/Password, OAuth2 / RS256 JWT) |
| **Database & Cloud Storage** | Cloud Firestore, Firebase Cloud Storage, Security Rules (`firestore.rules`, `storage.rules`) |
| **Private Cloud Backend** | Python 3.13, FastAPI, Uvicorn, Pydantic v2, PyJWT, Web3.py |
| **Blockchain & Smart Contracts**| Solidity (^0.8.19), Ethereum Virtual Machine (EVM), `eth-tester`, Web3.py |
| **Artificial Intelligence** | Google Gemini API / Fallback Knowledge Engine, Data Minimization Layer |
| **Containerization & Cloud** | Docker (`python:3.13-slim`), AWS VPC / ECS Fargate specification |
| **Testing & Quality Assurance** | Pytest, AnyIO, Flutter Analyze, Flutter Test |

---

## System Architecture

```
                         ┌─────────────────────┐
                         │     Flutter App     │
                         │                     │
                         │ Patient / Doctor /  │
                         │ Admin Portals       │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │ Firebase            │
                         │ Authentication      │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │ FastAPI Private     │
                         │ Cloud Backend       │
                         └──────────┬──────────┘
                                    │
             ┌──────────────────────┼──────────────────────┐
             │                      │                      │
             ▼                      ▼                      ▼
      ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
      │ EHR Service │       │ AI Service  │       │ Blockchain  │
      │             │       │             │       │ Service     │
      └──────┬──────┘       └─────────────┘       └──────┬──────┘
             │                                            │
             ▼                                            ▼
      ┌─────────────┐                              ┌─────────────┐
      │ Firestore   │                              │ Blockchain  │
      │ Actual EHR  │                              │ Integrity   │
      └─────────────┘                              │ Proof       │
                                                   └─────────────┘

                         ┌─────────────────────┐
                         │    Audit Service    │
                         └─────────────────────┘
```

---

## Implemented Modules

1. **Authentication & Authorization:** Multi-portal login, Firebase RS256 token verification, server-side RBAC.
2. **Patient Management:** Profile management, demographic updates, sequential `PID-xxxx` tracking.
3. **Doctor Management:** Provisioning of verified doctors, specialty mapping, assigned patient record access.
4. **Appointment Management:** Real-time schedule browsing, atomic slot reservation, cancellation slot release, double-booking prevention.
5. **Prescription Management:** Structured prescription orders, dosage timing, patient daily compliance tracking (`takenToday`).
6. **Private Cloud Backend:** FastAPI gateway, Pydantic schemas, dependency-injected auth, PII-sanitized audit service.
7. **Blockchain Integrity:** Canonical JSON sorting, SHA-256 digest engine, Solidity smart contract anchoring, tamper detection.
8. **Clinical AI Intelligence:** EHR summarization, prescription explanation, grounded health assistant, data minimization, safety guardrails.
9. **Security & Audit:** Declarative Firestore rules, Cloud Storage rules, API rate limiting, secrets management hygiene.

---

## Security Architecture

- **Untrusted Client:** The client is never trusted for authorization. All roles, record ownerships, and permissions are asserted server-side.
- **In-Depth Access Control:**
  - `firestore.rules` enforces collection-level constraints for 10 collections.
  - `storage.rules` restricts medical uploads to validated MIME types (`pdf`, `image/*`, `dicom`) up to 25 MB with patient-boundary isolation.
  - FastAPI endpoints re-verify token claims and record ownership, rejecting unauthorized cross-patient requests (IDOR) with `HTTP 403 Forbidden`.
- **AI Privacy & Safety:** Pre-inference data minimization strips personal identifiers. Refuses diagnostic demands and dosage changes.
- **Secret Protection:** Secrets (`GEMINI_API_KEY`, `WEB3_PRIVATE_KEY`, service account keys) are stored in server environments; diagnostic status endpoints scrub all credentials.

---

## Blockchain Integrity Verification

```
Original Record (Firestore)
         │
         ▼
Canonical Representation (Sorted Keys, Whitespace Normalized)
         │
         ▼
SHA-256 Hashing Engine
         │
         ▼
Cryptographic Digest (64 Hex Characters)
         │
         ▼
Solidity Contract (`anchorRecordProof`)
         │
         ▼
On-Chain Proof Receipt (`txHash`, `blockNumber`)
```

- **Off-Chain Verification:** Complete records remain in Firestore. Only the SHA-256 digest is stored on-chain.
- **Tamper Detection:** When a record is verified, the server re-calculates the canonical hash and checks it against the smart contract. Any modified character triggers `INTEGRITY_MISMATCH`.

---

## AI Capabilities & Safety

- **Assistive Scope:** The AI system is assistive and educational; it explicitly disclaims diagnostic authority and never replaces qualified medical professionals.
- **Summarization (`/api/v1/ai/summarize`):** Translates physician clinical notes into structured, accessible summaries.
- **Prescription Explanation (`/api/v1/ai/prescription-explanation`):** Breaks down medication purpose, administration instructions, and common side effects.
- **Rate Limiting:** Capped at 20 requests per minute per UID to prevent abuse.

---

## Private Cloud Infrastructure

- **Containerization:** Packaged with `python:3.13-slim` running as an unprivileged user (`ehruser`).
- **AWS Target Architecture:** Application Load Balancer in public subnets with TLS termination; FastAPI containers in private subnets with NAT Gateway egress; secrets injected via AWS Secrets Manager.
- **Status:** **Local Tested & Deployment Ready** (see Deployment section).

---

## Installation & Setup

### Prerequisites
- Flutter SDK (v3.19+ or higher)
- Python 3.11+ (Python 3.13 recommended)
- Git

### 1. Clone the Repository
```bash
git clone <repository-url>
cd healthcare_management
```

### 2. Backend Setup
```bash
# Navigate to backend directory
cd backend

# Create and activate virtual environment
python -m venv venv
# On Windows:
.\venv\Scripts\activate
# On Linux/macOS:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 3. Frontend Setup
```bash
# Return to project root
cd ..

# Fetch Flutter dependencies
flutter pub get
```

---

## Running the Applications

### Running the Backend Server
```bash
# From project root with venv activated:
cd backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
The API documentation is available at: `http://localhost:8000/docs`

### Running the Flutter Client
```bash
# Run on Chrome (Web)
flutter run -d chrome

# Or run on connected Android device/emulator
flutter run -d android
```

---

## Testing & Quality Assurance

### Run Backend Pytest Suite
```bash
# From project root:
& "backend\venv\Scripts\pytest.exe" backend/tests -v
```
*Current Result:* **60 passed in ~60s**

### Run Flutter Analysis & Tests
```bash
# Run static code analysis
flutter analyze

# Run Flutter automated tests
flutter test

# Build debug APK
flutter build apk --debug
```

---

## Deployment Status

- **Current State:** **LOCAL TESTED & DEPLOYMENT READY**
- **Validation Scope:** Validated against comprehensive unit, integration, penetration, and performance benchmarks locally and in-process.
- **Cloud Readiness:** Dockerfile, AWS VPC architecture specification, security group rules, and Secrets Manager integration are fully documented in [`backend/DEPLOYMENT.md`](file:///c:/Users/srinu/healthcare_management/backend/DEPLOYMENT.md). The application is ready for ECS Fargate deployment but has not yet been deployed to a live production cluster.

---

## Limitations

1. **Simulated EVM in Development:** Development uses an in-process EVM node (`eth-tester`); live deployment requires a dedicated Ethereum L2 or enterprise consortium network (Besu/Quorum).
2. **AI Provider Latency:** Live cloud LLM inference is subject to provider rate limits and network latency (local fallback engine operates in ~2.2 ms).
3. **No Direct FHIR/HL7 Interface:** Clinical records use structured JSON schemas rather than full FHIR R4 resources.
4. **Single-Region Validation:** Benchmarking was conducted locally; cross-region multi-datacenter latency has not been empirically measured.

---

## Future Scope

1. **Enterprise Blockchain Deployment:** Migration from development EVM to Hyperledger Besu or Polygon L2 with AWS KMS transaction signing.
2. **FHIR / HL7 Interoperability:** Native translation of Firestore medical records into standardized HL7 FHIR R4 clinical bundles.
3. **Multilingual Health Assistant:** Expanding the AI assistant to support multi-language consultations for diverse patient populations.
4. **Push Notifications:** Automated appointment reminders and prescription dose alerts via Firebase Cloud Messaging (FCM).
5. **Production AWS Deployment:** Provisioning live VPC, ALB, and ECS Fargate tasks using Terraform or AWS CDK.
