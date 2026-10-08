"""
==============================================================================
BLOCKCHAIN SERVICE — REAL EVM SMART CONTRACT INTEGRITY & VERIFICATION
==============================================================================
Phase 3: Blockchain Integrity & Verification Layer

CRITICAL ARCHITECTURAL PRINCIPLE:
Actual patient medical records, personal identity data, and clinical notes
MUST ALWAYS REMAIN OFF-CHAIN (stored securely in HIPAA/EHR compliant storage).
Only immutable cryptographic hashes (SHA-256) and transaction timestamps are
anchored on the distributed ledger for tamper-evident mathematical verification.
==============================================================================
"""

from datetime import datetime, timezone
import hashlib
import json
import os
from typing import Any, Dict, List, Optional, Tuple

import firebase_admin
from firebase_admin import firestore
from web3 import Web3
from web3.providers.eth_tester import EthereumTesterProvider

from app.core.config import settings
from app.core.logging_config import logger
from app.models.schemas import (
    AuditEvent,
    AuthenticatedUser,
    BlockchainProof,
    BlockchainStatusResponse,
    BlockchainVerifyResponse,
    UserRole,
)
from app.services.audit_service import audit_service


# Approved canonical fields for EHR record hashing (excludes transient DB metadata)
CANONICAL_EHR_FIELDS = [
    "patientId",
    "doctorId",
    "diagnosis",
    "notes",
    "prescription",
    "medicines",
    "date",
]


def calculate_record_hash(record_data: Dict[str, Any]) -> str:
    """
    Computes a deterministic cryptographic SHA-256 digest of clinical record data.
    Strictly filters approved fields and serializes with sorted keys and normalized separators.
    The exact same logical record will always produce the identical hash.
    Any tampering with diagnosis, medicines, notes, or patientId alters the resulting hash.
    """
    canonical_dict: Dict[str, Any] = {}

    for field in CANONICAL_EHR_FIELDS:
        if field in record_data:
            val = record_data[field]
            # Normalize whitespace for strings
            if isinstance(val, str):
                canonical_dict[field] = val.strip()
            elif isinstance(val, list):
                # Normalize medicines list
                normalized_list = []
                for item in val:
                    if isinstance(item, dict):
                        # Sort and strip keys in nested dictionary
                        normalized_list.append({
                            k.strip(): (v.strip() if isinstance(v, str) else v)
                            for k, v in sorted(item.items())
                        })
                    else:
                        normalized_list.append(item)
                canonical_dict[field] = normalized_list
            else:
                canonical_dict[field] = val

    # Deterministic JSON representation: sorted keys, compact separators, UTF-8
    canonical_json = json.dumps(canonical_dict, sort_keys=True, separators=(",", ":"), default=str)
    return hashlib.sha256(canonical_json.encode("utf-8")).hexdigest()


class BlockchainService:
    """
    Production-ready Blockchain Service connecting to local or private EVM networks.
    Anchors off-chain EHR digests into the EHRIntegrityRegistry smart contract.
    """

    def __init__(self):
        self.network_name: str = settings.BLOCKCHAIN_NETWORK
        self._w3: Optional[Web3] = None
        self._contract: Optional[Any] = None
        self._contract_address: Optional[str] = settings.BLOCKCHAIN_CONTRACT_ADDRESS
        self._deployer_account: Optional[str] = None
        self._contract_abi: Optional[List[Dict[str, Any]]] = None
        self._contract_bytecode: Optional[str] = None
        self._in_memory_proofs: Dict[str, BlockchainProof] = {}
        self._firestore_db: Optional[Any] = None

        self._initialize_blockchain()

    def _get_firestore(self) -> Optional[Any]:
        if self._firestore_db is None and len(firebase_admin._apps) > 0:
            try:
                self._firestore_db = firestore.client()
            except Exception as e:
                logger.warning(f"BlockchainService Firestore connection unavailable: {e}")
        return self._firestore_db

    def _load_contract_artifact(self) -> Tuple[List[Dict[str, Any]], str]:
        """Loads pre-compiled ABI and Bytecode from contracts/EHRIntegrityRegistry.json."""
        artifact_path = os.path.join(
            os.path.dirname(__file__), "..", "..", "contracts", "EHRIntegrityRegistry.json"
        )
        artifact_path = os.path.abspath(artifact_path)

        if not os.path.exists(artifact_path):
            raise FileNotFoundError(f"Smart contract artifact not found at {artifact_path}")

        with open(artifact_path, "r", encoding="utf-8") as f:
            artifact = json.load(f)

        return artifact["abi"], artifact["bytecode"]

    def _initialize_blockchain(self):
        """Initializes Web3 provider, sets up local EVM or RPC node, and deploys registry contract."""
        try:
            if settings.BLOCKCHAIN_RPC_URL:
                logger.info(f"Connecting to Ethereum JSON-RPC node at {settings.BLOCKCHAIN_RPC_URL}")
                self._w3 = Web3(Web3.HTTPProvider(settings.BLOCKCHAIN_RPC_URL))
            else:
                logger.info("Initializing in-process Local Development EVM Blockchain (EthereumTesterProvider)...")
                self._w3 = Web3(EthereumTesterProvider())

            if not self._w3.is_connected():
                logger.error("Failed to connect to Blockchain provider.")
                return

            self._deployer_account = self._w3.eth.accounts[0]
            self._contract_abi, self._contract_bytecode = self._load_contract_artifact()

            # Deploy contract if no existing address is provided
            if not self._contract_address:
                logger.info("Deploying EHRIntegrityRegistry smart contract to local EVM...")
                Contract = self._w3.eth.contract(abi=self._contract_abi, bytecode=self._contract_bytecode)
                tx_hash = Contract.constructor().transact({"from": self._deployer_account})
                receipt = self._w3.eth.wait_for_transaction_receipt(tx_hash)

                self._contract_address = receipt.contractAddress
                logger.info(
                    f"EHRIntegrityRegistry successfully deployed to EVM address: {self._contract_address} "
                    f"(Block #{receipt.blockNumber}, TxHash: {receipt.transactionHash.to_0x_hex()})"
                )

            self._contract = self._w3.eth.contract(address=self._contract_address, abi=self._contract_abi)

        except Exception as e:
            logger.error(f"Failed to initialize Blockchain subsystem: {e}", exc_info=True)
            self._w3 = None
            self._contract = None

    @property
    def phase(self) -> str:
        return "PHASE 3 — ACTIVE"

    def compute_record_hash(self, record_data: Dict[str, Any]) -> str:
        """Deterministic record hashing alias for backwards compatibility."""
        return calculate_record_hash(record_data)

    @property
    def is_connected(self) -> bool:
        return self._w3 is not None and self._w3.is_connected() and self._contract is not None

    def get_status(self) -> BlockchainStatusResponse:
        """Returns the real-time operational status of the Blockchain subsystem."""
        latest_block = 0
        if self._w3 and self._w3.is_connected():
            latest_block = self._w3.eth.block_number

        return BlockchainStatusResponse(
            network=self.network_name,
            contract_address=self._contract_address,
            connected=self.is_connected,
            latest_block=latest_block,
        )

    async def create_integrity_proof(
        self,
        record_id: str,
        record_type: str,
        record_version: int,
        record_data: Dict[str, Any],
        actor: AuthenticatedUser,
    ) -> BlockchainProof:
        """
        Creates and anchors a cryptographic integrity proof to the blockchain.
        1. Calculates deterministic SHA-256 hash.
        2. Submits hash to smart contract on-chain.
        3. Awaits real EVM transaction receipt.
        4. Persists proof metadata off-chain to Firestore / cache.
        5. Logs audit event.
        """
        if not self.is_connected:
            await audit_service.log_event(
                event_type=AuditEvent.BLOCKCHAIN_UNAVAILABLE,
                actor=actor,
                target_id=record_id,
                status="FAILED",
            )
            raise RuntimeError("BLOCKCHAIN_UNAVAILABLE: Blockchain EVM provider is offline or uninitialized.")

        # 1. Deterministic hashing
        record_hash_hex = calculate_record_hash(record_data)
        record_hash_bytes = bytes.fromhex(record_hash_hex)

        logger.info(
            f"Anchoring record_id='{record_id}' (v{record_version}) with SHA-256={record_hash_hex} to blockchain..."
        )

        try:
            # 2. Execute on-chain transaction
            tx_hash = self._contract.functions.storeProof(
                record_id,
                record_hash_bytes,
                record_type,
                record_version,
            ).transact({"from": self._deployer_account})

            # 3. Wait for confirmed transaction receipt
            receipt = self._w3.eth.wait_for_transaction_receipt(tx_hash)
            tx_id_hex = receipt.transactionHash.to_0x_hex()
            block_num = receipt.blockNumber

            if receipt.status != 1:
                raise RuntimeError(f"Blockchain transaction failed with status {receipt.status}")

        except Exception as e:
            logger.error(f"On-chain transaction execution failed: {e}", exc_info=True)
            await audit_service.log_event(
                event_type=AuditEvent.BLOCKCHAIN_TRANSACTION_FAILED,
                actor=actor,
                target_id=record_id,
                status="FAILED",
                metadata={"error": str(e)},
            )
            raise RuntimeError(f"BLOCKCHAIN_TRANSACTION_FAILED: {e}")

        now_iso = datetime.now(timezone.utc).isoformat()
        proof_id = f"proof_{record_id}_v{record_version}"

        proof = BlockchainProof(
            proof_id=proof_id,
            record_id=record_id,
            record_type=record_type,
            record_version=record_version,
            record_hash=record_hash_hex,
            hash_algorithm="SHA-256",
            transaction_id=tx_id_hex,
            block_number=block_num,
            blockchain_network=self.network_name,
            contract_address=self._contract_address or "",
            blockchain_status="CONFIRMED",
            created_at=now_iso,
            created_by_uid=actor.uid,
        )

        # 4. Persist proof metadata off-chain
        self._in_memory_proofs[proof_id] = proof
        self._in_memory_proofs[record_id] = proof

        db = self._get_firestore()
        if db:
            try:
                db.collection("blockchain_proofs").document(proof_id).set({
                    "proofId": proof.proof_id,
                    "recordId": proof.record_id,
                    "recordType": proof.record_type,
                    "recordVersion": proof.record_version,
                    "recordHash": proof.record_hash,
                    "hashAlgorithm": proof.hash_algorithm,
                    "transactionId": proof.transaction_id,
                    "blockNumber": proof.block_number,
                    "blockchainNetwork": proof.blockchain_network,
                    "contractAddress": proof.contract_address,
                    "blockchainStatus": proof.blockchain_status,
                    "createdAt": firestore.SERVER_TIMESTAMP,
                    "createdByUid": proof.created_by_uid,
                })
            except Exception as e:
                logger.error(f"Failed to persist blockchain proof to Firestore: {e}")

        # 5. Log audit trail
        await audit_service.log_event(
            event_type=AuditEvent.BLOCKCHAIN_PROOF_CREATED,
            actor=actor,
            target_id=record_id,
            status="SUCCESS",
            metadata={
                "proof_id": proof_id,
                "transaction_id": tx_id_hex,
                "block_number": block_num,
                "record_hash": record_hash_hex,
            },
        )

        return proof

    async def get_proof(self, record_id: str) -> Optional[BlockchainProof]:
        """Retrieves stored proof metadata from Firestore or cache."""
        if record_id in self._in_memory_proofs:
            return self._in_memory_proofs[record_id]

        db = self._get_firestore()
        if db:
            try:
                docs = (
                    db.collection("blockchain_proofs")
                    .where("recordId", "==", record_id)
                    .order_by("createdAt", direction=firestore.Query.DESCENDING)
                    .limit(1)
                    .stream()
                )
                for doc in docs:
                    d = doc.to_dict()
                    proof = BlockchainProof(
                        proof_id=d.get("proofId", doc.id),
                        record_id=d.get("recordId", record_id),
                        record_type=d.get("recordType", "medical_record"),
                        record_version=d.get("recordVersion", 1),
                        record_hash=d.get("recordHash", ""),
                        hash_algorithm=d.get("hashAlgorithm", "SHA-256"),
                        transaction_id=d.get("transactionId", ""),
                        block_number=d.get("blockNumber", 0),
                        blockchain_network=d.get("blockchainNetwork", self.network_name),
                        contract_address=d.get("contractAddress", self._contract_address or ""),
                        blockchain_status=d.get("blockchainStatus", "CONFIRMED"),
                        created_at=str(d.get("createdAt", "")),
                        created_by_uid=d.get("createdByUid", ""),
                    )
                    self._in_memory_proofs[record_id] = proof
                    return proof
            except Exception as e:
                logger.error(f"Error querying blockchain_proofs in Firestore: {e}")

        return None

    async def verify_integrity_proof(
        self,
        record_id: str,
        record_data: Dict[str, Any],
        actor: AuthenticatedUser,
        record_version: int = 1,
    ) -> BlockchainVerifyResponse:
        """
        Cryptographically verifies the authenticity and tamper-freedom of an EHR record.
        1. Recalculates current canonical SHA-256 hash from off-chain record data.
        2. Queries on-chain smart contract for the immutable stored hash.
        3. Cross-references off-chain metadata.
        4. Detects any bitwise deviation or clinical record tampering.
        5. Logs audit event.
        """
        now_iso = datetime.now(timezone.utc).isoformat()

        if not self.is_connected:
            await audit_service.log_event(
                event_type=AuditEvent.BLOCKCHAIN_UNAVAILABLE,
                actor=actor,
                target_id=record_id,
                status="FAILED",
            )
            return BlockchainVerifyResponse(
                verified=False,
                status="BLOCKCHAIN_UNAVAILABLE",
                record_id=record_id,
                timestamp=now_iso,
                details="Blockchain provider is currently unreachable.",
            )

        # 1. Compute current canonical hash
        current_hash_hex = calculate_record_hash(record_data)

        # 2. Retrieve proof metadata
        stored_proof = await self.get_proof(record_id)

        # 3. Query on-chain smart contract directly
        try:
            on_chain_data = self._contract.functions.getProof(record_id).call()
            # on_chain_data: (bytes32 recordHash, string recordType, uint256 recordVersion, uint256 timestamp, address registeredBy)
            on_chain_bytes = on_chain_data[0]
            on_chain_hash_hex = on_chain_bytes.hex()
        except Exception as e:
            logger.warning(f"On-chain proof query for record_id='{record_id}' returned: {e}")
            await audit_service.log_event(
                event_type=AuditEvent.BLOCKCHAIN_VERIFICATION_FAILED,
                actor=actor,
                target_id=record_id,
                status="PROOF_NOT_FOUND",
            )
            return BlockchainVerifyResponse(
                verified=False,
                status="PROOF_NOT_FOUND",
                record_id=record_id,
                current_hash=current_hash_hex,
                timestamp=now_iso,
                details="No blockchain integrity proof found for this record on the ledger.",
            )

        # 4. Compare current off-chain hash with on-chain immutable hash
        hashes_match = current_hash_hex.lower() == on_chain_hash_hex.lower()

        if hashes_match:
            status_str = "INTEGRITY_VERIFIED"
            details_str = "Cryptographic match confirmed. Record has not been altered since blockchain registration."
            await audit_service.log_event(
                event_type=AuditEvent.BLOCKCHAIN_VERIFICATION_SUCCESS,
                actor=actor,
                target_id=record_id,
                status="SUCCESS",
                metadata={"record_hash": current_hash_hex},
            )
        else:
            status_str = "INTEGRITY_MISMATCH"
            details_str = (
                "CRITICAL WARNING: Tampering detected! Current record data does not match the immutable hash "
                "registered on the blockchain."
            )
            logger.warning(
                f"TAMPERING DETECTED for record '{record_id}'! "
                f"Current off-chain hash: {current_hash_hex} != On-chain hash: {on_chain_hash_hex}"
            )
            await audit_service.log_event(
                event_type=AuditEvent.BLOCKCHAIN_VERIFICATION_FAILED,
                actor=actor,
                target_id=record_id,
                status="INTEGRITY_MISMATCH",
                metadata={
                    "current_hash": current_hash_hex,
                    "on_chain_hash": on_chain_hash_hex,
                },
            )

        return BlockchainVerifyResponse(
            verified=hashes_match,
            status=status_str,
            record_id=record_id,
            current_hash=current_hash_hex,
            on_chain_hash=on_chain_hash_hex,
            transaction_id=stored_proof.transaction_id if stored_proof else None,
            block_number=stored_proof.block_number if stored_proof else None,
            blockchain_network=self.network_name,
            timestamp=now_iso,
            details=details_str,
        )


blockchain_service = BlockchainService()
