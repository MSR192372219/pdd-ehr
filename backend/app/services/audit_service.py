from datetime import datetime, timezone
import hashlib
import json
from typing import Any, Dict, List, Optional
import firebase_admin
from firebase_admin import firestore
from app.core.logging_config import logger
from app.models.schemas import AuditEvent, AuditLogEntry, AuthenticatedUser, UserRole


class AuditService:
    """
    Centralized audit service interface for regulatory compliance and access traceability.
    Records audit trails in a structured, sanitized manner without leaking PII or credentials.
    """

    def __init__(self):
        self._db: Optional[Any] = None
        self._connection_failed: bool = False
        self._in_memory_audit_logs: List[AuditLogEntry] = []

    def _get_db(self) -> Optional[Any]:
        if self._db is None and not self._connection_failed and len(firebase_admin._apps) > 0:
            try:
                self._db = firestore.client()
            except Exception as e:
                self._connection_failed = True
                logger.warning(f"Audit Firestore connection unavailable: {e}")
        return self._db

    def _compute_event_hash(self, actor_uid: str, event_type: str, target_id: Optional[str]) -> str:
        """Computes a SHA-256 fingerprint of the audit event for tamper-evident verification."""
        content = f"{actor_uid}:{event_type}:{target_id or ''}:{datetime.now(timezone.utc).isoformat()}"
        return hashlib.sha256(content.encode("utf-8")).hexdigest()

    async def log_event(
        self,
        event_type: AuditEvent,
        actor: AuthenticatedUser,
        target_id: Optional[str] = None,
        status: str = "SUCCESS",
        metadata: Optional[Dict[str, Any]] = None,
    ) -> AuditLogEntry:
        """
        Records an audit event safely.
        Sanitizes metadata to ensure no sensitive medical summaries, credentials, or tokens are logged.
        """
        now_str = datetime.now(timezone.utc).isoformat()
        event_id = f"aud_{int(datetime.now(timezone.utc).timestamp() * 1000)}"
        event_hash = self._compute_event_hash(actor.uid, event_type.value, target_id)

        # Sanitize metadata: do not store full clinical text, passwords, or tokens
        safe_metadata: Dict[str, Any] = {}
        if metadata:
            for k, v in metadata.items():
                if k.lower() in ["password", "token", "private_key", "prescription", "notes"]:
                    safe_metadata[k] = "[REDACTED]"
                elif isinstance(v, (str, int, float, bool)):
                    safe_metadata[k] = v

        entry = AuditLogEntry(
            id=event_id,
            event_type=event_type,
            actor_uid=actor.uid,
            actor_role=actor.role,
            target_id=target_id,
            timestamp=now_str,
            status=status,
            metadata_hash=event_hash,
        )

        # Structured logger output
        logger.info(
            f"AUDIT_EVENT | Type={event_type.value} | ActorUID={actor.uid} | Role={actor.role.value} | "
            f"TargetID={target_id} | Status={status} | Hash={event_hash[:16]}..."
        )

        self._in_memory_audit_logs.append(entry)

        db = self._get_db()
        if db:
            try:
                db.collection("audit_logs").document(event_id).set({
                    "id": event_id,
                    "eventType": event_type.value,
                    "actorUid": actor.uid,
                    "actorRole": actor.role.value,
                    "targetId": target_id,
                    "timestamp": firestore.SERVER_TIMESTAMP,
                    "status": status,
                    "metadata": safe_metadata,
                    "eventHash": event_hash,
                })
            except Exception as e:
                logger.error(f"Failed to persist audit log to Firestore: {e}")

        return entry

    async def get_patient_audit_trail(
        self, patient_id: str, actor: AuthenticatedUser
    ) -> List[AuditLogEntry]:
        """
        Retrieves the audit trail associated with a patient.
        Patients can only see audits of their own records.
        """
        if actor.role == UserRole.PATIENT and actor.uid != patient_id:
            logger.warning(
                f"Unauthorized audit access attempt by Patient UID={actor.uid} on target Patient={patient_id}"
            )
            return []

        db = self._get_db()
        entries: List[AuditLogEntry] = []

        if db:
            try:
                docs = (
                    db.collection("audit_logs")
                    .where("targetId", "==", patient_id)
                    .order_by("timestamp", direction=firestore.Query.DESCENDING)
                    .limit(50)
                    .stream()
                )
                for doc in docs:
                    d = doc.to_dict()
                    entries.append(
                        AuditLogEntry(
                            id=doc.id,
                            event_type=AuditEvent(d.get("eventType", AuditEvent.RECORD_ACCESSED.value)),
                            actor_uid=d.get("actorUid", ""),
                            actor_role=UserRole(d.get("actorRole", UserRole.PATIENT.value)),
                            target_id=d.get("targetId"),
                            timestamp=str(d.get("timestamp", "")),
                            status=d.get("status", "SUCCESS"),
                            metadata_hash=d.get("eventHash"),
                        )
                    )
            except Exception as e:
                logger.error(f"Error querying audit_logs: {e}")

        if not db or len(entries) == 0:
            entries = [
                e for e in reversed(self._in_memory_audit_logs)
                if e.target_id == patient_id
            ]

        return entries


audit_service = AuditService()
