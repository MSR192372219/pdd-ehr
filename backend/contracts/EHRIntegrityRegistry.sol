// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EHRIntegrityRegistry
 * @dev Cryptographic integrity verification registry for Electronic Health Records.
 *
 * CRITICAL ARCHITECTURAL PRINCIPLE:
 * Actual patient medical records, personal identity data, and clinical notes
 * MUST ALWAYS REMAIN OFF-CHAIN (stored securely in HIPAA/EHR compliant storage).
 * Only immutable cryptographic hashes (SHA-256) and transaction timestamps are
 * anchored on the distributed ledger for tamper-evident mathematical verification.
 */
contract EHRIntegrityRegistry {
    struct Proof {
        bytes32 recordHash;
        string recordType;
        uint256 recordVersion;
        uint256 timestamp;
        address registeredBy;
    }

    // Mapping from recordId => Proof
    mapping(string => Proof) private proofs;

    event ProofStored(
        string indexed recordId,
        bytes32 indexed recordHash,
        string recordType,
        uint256 recordVersion,
        uint256 timestamp,
        address registeredBy
    );

    /**
     * @notice Stores a cryptographic SHA-256 hash of an off-chain EHR record.
     * @param recordId Unique identifier of the off-chain record.
     * @param recordHash 32-byte SHA-256 digest of the canonical record representation.
     * @param recordType Type of record (e.g. 'medical_record', 'prescription').
     * @param recordVersion Incremental version of the record.
     */
    function storeProof(
        string calldata recordId,
        bytes32 recordHash,
        string calldata recordType,
        uint256 recordVersion
    ) external returns (bool) {
        require(recordHash != bytes32(0), "Invalid record hash");
        require(bytes(recordId).length > 0, "Invalid record ID");

        proofs[recordId] = Proof({
            recordHash: recordHash,
            recordType: recordType,
            recordVersion: recordVersion,
            timestamp: block.timestamp,
            registeredBy: msg.sender
        });

        emit ProofStored(
            recordId,
            recordHash,
            recordType,
            recordVersion,
            block.timestamp,
            msg.sender
        );

        return true;
    }

    /**
     * @notice Retrieves the stored integrity proof for an off-chain record.
     * @param recordId Unique identifier of the off-chain record.
     */
    function getProof(string calldata recordId)
        external
        view
        returns (
            bytes32 recordHash,
            string memory recordType,
            uint256 recordVersion,
            uint256 timestamp,
            address registeredBy
        )
    {
        Proof memory p = proofs[recordId];
        require(p.recordHash != bytes32(0), "Proof not found");
        return (
            p.recordHash,
            p.recordType,
            p.recordVersion,
            p.timestamp,
            p.registeredBy
        );
    }
}
