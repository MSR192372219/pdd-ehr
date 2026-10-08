# AI & Blockchain Functional Separation & Integration

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## 1. Architectural Philosophy: Division of Concerns

The healthcare management platform maintains strict separation between **Cryptographic Integrity (Blockchain)** and **Assistive Clinical Intelligence (AI)**.

```
       +-------------------------------------------------------------+
       |               Electronic Health Record (EHR)                |
       |  (Diagnosis, Clinical Notes, Prescriptions, Laboratory)    |
       +-------------------------------------------------------------+
                      |                               |
                      | Canonicalization              | Data Minimization
                      v                               v
       +-----------------------------+ +-----------------------------+
       |      BLOCKCHAIN LAYER       | |          AI LAYER           |
       |  - Deterministic SHA-256    | |  - Pharmacology Engine      |
       |  - EVM Proof Registration   | |  - Longitudinal Summarizer  |
       |  - Immutable Notarization   | |  - Patient Guidance Ass't   |
       |  - Tamper Detection         | |  - Safety Guardrails        |
       +-----------------------------+ +-----------------------------+
                      |                               |
                      v                               v
             Mathematical Proof               Clinical Clarity
         ("This record is unchanged")   ("Here is what this means")
```

---

## 2. Hard Boundaries & Forbidden Interactions

1. **NO Medical Data on Blockchain:**
   - Patient names, diagnoses, prescriptions, treatment notes, and files are **never** stored on-chain.
   - The smart contract receives only a 32-byte SHA-256 cryptographic digest.
2. **NO AI Modifying Blockchain Proofs:**
   - The AI service cannot issue, sign, revoke, or alter blockchain transactions or integrity proofs.
   - Proof creation is strictly restricted to licensed clinicians and administrators via the `EHRService`.
3. **NO AI Overriding Authoritative EHR:**
   - The EHR stored in Cloud Firestore is the legal, authoritative medical record.
   - AI outputs are clearly demarcated as assistive summaries with mandatory disclaimers.
4. **NO Private Key Exposure:**
   - The AI subsystem has zero access to Ethereum private keys, signing accounts, or RPC credentials.

---

## 3. Synergy in Clinical Practice

While strictly segregated in data flow, the AI and Blockchain layers act together to provide comprehensive trust and usability for patients and clinicians:

- **Trust:** When a patient views their medical history, the **Blockchain subsystem** cryptographically verifies that their records have not been altered or tampered with since the doctor authored them.
- **Clarity:** Once record integrity is established, the **AI subsystem** translates complex clinical nomenclature, prescribed dosages, and administration schedules into plain-language educational guidance.
- **Auditability:** Every verification attempt, proof creation, and AI inquiry is logged to the tamper-evident **Audit trail**, creating end-to-end regulatory compliance.
