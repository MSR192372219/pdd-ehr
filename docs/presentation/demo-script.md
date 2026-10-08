# Final Project Demonstration Script

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

**Estimated Duration:** 8 – 12 Minutes  
**Demonstration Scope:** Live presentation of role-based portals, atomic booking, prescription adherence, blockchain tamper detection, and assistive clinical AI.

---

## Preparation & Prerequisites (Pre-Demo Checklist)

1. **Backend Server Running:**
   ```bash
   cd backend
   python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
   *Verify:* Navigate to `http://localhost:8000/docs` to show Swagger UI is alive.
2. **Flutter Application Running:**
   ```bash
   flutter run -d chrome
   ```
   *(Or running on connected Android emulator / device).*
3. **Demo Test Accounts Prepared:**
   - **Admin:** `admin@hospital.com`
   - **Doctor:** `doctor@hospital.com` (e.g., Dr. Rajesh Sharma, Cardiology)
   - **Patient:** `patient@hospital.com` (e.g., John Doe, PID-1001)

---

## Act 1: Role-Based Authentication & Gateway Verification (Time: 0:00 – 1:30)

- **Action:** Open the Flutter app. Highlight the clean Material 3 login screen.
- **Narrative:**
  > *"Good morning. Today we present our AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud. We start at the login screen. Our platform implements zero-trust identity management backed by Firebase Authentication and an asynchronous FastAPI Private Cloud gateway. When a user signs in, their credentials never touch insecure storage; Firebase returns an RS256-signed JWT token which our backend gateway cryptographically verifies on every request."*
- **Action:** Sign in as `admin@hospital.com`.
- **Observation:** Notice the system dynamically identifies the `admin` role and routes the user directly to the **Administrator Dashboard**.

---

## Act 2: Administrator Portal & Provisioning (Time: 1:30 – 3:00)

- **Action:** Navigate through Admin tabs:
  1. **Doctor Management:** Show listed licensed physicians with their IDs, departments, and availability.
  2. **Patient Directory:** Show registered patients with sequential IDs (`PID-1001`, `PID-1002`).
  3. **Counters Security:** Explain that sequential counters are protected in Firestore rules so patients cannot tamper with numbering.
- **Narrative:**
  > *"From the Admin dashboard, authorized hospital administrators provision verified doctor credentials and manage patient records. Notice our dual-identity architecture: the patient's internal Firebase UID is decoupled from their human-readable Patient ID (PID). This guarantees database referential integrity without exposing internal authentication keys."*
- **Action:** Log out of the Admin portal.

---

## Act 3: Doctor Consultation & Clinical Workflow (Time: 3:00 – 5:00)

- **Action:** Sign in as `doctor@hospital.com`.
- **Observation:** App loads the **Doctor Portal**, displaying scheduled consultations, assigned patients, and pending actions.
- **Action:** Open an assigned patient's file (e.g., John Doe).
- **Action:** Create a new clinical medical record:
  - Diagnosis: `Hypertension Stage 1 & Mild Tachycardia`
  - Notes: `Patient presented with resting BP 142/92 mmHg. Advised low-sodium diet and daily exercise.`
  - Treatment Plan: `Oral anti-hypertensive therapy initiated. Follow-up in 4 weeks.`
- **Action:** Issue a structured prescription:
  - Medicine: `Amlodipine 5mg`
  - Frequency: `Once daily`
  - Timing: `Morning after breakfast`
  - Start Date: Today | End Date: 30 days out
- **Narrative:**
  > *"Now logged in as Dr. Sharma, we see the doctor's workflow. The doctor creates an official clinical record and issues a structured prescription. In our architecture, clinical fields—such as dosage and medication names—are immutable once authored. Firestore rules strictly forbid patients from altering these medical fields."*

---

## Act 4: Blockchain Integrity Anchoring & Verification (Time: 5:00 – 7:00)

- **Action:** In the Doctor Portal, click the **Anchor to Blockchain** button on the newly created medical record.
- **Observation:**
  - Loading spinner executes the canonical JSON serialization and SHA-256 computation.
  - Success dialog appears displaying:
    - **Transaction Hash:** `0x4a7b...`
    - **Block Number:** e.g., `#142`
    - **Canonical SHA-256 Digest:** `7d3f...`
- **Narrative:**
  > *"Here is our core blockchain innovation. The doctor anchors the record to our smart contract, EHRIntegrityRegistry. Notice what happens behind the scenes: our backend canonicalizes the clinical record, computes a deterministic SHA-256 hash, and signs a transaction to the EVM network. 
  > Crucially, NO patient names, diagnoses, or clinical notes are stored on the blockchain! Only the 64-character mathematical digest is anchored. This completely satisfies HIPAA and GDPR privacy mandates while providing mathematical non-repudiation."*
- **Action:** Click **Verify Integrity** on the record.
- **Observation:** The dialog confirms: `Status: INTEGRITY_VERIFIED`. A green cryptographic shield is displayed.
- **Action (Explain Tamper Detection):**
  > *"If an attacker gained access to the database and modified the dosage from 5mg to 50mg, the recomputed SHA-256 hash would no longer match the on-chain hash. The verification endpoint immediately detects this discrepancy and returns INTEGRITY_MISMATCH, providing foolproof tamper detection."*

---

## Act 5: Patient Portal & Prescription Compliance (Time: 7:00 – 8:45)

- **Action:** Log out as Doctor; sign in as `patient@hospital.com`.
- **Observation:** App renders the **Patient Portal**.
- **Action:** Open **Appointments**:
  - Show upcoming appointments.
  - Explain atomic slot locking: *"When a patient books a slot, our system writes to an appointment_slots document with a composite key. If another patient clicks at the exact same millisecond, the Firestore transaction rejects the collision, eliminating double-booking."*
- **Action:** Open **Prescriptions**:
  - Show the prescribed `Amlodipine 5mg`.
  - Check the **Today's Dose Taken** checkbox on the compliance checklist.
- **Narrative:**
  > *"Patients can actively participate in their recovery through the compliance checklist. Firestore security rules allow the patient to update their compliance log, but if a malicious script attempts to edit the medicine or dosage, the write is immediately rejected by our database engine."*

---

## Act 6: Assistive Clinical AI in Action (Time: 8:45 – 10:30)

- **Action:** Click the **AI Summary** button next to the doctor's consultation record.
- **Observation:** The AI Summary dialog opens, presenting:
  - Clinical terms translated into plain language (e.g., explaining blood pressure readings).
  - Clear care instructions.
  - Questions to ask during the next follow-up.
  - Mandatory disclaimer at the bottom: *"This information is AI-generated for educational assistance only and does not replace consultation with a qualified medical professional."*
- **Action:** Click **Explain Medication** on `Amlodipine`.
- **Observation:** The AI explains pharmacological purpose, dietary recommendations, and common side effects.
- **Action:** Open the **Patient AI Health Assistant** page.
- **Action:** Enter a query: *"What should I do if I feel dizzy after taking my blood pressure medicine?"*
- **Observation:** Grounded, educational response explaining hydration and sitting down slowly, accompanied by an explicit reminder to contact the prescribing doctor.
- **Narrative:**
  > *"Our AI subsystem is engineered with defense-in-depth safety guardrails:
  > First, pre-inference data minimization strips personal identifiers before sending data to the AI model.
  > Second, the AI strictly refuses any demand to provide a medical diagnosis or alter medication dosages.
  > Third, sliding-window rate limiting caps requests to 20 per minute per user to prevent abuse.
  > Fourth, every response carries mandatory medical disclaimers."*

---

## Act 7: Security Summary & Conclusion (Time: 10:30 – 11:30)

- **Narrative:**
  > *"To summarize our security architecture:
  > 1. The client is NEVER trusted for authorization.
  > 2. Database security rules protect all 10 collections directly at the persistence layer.
  > 3. Medical data remains strictly off-chain, while the EVM blockchain guarantees mathematical immutability.
  > 4. The backend is fully containerized with Docker and specified for private cloud deployment on AWS ECS Fargate with AWS Secrets Manager.
  > 5. Across our testing, all 60 pytest backend tests and all Flutter tests passed with zero errors.
  > Thank you, and we welcome your questions!"*
