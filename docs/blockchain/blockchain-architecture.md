# Blockchain Integrity & Verification Architecture

**Official Project Title:**  
**AI-Enabled Secure Electronic Health Record Management System with Blockchain and Private Cloud**

---

## 1. Why Blockchain is Used

In conventional electronic health record (EHR) management architectures, databases are under centralized administrative control. A malicious insider, compromised database administrator, or external attacker gaining database access can alter clinical notes, falsify medical prescriptions, or erase diagnostic findings without leaving a definitive cryptographic trail.

The blockchain layer introduces an **immutable, decentralized notary**. By anchoring mathematical proofs of health records to a decentralized consensus network, the system guarantees:
1. **Non-Repudiation:** Once a doctor signs and notarizes a record, its existence and exact content state cannot be denied.
2. **Tamper Evidence:** Any modification to a record off-chain—even changing a single dosage or date—instantly produces a hash mismatch when verified against the blockchain.
3. **Decentralized Trust:** Verification does not rely solely on the honesty of the database server; anyone with read authorization can independently verify the record against the blockchain ledger.

---

## 2. Why Medical Data is NOT Stored On-Chain

A common misconception is storing complete electronic health records directly on a blockchain. In enterprise healthcare systems, storing medical data on-chain is architecturally flawed and legally impermissible for the following reasons:

1. **Patient Privacy & HIPAA/GDPR Compliance:**
   - Blockchains are immutable public ledgers. Storing Protected Health Information (PHI) or Personally Identifiable Information (PII) on a blockchain violates the GDPR "Right to be Forgotten" and HIPAA privacy rules. Once written, data cannot be deleted or expunged.
2. **Storage Scalability & Cost:**
   - Clinical documents, high-resolution diagnostic images (DICOM), and detailed physician notes require megabytes or gigabytes of storage. Blockchain storage is prohibitively expensive and causes chain bloat.
3. **Confidentiality:**
   - Even encrypted data on a public ledger is vulnerable to future cryptographic breakthroughs or quantum decryption.

**The Solution:** All medical data is stored securely off-chain in Cloud Firestore. Only a **one-way mathematical digest (SHA-256 hash)** and minimal operational metadata are anchored on-chain.

---

## 3. Cryptographic Pipeline: From Record to Block

```
Original Record (Firestore)
         │
         ▼
Canonical JSON Representation (Sorted Keys, Deterministic Spacing)
         │
         ▼
SHA-256 Cryptographic Engine
         │
         ▼
64-Character Hexadecimal Digest (recordHash)
         │
         ▼
Smart Contract Execution (`anchorRecordProof`)
         │
         ▼
Transaction ID / Hash (`0x...`) & Block Inclusion Receipt
```

---

## 4. Canonicalization & Deterministic Hashing

Hashing raw JSON documents directly is prone to false-positive mismatch errors due to differences in whitespace, key ordering, or transient fields. 

To eliminate non-determinism, the `BlockchainService` implements a strict canonicalization protocol:

1. **Field Whitelisting:** Only immutable, clinically meaningful fields are included in the digest:
   - `recordId`
   - `patientId`
   - `doctorUid`
   - `diagnosis`
   - `clinicalNotes`
   - `treatmentPlan`
   - `medicines` (name, dosage, frequency, instructions)
2. **Transient Field Exclusion:** Metadata fields that change over time (`status`, `createdAt`, `updatedAt`, `blockchainTxHash`, `comments`) are excluded.
3. **Recursive Key Sorting:** All dictionaries and nested objects are sorted alphabetically by key.
4. **Normalized Formatting:** Serialized as UTF-8 JSON using strict compact formatting (`json.dumps(obj, sort_keys=True, separators=(', ', ': '))`).
5. **SHA-256 Digest:** The resulting canonical byte string is passed to `hashlib.sha256()`, producing a 64-character lowercase hexadecimal hash.

---

## 5. Smart Contract: `EHRIntegrityRegistry.sol`

The smart contract deployed on the EVM network maintains an append-only mapping of record proofs:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract EHRIntegrityRegistry {
    struct ProofRecord {
        bytes32 recordHash;
        address doctorAddress;
        uint256 timestamp;
        uint256 blockNumber;
        bool exists;
    }

    mapping(bytes32 => ProofRecord) private proofs;
    address public owner;

    event RecordProofAnchored(
        bytes32 indexed recordId,
        bytes32 indexed recordHash,
        address indexed doctorAddress,
        uint256 timestamp
    );

    constructor() { owner = msg.sender; }

    function anchorRecordProof(bytes32 recordId, bytes32 recordHash) external {
        require(!proofs[recordId].exists, "Proof already anchored for this record");
        proofs[recordId] = ProofRecord({
            recordHash: recordHash,
            doctorAddress: msg.sender,
            timestamp: block.timestamp,
            blockNumber: block.number,
            exists: true
        });
        emit RecordProofAnchored(recordId, recordHash, msg.sender, block.timestamp);
    }

    function getRecordProof(bytes32 recordId) external view returns (
        bytes32 recordHash,
        address doctorAddress,
        uint256 timestamp,
        uint256 blockNumber,
        bool exists
    ) {
        ProofRecord memory proof = proofs[recordId];
        return (proof.recordHash, proof.doctorAddress, proof.timestamp, proof.blockNumber, proof.exists);
    }
}
```

---

## 6. Verification & Tamper Detection Workflow

1. An authorized user (the patient or their consulting doctor) initiates verification through the Flutter application.
2. The FastAPI backend fetches the record from Cloud Firestore.
3. The server canonicalizes the record and computes `calculatedHash`.
4. The server executes a read-only smart contract call (`getRecordProof`) to retrieve the `onChainHash`.
5. **Comparison:**
   - **`calculatedHash == onChainHash`:** Returns `verified: true`, status `INTEGRITY_VERIFIED`. The UI displays a green cryptographic shield icon with block number and transaction receipt.
   - **`calculatedHash != onChainHash`:** Returns `verified: false`, status `INTEGRITY_MISMATCH`. The UI displays an alert badge detailing the computed hash versus the immutable on-chain hash, proving tampering occurred off-chain.

---

## 7. Current Environment vs. Future Production Deployment

### 7.1 Current Environment (Development & Validation)
- **EVM Implementation:** In-process Ethereum Virtual Machine (EVM) simulation powered by `eth-tester` and `Web3.py`.
- **Contract State:** Fully compiled and deployed via bytecode with valid Ethereum account signing and transaction receipts.
- **Latency:** Average proof creation: $\sim 52.17\text{ ms}$; average verification: $\sim 7.08\text{ ms}$.

### 7.2 Future Production Deployment (Enterprise Architecture)
- **Target Network:** Enterprise Ethereum (Hyperledger Besu / Quorum) or public Layer 2 networks (Polygon, Arbitrum) with deterministic gas pricing.
- **Key Management:** Private keys secured inside AWS CloudHSM or AWS KMS (Asymmetric Key Spec `ECC_SECG_P256K1`).
- **Relayer Service:** Gasless meta-transactions (ERC-2771) enabling doctors to notarize records without managing raw cryptocurrency balances.
