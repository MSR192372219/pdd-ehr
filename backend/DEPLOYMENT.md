# Private Cloud Deployment Guide: AWS Infrastructure Specification

## Project: AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud
### Target Environment: Private Cloud (AWS VPC / ECS Fargate)

---

### 1. Architecture Overview

In production, the FastAPI Private Cloud Backend runs within an isolated **Amazon Virtual Private Cloud (VPC)**. It is never directly exposed to the public internet on unencrypted ports.

```
+---------------------------------------------------------------------------------+
|                                 AWS REGION                                      |
|                                                                                 |
|  +---------------------------------------------------------------------------+  |
|  |                            VPC (10.0.0.0/16)                              |  |
|  |                                                                           |  |
|  |  [Public Subnets: 10.0.1.0/24, 10.0.2.0/24]                              |  |
|  |    - Internet Gateway (IGW)                                               |  |
|  |    - Application Load Balancer (ALB) with AWS ACM TLS Certificate         |  |
|  |    - NAT Gateway (Outbound Internet for Firebase Auth Token Keys)        |  |
|  |                                                                           |  |
|  |  [Private Subnets: 10.0.10.0/24, 10.0.20.0/24] (No Inbound Public Route) |  |
|  |    - ECS Fargate Tasks (Running FastAPI Backend Container)               |  |
|  |    - Security Group: Inbound Port 8000 ONLY from ALB Security Group       |  |
|  |    - Outbound Route to NAT Gateway                                        |  |
|  |                                                                           |  |
|  |  [AWS Managed Services]                                                   |  |
|  |    - AWS Secrets Manager (Stores Firebase Service Account Credentials)    |  |
|  |    - AWS CloudWatch (Encrypted Log Groups & Alarm Metrics)                |  |
|  |    - AWS KMS (Customer Managed Key for at-rest encryption)               |  |
|  +---------------------------------------------------------------------------+  |
+---------------------------------------------------------------------------------+
```

---

### 2. Network & Security Topology

#### Virtual Private Cloud (VPC)
- **CIDR**: `10.0.0.0/16`
- **Subnets**:
  - `Public-Subnet-A` (`10.0.1.0/24`) in `us-east-1a`
  - `Public-Subnet-B` (`10.0.2.0/24`) in `us-east-1b`
  - `Private-Subnet-A` (`10.0.10.0/24`) in `us-east-1a`
  - `Private-Subnet-B` (`10.0.20.0/24`) in `us-east-1b`

#### Security Groups
1. **ALB Security Group (`sg-alb`)**:
   - Inbound: Port `443` (HTTPS) from Allowed CIDRs or Internet.
   - Outbound: Port `8000` to `sg-backend-ecs`.
2. **Backend ECS Security Group (`sg-backend-ecs`)**:
   - Inbound: Port `8000` strictly from `sg-alb` (No direct internet traffic).
   - Outbound: Port `443` via NAT Gateway for Google OAuth2 / Firebase token key rotation.

---

### 3. Secrets Management (AWS Secrets Manager)

Credentials are never placed in source code, Docker images, or unencrypted environment variables.

1. **Secret Name**: `ehr-system/private-cloud/credentials`
2. **Key-Value Pairs**:
   - `FIREBASE_PROJECT_ID`: `ehrsystem-32674f7e`
   - `FIREBASE_CLIENT_EMAIL`: Service account client email
   - `FIREBASE_PRIVATE_KEY`: Service account private key
   - `ENVIRONMENT`: `production`
   - `ALLOWED_ORIGINS`: Production client domains (e.g., `https://ehr.healthcare.com`)

In ECS task definitions, secrets are injected directly into container environment variables using the `secrets` attribute referencing the Secrets Manager ARN.

---

### 4. Containerization (Dockerfile)

```dockerfile
FROM python:3.13-slim

WORKDIR /app

# Prevent Python from writing .pyc files & buffering stdout
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY app/ ./app/

# Create non-root system user for security
RUN useradd -m -u 10001 ehruser
USER ehruser

EXPOSE 8000

# Run with production Uvicorn settings
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

---

### 5. Health Checks, Observability & Auditing

- **Health Endpoint**: `GET /health` polled every 30 seconds by the Application Load Balancer target group.
- **Logging**: All stdout logs are captured by the AWS CloudWatch `awslogs` log driver.
- **Log Sanitization**: The application's `SanitizingFilter` automatically redacts bearer tokens, passwords, and private keys prior to writing to the stream.
- **Monitoring**: CloudWatch Alarms on 5XX HTTP error rates and task CPU/Memory thresholds (> 80%).

---

### 6. Disaster Recovery & Backups

- Multi-AZ task distribution across two Availability Zones (`us-east-1a` and `us-east-1b`).
- Cloud Firestore native point-in-time recovery (PITR) enabled on project `ehrsystem-32674f7e`.
- Infrastructure defined via Terraform / AWS CDK for automated disaster reconstruction.

---

### 7. Phase 3: Blockchain Subsystem in Private Cloud

In production private cloud environments, the blockchain subsystem connects to an internal private EVM network (e.g., private Ethereum PoA, Hyperledger Besu, or AWS Managed Blockchain):

1. **RPC Connection**: Set `BLOCKCHAIN_RPC_URL` (e.g., `http://besu-node.internal.vpc:8545`) within the VPC security group boundary.
2. **Contract Deployment**: The `EHRIntegrityRegistry` contract address is pinned using `BLOCKCHAIN_CONTRACT_ADDRESS`.
3. **Off-Chain Isolation**: Clinical data is strictly offloaded to Cloud Firestore. Only 32-byte cryptographic hashes and audit receipts transit to the EVM node.
4. **Signer Key Protection**: In production, the backend signer account is backed by an AWS KMS asymmetric key or Hardware Security Module (HSM), eliminating cleartext private key exposure.

---

### 8. Phase 4: AI Clinical Assistance Subsystem in Private Cloud

The Phase 4 AI architecture provides grounded clinical assistance with strict data governance:

1. **AI Provider Topology**:
   - **Internal Deterministic Engine**: Enabled by default (`AI_PROVIDER=clinical_engine`), requiring zero external network calls or cloud egress.
   - **External LLM Gateway**: Supported via HTTPS egress via VPC NAT Gateway to authorized LLM endpoints (`openai`, `gemini`, or custom private VPC hosted LLM endpoints).
2. **Secrets & Credentials Protection**:
   - `AI_API_KEY` is provisioned exclusively through AWS Secrets Manager (`ehr-system/private-cloud/credentials`).
   - The key is injected into the container environment at task execution and NEVER exposed in Flutter, git, Firestore, or logs.
3. **Data Minimization & HIPAA Safeguards**:
   - Only minimized clinical fields (prescribed medicine names, dosages, high-level diagnoses) are transmitted to the AI engine.
   - Patient names, emails, phone numbers, addresses, auth tokens, and full EHR trees are stripped prior to prompt compilation.
   - Prompt sanitization filters redact all access tokens and PII before any external dispatch.
4. **Rate Limiting & Abuse Prevention**:
   - Sliding-window rate limiter limits requests to `AI_RATE_LIMIT_PER_MINUTE=20` per authenticated caller UID.
   - Exceeding the threshold yields `HTTP 429 Too Many Requests` and logs an `AI_RATE_LIMIT_EXCEEDED` audit entry.
5. **Medical Advisory Compliance**:
   - All responses include the mandatory disclaimer:
     *"This summary is AI-generated and is not a medical diagnosis. Please consult your doctor or healthcare provider."*
   - Application-level validators reject outputs that claim definitive diagnosis or propose altering prescribed dosages.

