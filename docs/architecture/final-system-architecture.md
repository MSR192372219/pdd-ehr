# Final System Architecture

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## 1. Architectural Overview

The system implements a layered, privacy-preserving, defense-in-depth architecture specifically engineered for electronic health record (EHR) management. Sensitive clinical data and heavy compute tasks are segregated into distinct security and execution boundaries across the mobile/web client layer, managed cloud identity, containerized private cloud services, document persistence, decentralized cryptographic verification, and clinical AI inference.

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

## 2. On-Chain vs. Off-Chain Data Segregation

A fundamental design requirement of modern healthcare informatics and privacy regulations (HIPAA, GDPR) is the strict segregation of clinical data from immutable public ledgers. 

The system strictly adheres to the principle that **no medical records, protected health information (PHI), or personally identifiable information (PII) are stored on the blockchain**.

### 2.1 Off-Chain Layer (Confidential Clinical Storage)
All clinical documents, identifiers, and sensitive workflows reside off-chain within Google Cloud Firestore and Firebase Cloud Storage, protected by granular security rules and server-side RBAC:
- **Patient Information**: Demographics, emergency contacts, medical history, allergies.
- **Medical Records**: Clinical notes, doctor diagnoses, treatment plans, lab observations, file attachments.
- **Prescriptions**: Drug names, dosage, frequency, administration timing, start/end dates, instructions, compliance logs.
- **Appointments & Availability**: Doctor schedule slots, booking state, cancellation metadata.
- **Medical Files**: Radiographs, diagnostic lab PDFs, and medical scans in Cloud Storage with authenticated access rules.

### 2.2 On-Chain Layer (Cryptographic Integrity Anchoring)
The blockchain layer functions solely as an immutable cryptographic notary. It stores zero readable healthcare information:
- **Cryptographic Hash**: Fixed 256-bit SHA-256 digest calculated deterministically over canonicalized clinical record fields.
- **Record Identifier**: Opaque alphanumeric identifier linking the proof to the record.
- **Timestamp**: Epoch timestamp recording the block inclusion time.
- **Anchoring Doctor Address**: Ethereum account address of the authorized provider committing the notarization.
- **Transaction Hash & Block Number**: Cryptographic receipt from the EVM network proving block immutability.

---

## 3. Core Architecture Components

### 3.1 Client Layer: Flutter Application
- **Role-Based Portals**: Distinct user interfaces for Patients, Doctors, and Administrators.
- **Direct Auth Integration**: Firebase Authentication SDK handling secure token acquisition and refresh.
- **Dual Communication Path**: Direct, rule-restricted Firestore access for responsive client updates coupled with authenticated HTTPS communication to the FastAPI backend for clinical AI processing and blockchain notarization.

### 3.2 Identity & Access Management: Firebase Authentication
- **Secure Token Authority**: Issues cryptographically signed RS256 JWT tokens.
- **Role-Based Identity**: User roles (`patient`, `doctor`, `admin`) are anchored in Firestore and verified on the server side.
- **Token Verification**: FastAPI verifies Firebase tokens via Google's public key JWKS endpoints on every inbound request.

### 3.3 Private Cloud Backend: FastAPI
- **Gateway & Middleware**: Implements CORS policy, structured request logging with PII scrubbing, rate limiting, and Bearer token dependency injection.
- **Authoritative Authorization**: Re-evaluates requester role and data ownership directly from token claims and database state. Client input parameters are never trusted for authorization decisions.
- **Modular Micro-Services**:
  - `EHRService`: Manages clinical record transformations, validations, and canonical representations.
  - `BlockchainService`: Manages canonical serialization, SHA-256 computation, Web3.py smart contract interaction, and tamper verification.
  - `AIService`: Manages data minimization filtering, prompt containment, grounded clinical explanations, non-diagnostic safety guardrails, and summarization.
  - `AuditService`: Persists structured audit events capturing actors, actions, timestamps, and request outcomes with zero sensitive credential exposure.

### 3.4 Persistence Layer: Cloud Firestore & Cloud Storage
- **Cloud Firestore**: Multi-region NoSQL database hosting users, patients, doctors, appointments, slots, prescriptions, records, and blockchain proof metadata. Protected by declarative `firestore.rules`.
- **Firebase Cloud Storage**: Secure object storage for clinical attachments restricted by `storage.rules`.

### 3.5 Decentralized Ledger: Smart Contract Integrity Registry
- **EHRIntegrityRegistry**: Solidity smart contract deployed to EVM-compatible networks.
- **Proof Storage**: Stores mapping `recordId => ProofRecord(recordHash, doctorAddress, timestamp, blockNumber)`.
- **Tamper Detection**: Dynamically calculates the SHA-256 digest of stored clinical records and performs equality checking against on-chain proof records.

---

## 4. Architectural Boundaries & Isolation

| Boundary | Inbound Protocols | Protection Mechanism | Trust Level |
|---|---|---|---|
| **Client to Firebase Auth** | HTTPS / TLS 1.3 | Firebase SDK, Identity Toolkit | Untrusted client |
| **Client to Firestore** | gRPC / TLS 1.3 | Security Rules (`firestore.rules`), UID matching | Rule-governed |
| **Client to FastAPI Backend** | HTTPS / TLS 1.3 | Bearer Token Verification, Rate Limiting (20/min/UID) | Zero-trust gateway |
| **FastAPI to EVM Node** | JSON-RPC / HTTP | Private key management, local RPC / VPC gateway | Trusted backend |
| **FastAPI to Firestore Admin** | gRPC / TLS 1.3 | Google Application Default Credentials / Service Account | Trusted backend |
