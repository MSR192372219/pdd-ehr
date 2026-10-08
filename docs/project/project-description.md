# Project Description & Scope

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## 1. Problem Statement

Healthcare institutions handle highly sensitive patient clinical data across heterogeneous, often fragmented software systems. Traditional electronic health record (EHR) management architectures suffer from several critical shortcomings:

1. **Vulnerability to Unauthorized Record Tampering:** Centralized databases remain vulnerable to insider tampering, administrative credential compromise, or silent data corruption. Without cryptographic verification, modified diagnoses or altered prescriptions cannot be easily proven in a court of law or medical audit.
2. **Cognitive Burden on Patients (Health Literacy Gap):** Clinical notes, lab reports, and medication regimens are authored in specialized medical jargon. Patients frequently struggle to comprehend their treatment instructions, leading to non-compliance, medication errors, and preventable hospital readmissions.
3. **Double-Booking & Concurrency Collisions:** Inadequately synchronized scheduling platforms allow concurrent bookings of the same consultation slot, wasting clinical capacity and frustrating patients.
4. **Cloud Security & Compliance Risks:** Deploying healthcare systems on public cloud infrastructure without strict network isolation, least-privilege role boundaries, and secret management exposes Protected Health Information (PHI) to regulatory penalties under HIPAA and GDPR.

---

## 2. Proposed Solution

This project implements an integrated, privacy-preserving, defense-in-depth healthcare management system combining:

- **Cross-Platform Multi-Role Portals:** A responsive Flutter client providing customized workflows for Patients, Doctors, and Administrators with strict role separation.
- **Off-Chain Cloud Persistence:** Scalable NoSQL storage in Cloud Firestore governed by declarative security rules (`firestore.rules`) enforcing strict read/write boundaries and document-level immutability.
- **Private Cloud API Gateway:** An asynchronous FastAPI backend acting as a zero-trust mediator. It cryptographically validates Firebase-issued RS256 JWT tokens, re-evaluates authorization server-side, and sanitizes audit logs.
- **Decentralized Blockchain Integrity Notary:** A Solidity smart contract (`EHRIntegrityRegistry.sol`) running on an EVM network. Deterministically generated SHA-256 hashes of canonicalized clinical records are anchored on-chain. Sensitive medical data remains strictly off-chain, ensuring compliance with privacy regulations while guaranteeing mathematical tamper evidence.
- **Safety-Governed Assistive AI:** Clinical AI capabilities (EHR summarization, prescription explanation, grounded health assistant) incorporating data minimization, sliding-window rate limiting, programmatic refusal to diagnose or modify doses, and mandatory clinical disclaimers.

---

## 3. Project Objectives

1. **Establish a Secure, Multi-Role EHR Platform:**
   - Implement role-based portals for Patients, Doctors, and Admins with authenticated routing.
   - Decouple internal authentication UIDs from sequential human-readable identifiers (`PID-xxxx`).
2. **Eliminate Scheduling Race Conditions:**
   - Implement atomic reservation locks (`appointment_slots`) preventing double-booking and ensuring clean slot release on cancellation.
3. **Guarantee Clinical Prescription Integrity & Compliance:**
   - Enable doctors to issue structured prescriptions while locking clinical fields against patient modification.
   - Provide patients with a daily adherence checklist to log medication compliance.
4. **Implement Mathematical Tamper Detection:**
   - Create a deterministic canonical serialization and SHA-256 hashing engine.
   - Anchor record hashes to an EVM smart contract, enabling instant verification (`INTEGRITY_VERIFIED` vs `INTEGRITY_MISMATCH`).
5. **Enhance Patient Health Literacy Responsibly:**
   - Deliver plain-language summaries of medical records and pharmacological explanations of prescribed medications.
   - Enforce rigorous safety guardrails that prevent autonomous diagnosis or dosage tampering.
6. **Design Enterprise Private-Cloud Infrastructure:**
   - Containerize the backend with Docker, isolate compute tasks in private subnets, and configure secret injection via AWS Secrets Manager.

---

## 4. System Scope

### 4.1 In Scope (Implemented Capabilities)
- Authentication and authorization via Firebase Auth and FastAPI token verification.
- Patient profile creation, self-management, and administrative directory.
- Doctor provisioning, specialty catalog, and assigned patient record access.
- Atomic appointment slot booking and cancellation.
- Prescription creation, immutability enforcement, and patient adherence tracking.
- Canonical JSON serialization and SHA-256 digest generation.
- Solidity smart contract deployment, proof anchoring, and verification on EVM development node.
- AI EHR summarization, prescription explanation, and grounded Q&A health assistant.
- In-memory sliding-window rate limiting (20 req/min/UID).
- Comprehensive unit, integration, penetration, and performance test suites.

### 4.2 Out of Scope (Explicit Boundaries)
- Autonomous medical diagnosis or autonomous clinical decision-making.
- Autonomous prescription modification.
- Storage of Protected Health Information (PHI) directly on a public blockchain.
- Live production deployment to physical AWS infrastructure (designed and deployment-ready, tested locally).
- Direct billing, health insurance claims processing, or electronic payment gateway integration.

---

## 5. Expected Benefits

- **Cryptographic Trust:** Patients, physicians, and auditors can mathematically verify that a medical record has not been altered since creation.
- **Patient Empowerment:** Translating clinical terminology into accessible language improves medication adherence and patient engagement.
- **Zero-Trust Security:** Server-side token validation and declarative Firestore rules protect data even if the mobile client is modified or compromised.
- **Operational Efficiency:** Atomic slot reservations eliminate double-booking errors and scheduling conflicts.
- **Regulatory Alignment:** Segregating off-chain PHI from on-chain hashes respects patient privacy mandates under HIPAA and GDPR.
