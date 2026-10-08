# Comprehensive Viva & Technical Defense Questions

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## 1. General & Architecture Questions

### Q1: Why did you choose this project?
**Answer:** Healthcare data systems face a difficult trilemma: ensuring patient confidentiality, guaranteeing tamper-proof record integrity, and delivering an accessible, patient-friendly experience. This project bridges these challenges by integrating mobile engineering (Flutter), modern private-cloud APIs (FastAPI), cryptographic decentralized verification (Blockchain), and clinical intelligence (AI) into a cohesive, zero-trust system.

### Q2: What core problem does it solve?
**Answer:** It solves three major issues: (1) Vulnerability of centralized healthcare databases to undetected record tampering or insider fraud; (2) Patient cognitive overload and non-compliance caused by difficult medical jargon; and (3) Scheduling conflicts like double-booking in busy clinical environments.

### Q3: What are the main modules of the system?
**Answer:** The system consists of 9 core modules:
1. Authentication & Role-Based Authorization
2. Patient Management
3. Doctor Management & Credential Mapping
4. Appointment Management with Atomic Slot Locking
5. Prescription Management & Patient Compliance Tracking
6. Private Cloud Backend (FastAPI Gateway)
7. Blockchain Integrity & Tamper Detection
8. Assistive Clinical AI with Safety Guardrails
9. System Security, Firestore Rules & Audit Logging

### Q4: What is the role of Flutter in this system?
**Answer:** Flutter provides a unified, reactive, cross-platform client (supporting Web, Android, iOS, and Desktop) from a single Dart codebase. It renders role-specific interfaces for Patients, Doctors, and Administrators, communicating directly with Firestore for real-time data and with the FastAPI backend for compute-intensive AI and blockchain tasks.

### Q5: Why did you use Firebase?
**Answer:** Firebase provides industry-standard, battle-tested services: Firebase Authentication provides cryptographic RS256 JWT tokens; Cloud Firestore offers scalable NoSQL persistence with real-time listeners and declarative document security rules; and Firebase Cloud Storage provides secure file handling for clinical attachments.

---

## 2. Private Cloud & Backend Questions

### Q6: Why FastAPI instead of Flask or Django?
**Answer:** FastAPI offers native asynchronous I/O (`async`/`await`), automatic schema validation using Pydantic, high throughput comparable to NodeJS/Go, and automatic OpenAPI (Swagger) documentation generation. This makes it ideal for handling concurrent healthcare requests, token verification, and Web3 interactions with minimal latency.

### Q7: What is a "Private Cloud" and how is it implemented here?
**Answer:** A private cloud is an isolated computing environment dedicated to a single organization. In our design, the backend is architected to run inside an isolated Amazon VPC across private subnets with no inbound public internet route. Public clients access the backend exclusively through an Application Load Balancer (ALB) over TLS 1.3, while secrets are injected via AWS Secrets Manager.

### Q8: What is the role of Docker?
**Answer:** Docker packages the FastAPI application, Python runtime, and dependencies into an immutable container based on `python:3.13-slim`. This eliminates environment discrepancies ("works on my machine"), enforces execution as an unprivileged user (`ehruser`, UID 10001), and enables one-click deployment across local servers or cloud container engines (AWS ECS Fargate).

### Q9: What is an API and how does it secure communication?
**Answer:** An Application Programming Interface (API) is a structured communication contract between client and server. In our system, the RESTful API enforces security by requiring an `Authorization: Bearer <token>` header on every sensitive endpoint, validating caller claims and rate limits before routing to business logic.

---

## 3. Blockchain & Cryptography Questions

### Q10: Why use blockchain in a healthcare system?
**Answer:** Centralized databases can be modified by database administrators or compromised through SQL/NoSQL injections without leaving a trace. A blockchain provides an immutable, decentralized append-only ledger. Once a record's cryptographic hash is anchored to a smart contract, any subsequent alteration off-chain can be mathematically proven and flagged immediately.

### Q11: Why is medical data NOT stored directly on the blockchain?
**Answer:** Storing medical records on-chain is architecturally flawed for three reasons:
1. **Privacy Violations (HIPAA/GDPR):** Blockchains are immutable. Storing Protected Health Information (PHI) violates GDPR's "Right to be Forgotten".
2. **Scalability & Cost:** Medical scans (DICOM) and lengthy clinical histories require megabytes of storage; storing raw data on-chain causes chain bloat and high transaction gas costs.
3. **Confidentiality:** Public ledgers expose data to unauthorized observers.
*Solution:* Medical data remains strictly off-chain in Firestore; only a 64-character SHA-256 digest is anchored on-chain.

### Q12: What is SHA-256 and how is hashing different from encryption?
**Answer:** SHA-256 is a deterministic, one-way cryptographic hash function that converts arbitrary input data into a fixed 256-bit (64 hexadecimal character) string. Unlike encryption, hashing is one-way: you cannot reverse the hash to recover the original text. It is used strictly for integrity verification.

### Q13: What is canonicalization and why is it necessary?
**Answer:** In JSON documents, changing whitespace, indentations, or the order of key-value pairs changes the byte sequence and produces a completely different SHA-256 hash. Canonicalization sorts all keys alphabetically and standardizes formatting so the same clinical record always produces the exact same hash.

### Q14: How does tamper detection work in your system?
**Answer:** When an authorized user requests verification:
1. The backend fetches the record from Cloud Firestore.
2. It canonicalizes the record and computes `calculatedHash`.
3. It performs a read-only smart contract call (`getRecordProof`) to retrieve `onChainHash`.
4. If `calculatedHash == onChainHash`, status is `INTEGRITY_VERIFIED`.
5. If an attacker altered any field off-chain, the hashes differ, and the system flags `INTEGRITY_MISMATCH`.

---

## 4. Artificial Intelligence & Clinical Safety Questions

### Q15: What is the purpose of the AI module?
**Answer:** The AI module serves as an assistive tool to bridge the medical communication gap. It generates plain-language summaries of complex EHR notes and explains prescription details (mechanism, timing, side effects) to enhance patient health literacy and treatment compliance.

### Q16: Can the AI diagnose a patient or modify a prescription?
**Answer:** **No, absolutely not.** The system enforces programmatic safety guardrails. Any prompt requesting a clinical diagnosis or suggesting dosage changes is intercepted and rejected with an explicit refusal and advice to consult a licensed physician. All AI responses include a mandatory legal and medical disclaimer.

### Q17: How is patient privacy protected when interacting with AI?
**Answer:** Through our **Data Minimization Layer**: before any prompt is assembled, patient identifiers (full names, phone numbers, addresses, social IDs) are stripped. Only the minimum necessary clinical tokens (e.g., medication name, dosage) are supplied to the model.

### Q18: How do you prevent unauthorized users from passing records to the AI?
**Answer:** The AI endpoints (`/api/v1/ai/summarize`, `/api/v1/ai/prescription-explanation`) enforce strict authorization checks. A patient can only submit their own records; attempting to summarize another patient's record returns `HTTP 403 Forbidden` (IDOR protection).

---

## 5. Security & Access Control Questions

### Q19: How is authentication implemented?
**Answer:** Authentication is handled by Firebase Authentication. Users log in with email and password, and Firebase returns a cryptographically signed RS256 JWT token containing user identity claims and expiration timestamps.

### Q20: How is authorization enforced?
**Answer:** Authorization follows a zero-trust model: **the client is never trusted**. Authorization is enforced in two places:
1. **At the database layer:** `firestore.rules` checks `request.auth.uid` and user role documents before allowing any read/write.
2. **At the API gateway:** FastAPI verifies the token's RS256 signature against Google's public JWKS keys and verifies ownership before executing operations.

### Q21: What is Role-Based Access Control (RBAC)?
**Answer:** RBAC restricts system actions based on assigned user roles:
- **Patients:** Can read only their own records, book appointments, cancel their own appointments, and mark prescription compliance.
- **Doctors:** Can view assigned patients, create clinical records, issue prescriptions, and anchor blockchain proofs.
- **Admins:** Can provision accounts, manage doctor rosters, and view system metrics.

### Q22: How is double-booking prevented?
**Answer:** Through **atomic slot reservation**. When booking an appointment, the system writes to a dedicated `appointment_slots` document with a composite ID: `${doctorId}_${date}_${timeSlot}` inside a Firestore transaction. If two patients attempt to book the same slot simultaneously, the transaction ensures only one succeeds while the second is rejected.

### Q23: How are system secrets protected?
**Answer:** System secrets (API keys, private keys, service account credentials) are never stored in code repositories or frontend builds. They are loaded via server-side environment variables or AWS Secrets Manager. Status endpoints scrub all sensitive keys from JSON responses.

---

## 6. Database Design Questions

### Q24: Why use Cloud Firestore instead of a relational database like PostgreSQL?
**Answer:** Cloud Firestore provides multi-region high availability, document-level transactions, real-time reactive data synchronization with Flutter clients, and declarative security rules (`firestore.rules`) executed directly at the database engine layer.

### Q25: Why separate the Firebase UID from the human-readable Patient ID (`PID-xxxx`)?
**Answer:** Firebase UIDs are 28-character alphanumeric strings generated randomly for authentication security. They are unwieldy for hospital administrative workflows, lab labeling, and verbal communication. Decoupling UIDs from sequential `PID-xxxx` values provides both cryptographic security and human-friendly usability.

### Q26: How do you ensure patients cannot alter their own prescriptions?
**Answer:** In `firestore.rules`, the `update` rule for the `prescriptions` collection uses `affectedKeys()` validation: patients can only update compliance fields (`takenToday`, `takenLog`, `updatedAt`). Attempting to modify medication name, dosage, frequency, or doctor details is rejected with `PERMISSION_DENIED`.
