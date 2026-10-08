# Performance & Benchmarking Test Report

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## 1. Executive Summary

Performance benchmarking was conducted across all core operations using controlled test iterations executed against the local FastAPI Private Cloud backend and in-process EVM development blockchain.

---

## 2. Benchmark Measurements

| Component / Endpoint | Operations Measured | Avg Latency | Median Latency | p95 Latency | Error Rate |
|---|---|---|---|---|---|
| **FastAPI Health** (`GET /health`) | 50 requests | **0.99 ms** | **0.88 ms** | **1.70 ms** | 0.0% |
| **EHR API** (`GET /api/v1/ehr/records/{id}`) | 30 requests | **1.52 ms** | **1.32 ms** | **3.55 ms** | 0.0% |
| **AI Assistant** (`POST /api/v1/ai/assistant`) | 15 requests | **2.23 ms** | **1.96 ms** | **7.49 ms** | 0.0% |
| **Blockchain Proof Creation** (`POST /api/v1/blockchain/proof`) | 10 transactions | **52.17 ms** | **51.47 ms** | **54.33 ms** | 0.0% |
| **Blockchain Verification** (`POST /api/v1/blockchain/verify`) | 20 queries | **7.08 ms** | **7.03 ms** | **8.03 ms** | 0.0% |

---

## 3. Analysis & Observations

1. **Sub-Millisecond Health & Gateway Throughput:**
   - The FastAPI gateway processes public health endpoints in under 1 ms, confirming minimal middleware overhead.
2. **Authenticated EHR Latency:**
   - Enforcing Bearer token authentication and record isolation incurs negligible latency ($\sim 1.5\text{ ms}$ in-memory/cached).
3. **AI Clinical Intelligence Performance:**
   - Offline clinical knowledge base lookup and safety validation execute in $\sim 2.2\text{ ms}$.
   - External LLM provider calls will vary depending on network conditions and provider throughput ($\sim 500\text{--}1500\text{ ms}$ typical for cloud LLMs).
4. **EVM Transaction Mining Overhead:**
   - Blockchain proof creation incurs a modest $\sim 52\text{ ms}$ latency due to Web3 transaction signing and block mining.
   - Verification operations are fast read-only contract calls (`eth_call`), completing in $\sim 7\text{ ms}$.
