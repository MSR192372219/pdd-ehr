# System Limitations & Constraints

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## 1. Scope of Empirical Limitations

This document outlines the genuine technical, architectural, and operational constraints identified through development, integration testing, and empirical evaluation (Phases 1 through 6).

---

## 2. Identified Subsystem Limitations

### 2.1 Blockchain Subsystem
1. **Local EVM Simulation vs. Production Network:**
   - The current blockchain validation runs on an in-process Ethereum Virtual Machine (EVM) simulation (`eth-tester` with Web3.py). 
   - While the Solidity contract logic (`EHRIntegrityRegistry.sol`), ABI serialization, and transaction signing are production-grade, the system does not currently run against an active public mainnet, public testnet (Sepolia), or private consortium chain (Hyperledger Besu).
2. **Gas Economics & Wallet Management:**
   - In production, transactions require native network gas fees (ETH/MATIC). The current implementation assumes pre-funded development accounts and does not yet include an ERC-2771 meta-transaction relayer for gasless doctor submissions.
3. **Transaction Inclusion Confirmation:**
   - In live decentralized networks, block mining and finality can take between 2 and 15 seconds depending on network congestion, whereas local EVM simulation executes in ~52 ms.

### 2.2 Artificial Intelligence Subsystem
1. **Third-Party Provider Quota & Dependency:**
   - When utilizing cloud-based generative AI (Google Gemini API), availability is subject to external internet connectivity, network jitter, and external provider rate limits.
2. **Offline Fallback Scope:**
   - The local fallback clinical engine relies on structured clinical knowledge bases. While fast (~2.2 ms) and reliable, it lacks the expansive conversational nuance of high-parameter foundational LLMs.
3. **Assistive Nature & Non-Diagnostic Boundary:**
   - By intentional design, the AI strictly refuses to formulate definitive medical diagnoses or alter medication dosages. While this is a critical safety feature, users must understand it does not replace in-person clinical consultations.

### 2.3 Cloud & Infrastructure Subsystem
1. **Deployment Readiness vs. Live Cloud Infrastructure:**
   - **Current Status: LOCAL TESTED & DEPLOYMENT READY.**
   - The Docker container, AWS VPC topology, security group specifications, and Secrets Manager architecture are fully defined in [`backend/DEPLOYMENT.md`](file:///c:/Users/srinu/healthcare_management/backend/DEPLOYMENT.md). However, the system is not actively provisioned on live AWS ECS Fargate or physical cloud data centers.
2. **In-Memory Rate Limiting:**
   - The current API rate limiter (20 requests/minute/UID) uses an in-memory sliding window. In a horizontally auto-scaled multi-container ECS cluster, this rate limiter must be backed by a centralized distributed cache (such as Redis/ElastiCache) to prevent limiter fragmentation.

### 2.4 Clinical Data & Standard Interoperability
1. **Absence of Full HL7 FHIR Protocol:**
   - While records follow a structured, strongly-typed JSON schema, the platform does not currently parse or export native HL7 FHIR (Fast Healthcare Interoperability Resources) R4 bundles.
2. **Storage of Binary Medical Imaging:**
   - Medical scans (DICOM/PDF) are uploaded to Cloud Storage and referenced via URLs; heavy binary payloads are not embedded directly in Firestore documents or on-chain proofs.
