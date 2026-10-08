# Private Cloud Backend Architecture

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## 1. Deployment Status Declaration

> ### **CURRENT STATUS: LOCAL TESTED & DEPLOYMENT READY**
> 
> The private cloud infrastructure described herein is fully specified, containerized with Docker, validated against local integration and penetration test suites, and **deployment ready**. 
> The backend has been validated locally and in-process. 
> **It is NOT currently deployed to a live AWS production cluster.**

---

## 2. Containerized Application Stack

The backend service is containerized using Docker to ensure reproducible, isolated execution across development, staging, and private cloud environments.

### 2.1 Backend Container Architecture
- **Runtime Base:** `python:3.13-slim` (minimal attack surface, non-essential binaries omitted).
- **Web Framework:** FastAPI (asynchronous ASGI server powered by Uvicorn).
- **Execution User:** Non-root system user (`ehruser`, UID 10001) preventing privilege escalation vulnerabilities.
- **Port:** Port 8000 exposed internally.
- **Healthcheck:** Automated container health checks pinging `GET /health` with 30-second intervals.

---

## 3. Production AWS Private Cloud Architecture (Target Topology)

When deployed to production, the backend operates inside an isolated Amazon Virtual Private Cloud (VPC) spanning multiple Availability Zones:

```
+---------------------------------------------------------------------------------+
|                                 AWS REGION                                      |
|                                                                                 |
|  +---------------------------------------------------------------------------+  |
|  |                            VPC (10.0.0.0/16)                              |  |
|  |                                                                           |  |
|  |  [Public Subnets: 10.0.1.0/24, 10.0.2.0/24]                              |  |
|  |    - Internet Gateway (IGW)                                               |  |
|  |    - Application Load Balancer (ALB) with AWS ACM TLS 1.3 Certificate     |  |
|  |    - NAT Gateway (Outbound Internet for Firebase Token Verification)      |  |
|  |                                                                           |  |
|  |  [Private Subnets: 10.0.10.0/24, 10.0.20.0/24] (No Inbound Public Route) |  |
|  |    - ECS Fargate Tasks (FastAPI Backend Docker Container)                 |  |
|  |    - Inbound Security Group: Port 8000 ONLY from ALB Security Group       |  |
|  |    - Outbound Route to NAT Gateway                                        |  |
|  |                                                                           |  |
|  |  [AWS Managed Services]                                                   |  |
|  |    - AWS Secrets Manager (Credentials: Firebase SA, Gemini API Key)       |  |
|  |    - AWS CloudWatch (Encrypted Log Groups & Operational Alarms)           |  |
|  |    - AWS KMS (Customer Managed Key for At-Rest Storage Encryption)        |  |
|  +---------------------------------------------------------------------------+  |
+---------------------------------------------------------------------------------+
```

---

## 4. Key Infrastructure Components

### 4.1 Network Segmentation & Subnets
- **Public Subnets (`10.0.1.0/24`, `10.0.2.0/24`):**
  - Host only the Application Load Balancer and NAT Gateway.
  - No application backend containers run in public subnets.
- **Private Subnets (`10.0.10.0/24`, `10.0.20.0/24`):**
  - Zero direct ingress from the public internet.
  - Host the containerized ECS Fargate tasks running the FastAPI backend.
  - Egress to the public internet is routed strictly through the NAT Gateway for verifying external Google OAuth2 tokens.

### 4.2 Security Groups & Defense-in-Depth
1. **ALB Security Group (`sg-alb`):**
   - Inbound: Port 443 (HTTPS) from client IP ranges.
   - Outbound: Port 8000 strictly routed to `sg-backend-ecs`.
2. **ECS Fargate Security Group (`sg-backend-ecs`):**
   - Inbound: Port 8000 strictly allowed from `sg-alb` (direct internet traffic rejected).
   - Outbound: Port 443 via NAT Gateway for external token validation and AI APIs.

### 4.3 Elastic Compute: AWS ECS Fargate
- Serverless container orchestration eliminating OS management and host-level vulnerabilities.
- Automatic horizontal scaling based on CPU utilization and request latency metrics.

### 4.4 Secrets Management & Key Protection
- **AWS Secrets Manager:**
  - Securely provisions `FIREBASE_SERVICE_ACCOUNT_KEY`, `GEMINI_API_KEY`, and `BLOCKCHAIN_PRIVATE_KEY`.
  - Injected directly into the container's execution memory via ECS Task Definitions.
  - Zero secrets reside in source code, Docker image layers, or persistent disk volumes.

### 4.5 Logging, Auditing & Observability
- **AWS CloudWatch Logs:**
  - Centralized streaming of container stdout/stderr.
  - Logs encrypted at rest using AWS KMS Customer Managed Keys (CMK).
  - PII scrubbing in the FastAPI `AuditService` ensures patient health data and tokens are never written to log streams.
