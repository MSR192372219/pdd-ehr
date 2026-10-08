# Clinical AI Intelligence Architecture

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## 1. Foundational Medical Disclaimer & Scope

> **AI IS AN ASSISTIVE SYSTEM AND DOES NOT REPLACE QUALIFIED HEALTHCARE PROFESSIONALS.**
> 
> The AI capabilities implemented within this system are strictly designed for **health literacy enhancement, medical record summarization, and educational assistance**. 
> The system **does not provide definitive medical diagnoses, does not prescribe treatments, and strictly refuses user attempts to alter medication regimens or dosage schedules**.

---

## 2. Implemented AI Capabilities

### 2.1 EHR Record Summarization (`POST /api/v1/ai/summarize`)
- **Target Audience:** Patients reviewing complex discharge summaries and clinical consultation notes.
- **Functionality:** Ingests complex doctor clinical notes, diagnostic terminology, and prescribed treatment plans, translating them into clear, structured, 6th-grade reading level summaries.
- **Output Structure:**
  - Key Findings / Diagnosis Overview
  - Prescribed Care Instructions
  - Questions to Ask During Follow-up Consultations
  - Mandatory Educational Disclaimer

### 2.2 Prescription Explanation (`POST /api/v1/ai/prescription-explanation`)
- **Target Audience:** Patients needing clarification on medication purpose and administration rules.
- **Functionality:** Extracts medication name, dosage, frequency, and instructions, providing:
  - Pharmacological class and therapeutic purpose (e.g., "Metformin is an oral biguanide used to help manage blood sugar levels").
  - Administration best practices (e.g., take with food to minimize gastrointestinal discomfort).
  - Common side effects and red-flag symptoms requiring emergency medical attention.
  - Missed-dose guidance (emphasizing never taking a double dose without physician approval).

### 2.3 Patient Health Assistant (`POST /api/v1/ai/assistant`)
- **Target Audience:** Authenticated patients via the dedicated Flutter Health Assistant interface.
- **Functionality:** Context-grounded health assistant answering general medical queries, lifestyle suggestions, appointment preparation guidelines, and preventative health questions.
- **Grounding:** Ingests authorized health record context to answer personalized questions without inventing synthetic medical history.

---

## 3. Clinical Safety & Defensive Guardrails

The AI subsystem implements a multi-tier defense system to prevent hallucinations, unsafe medical advice, and prompt injection attacks:

### 3.1 Pre-Execution Data Minimization
- The `DataMinimizer` component sanitizes incoming clinical records prior to prompt formation.
- Strips direct identifiers: full names, contact phone numbers, physical residential addresses, social security/national IDs, and financial information.
- Passes only the minimum clinical tokens strictly required to fulfill the user's specific request.

### 3.2 Programmatic Refusal Guardrails
Before context reaches the language model or knowledge retrieval engine, the input query is analyzed for prohibited medical operations:
1. **Refusal to Diagnose:**
   - Any query demanding a medical diagnosis (e.g., *"Diagnose me,"* *"Do I have cancer?"*) is immediately intercepted.
   - Response: Explicit refusal stating that diagnosis requires in-person medical evaluation, lab tests, and a licensed physician, followed by general guidelines on discussing symptoms with their doctor.
2. **Refusal to Alter Dosages:**
   - Any query requesting dose modifications (e.g., *"Can I double my dose?"*, *"Should I stop taking this medication?"*) is intercepted.
   - Response: Explicit warning against altering prescription dosages without direct guidance from the prescribing physician.

### 3.3 Prompt Injection Containment
- System prompts, retrieved clinical documents, and user questions are isolated into discrete JSON fields with immutable system instructions.
- User input is prevented from overriding system safety rules through delimited boundaries.

### 3.4 Post-Inference Response Validation
- Every AI response passes through `validate_ai_response()`.
- Verifies that no prohibited diagnostic affirmations or reckless dosage instructions were generated.
- Programmatically appends the standardized legal and clinical disclaimer to every payload.

---

## 4. Rate Limiting & Resource Protection

- **Sliding-Window Rate Limiter:** Capped at **20 requests per minute per authenticated Firebase UID**.
- Rapid bursts exceeding the threshold are immediately rejected with `HTTP 429 Too Many Requests`, protecting both backend computing resources and downstream AI provider quotas.

---

## 5. Security, Secrets & Audit Logging

- **API Key Protection:** The Google Gemini API key (`GEMINI_API_KEY`) is stored strictly in server-side environment variables or AWS Secrets Manager. It is never shipped in Flutter app code or visible in client network traffic.
- **Status Endpoint Scrubbing:** The `/api/v1/ai/status` endpoint reports boolean health and provider availability; it reveals zero secret keys or credential strings.
- **Sanitized Audit Events:** Every AI interaction is logged via `AuditService` recording the requesting UID, timestamp, and token counts. Prompt text and patient clinical contents are redacted from system logs to protect confidentiality.
