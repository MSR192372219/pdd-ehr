# Final Database Design & Schema Specification

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## 1. Persistence Overview

The primary persistence engine is **Google Cloud Firestore**, a multi-region, distributed NoSQL document database configured with strong consistency for document-level transactions. 

The database schema is strictly enforced through declarative security rules (`firestore.rules`) and server-side Pydantic validation schemas. Below are the 10 collections that exist in the system.

---

## 2. Collection Directory & Detailed Schemas

### 2.1 Collection: `users`
- **Purpose:** Primary identity directory holding user authentication profiles and authoritative system roles.
- **Document ID:** Firebase Auth UID (`request.auth.uid`).
- **Key Fields:**
  - `email` (string): User email address.
  - `role` (string): System access role (`patient`, `doctor`, `admin`). Immutable for non-admins.
  - `name` (string): Full name of the user.
  - `patientId` (string, optional): Linked human-readable patient identifier (`PID-xxxx`). Immutable for non-admins.
  - `status` (string): Account status (`active`, `suspended`).
  - `createdAt` (timestamp): Account creation timestamp.
- **Access Control:** User can read/write their own document; Doctors and Admins can read user profiles. Role changes are restricted strictly to Admins.
- **Immutable Fields (for non-admins):** `role`, `patientId`.

### 2.2 Collection: `counters`
- **Purpose:** Provides atomic sequential counters for generating monotonic, human-readable IDs (`PID-1001`, etc.).
- **Document ID:** Counter name (e.g., `patients`).
- **Key Fields:**
  - `current` (integer): Current sequential counter value.
- **Access Control:** Strict Admin-only access (`read, write: if isAdmin()`). Normal patients and doctors are strictly denied.

### 2.3 Collection: `patients`
- **Purpose:** Comprehensive clinical profile and demographic repository for registered patients.
- **Document ID:** Sequential Patient ID (e.g., `PID-1001`) or Auth UID.
- **Key Fields:**
  - `uid` (string): Foreign key linking to `users` collection UID.
  - `patientId` (string): Unique human-readable patient identifier.
  - `fullName` (string): Patient's full name.
  - `dob` (string): Date of birth.
  - `gender` (string): Gender.
  - `bloodGroup` (string): Blood type (e.g., `O+`, `A-`).
  - `phone` (string): Contact number.
  - `emergencyContact` (string): Emergency contact details.
  - `address` (string): Residential address.
  - `medicalHistory` (array/string): Known chronic conditions and past surgeries.
  - `allergies` (array/string): Drug and environmental allergies.
  - `createdAt` (timestamp): Registration timestamp.
- **Access Control:** Admins and Doctors can read/write all patient profiles. Patients can read their own profile and update demographic fields, but cannot modify `role` or `patientId`.

### 2.4 Collection: `doctors`
- **Purpose:** Professional credential directory and schedule catalog for licensed medical providers.
- **Document ID:** Doctor ID or Doctor Auth UID.
- **Key Fields:**
  - `uid` (string): Doctor Firebase Auth UID.
  - `doctorId` (string): Unique doctor identifier.
  - `name` (string): Full doctor name and professional title.
  - `specialization` (string): Clinical specialty (e.g., Cardiology, General Medicine).
  - `department` (string): Hospital department.
  - `qualification` (string): Medical degrees and credentials.
  - `availableDays` (array of strings): Days of clinical availability.
  - `availableHours` (map/string): Working hours and consultation windows.
  - `status` (string): Operational status (`active`, `on-leave`).
- **Access Control:** Authenticated users can read doctor listings to book appointments. Write access is restricted to Admins.

### 2.5 Collection: `appointments`
- **Purpose:** Tracks clinical consultation bookings between patients and doctors.
- **Document ID:** Unique appointment identifier (UUID or auto-generated Firestore ID).
- **Key Fields:**
  - `patientId` (string): UID or formatted ID of the booking patient.
  - `patientName` (string): Name of the patient.
  - `doctorId` (string): ID of the consulting doctor.
  - `doctorName` (string): Name of the consulting doctor.
  - `date` (string): Appointment date (`YYYY-MM-DD`).
  - `timeSlot` (string): Time window (e.g., `10:00 AM - 10:30 AM`).
  - `status` (string): Current state (`Scheduled`, `Booked`, `Completed`, `Cancelled`).
  - `symptoms` (string): Patient-reported chief complaint.
  - `createdAt` (timestamp): Booking creation timestamp.
- **Access Control:** Patients can read their own appointments; Doctors and Admins can read all appointments. Patients can create appointments for themselves and update status to `Cancelled`.

### 2.6 Collection: `appointment_slots`
- **Purpose:** High-concurrency synchronization table preventing race conditions and double-booking.
- **Document ID:** Composite key `${doctorId}_${date}_${timeSlot}`.
- **Key Fields:**
  - `doctorId` (string): Doctor identifier.
  - `patientId` (string): UID of the patient holding the reservation.
  - `date` (string): Date string.
  - `timeSlot` (string): Time slot string.
  - `status` (string): Lock status (`active`).
  - `createdAt` (timestamp): Reservation timestamp.
- **Access Control:** All authenticated users can read to inspect schedule availability. Patients can atomically create a reservation for their own UID. Deletions are allowed upon cancellation by the holding patient, doctor, or admin. Overwrites by other patients are rejected.

### 2.7 Collection: `medicines`
- **Purpose:** Formulary master catalog containing standard medication names, classifications, and stock units.
- **Document ID:** Auto-generated ID or medicine code.
- **Key Fields:**
  - `name` (string): Generic or brand name of medication.
  - `category` (string): Pharmacological category (e.g., Antibiotic, Analgesic).
  - `dosageForm` (string): Tablet, Capsule, Syrup, Injection.
  - `strength` (string): Standard unit strength (e.g., `500mg`, `10mg/ml`).
- **Access Control:** Authenticated users can read formulary data; write access is restricted to Doctors and Admins.

### 2.8 Collection: `prescriptions`
- **Purpose:** Clinical prescription orders with daily patient adherence and compliance tracking.
- **Document ID:** Unique prescription identifier.
- **Key Fields:**
  - `patientId` (string): UID or patient ID of the recipient.
  - `patientName` (string): Patient's name.
  - `doctorId` (string): Doctor ID.
  - `doctorUid` (string): Firebase UID of prescribing doctor.
  - `doctorName` (string): Prescribing doctor's name.
  - `diagnosis` (string): Medical diagnosis prompting the prescription.
  - `medicines` (array of maps):
    - `name` (string): Medication name.
    - `dosage` (string): Prescribed dose (e.g., `500mg`).
    - `frequency` (string): Frequency (e.g., `Twice daily`).
    - `timing` (string): Administration timing (e.g., `After meals`).
    - `startDate` (string): Prescription start date.
    - `endDate` (string): Prescription conclusion date.
    - `instructions` (string): Special patient instructions.
  - `takenToday` (boolean): Flag indicating whether today's dose was consumed.
  - `takenLog` (array of maps): Timestamped history of patient-confirmed administrations.
  - `complianceStatus` (string): Overall adherence status (`Adherent`, `Pending`, `Missed`).
  - `createdAt` (timestamp): Creation timestamp.
- **Access Control:** Doctors and Admins create and modify prescriptions. Patients can read their own prescriptions and update *only* compliance tracking fields (`takenToday`, `takenLog`, `updatedAt`). Medical fields are strictly immutable for patients.

### 2.9 Collection: `medical_records`
- **Purpose:** Official electronic health record containing doctor clinical notes, diagnostic evaluations, lab observations, and treatment plans.
- **Document ID:** Unique record identifier (`recordId`).
- **Key Fields:**
  - `recordId` (string): Unique identifier.
  - `patientId` (string): Patient identifier or UID.
  - `doctorUid` (string): Authoring doctor UID.
  - `doctorName` (string): Authoring doctor full name.
  - `diagnosis` (string): Clinical diagnostic finding.
  - `clinicalNotes` (string): Detailed physician evaluation notes.
  - `treatmentPlan` (string): Prescribed therapy and care plan.
  - `medicines` (array of maps): Associated medications and dosages.
  - `attachments` (array of maps): URLs or metadata for attached clinical documents.
  - `createdAt` (string/timestamp): Timestamp of record entry.
  - `blockchainTxHash` (string, optional): Linked transaction proof hash.
  - `blockchainStatus` (string, optional): Verification status (`ANCHORED`, `VERIFIED`).
- **Access Control:** Read access is restricted to the specific patient, authorized doctors, and admins. Write access is restricted to Doctors and Admins.

### 2.10 Collection: `blockchain_proofs`
- **Purpose:** Off-chain mirror of on-chain cryptographic notarizations anchoring medical record integrity.
- **Document ID:** Record identifier (`recordId`) or proof UUID.
- **Key Fields:**
  - `recordId` (string): Primary foreign key referencing `medical_records`.
  - `recordHash` (string): Deterministic 64-character SHA-256 digest of canonical record.
  - `doctorAddress` (string): Ethereum address of the anchoring provider.
  - `doctorUid` (string): Firebase UID of the anchoring provider.
  - `txHash` (string): Blockchain transaction hash (`0x...`).
  - `blockNumber` (integer): EVM block number where transaction was included.
  - `contractAddress` (string): Address of deployed `EHRIntegrityRegistry` contract.
  - `anchoredAt` (timestamp): Block timestamp.
- **Access Control:** Authenticated users can read proof records to verify document authenticity. Write access is restricted to Admins and trusted backend services to prevent proof forgery.
