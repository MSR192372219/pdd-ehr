from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from fastapi import HTTPException, status
import firebase_admin
from firebase_admin import firestore
from app.core.logging_config import logger
from app.models.schemas import AuthenticatedUser, EHRRecordCreate, EHRRecordResponse, UserRole


class EHRService:
    """
    Architectural service for electronic health records.
    Provides server-authoritative data access with strict patient privacy and clinical auditing.
    Directly interfaces with Cloud Firestore using Firebase Admin SDK.
    """

    def __init__(self):
        self._db: Optional[Any] = None
        self._connection_failed: bool = False
        self._in_memory_records: Dict[str, Dict[str, Any]] = {}

    def _get_db(self) -> Optional[Any]:
        if self._db is None and not self._connection_failed and len(firebase_admin._apps) > 0:
            try:
                self._db = firestore.client()
            except Exception as e:
                self._connection_failed = True
                logger.warning(f"Firestore client connection failed: {e}")
        return self._db

    async def get_patient_records(
        self, patient_id: str, actor: AuthenticatedUser
    ) -> List[EHRRecordResponse]:
        """
        Retrieves medical records for a specific patient.
        Strict authorization enforcement:
        - Patients can only access their OWN records (actor.uid == patient_id).
        - Doctors and Admins can access authorized clinical patient records.
        """
        if not patient_id or not patient_id.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Patient identifier is required."
            )

        # Patient isolation rule
        if actor.role == UserRole.PATIENT and actor.uid != patient_id:
            logger.warning(
                f"Unauthorized EHR access attempt: Patient actor={actor.uid} requested patient={patient_id}"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Patients may only access their own medical records."
            )

        db = self._get_db()
        records: List[EHRRecordResponse] = []

        if db:
            try:
                docs = (
                    db.collection("medical_records")
                    .where("patientId", "==", patient_id)
                    .stream()
                )
                for doc in docs:
                    data = doc.to_dict()
                    records.append(
                        EHRRecordResponse(
                            id=doc.id,
                            patient_id=data.get("patientId", patient_id),
                            doctor_id=data.get("doctorId", data.get("doctorUid", "")),
                            doctor_name=data.get("doctorName"),
                            diagnosis=data.get("diagnosis", ""),
                            notes=data.get("notes"),
                            prescription=data.get("prescription"),
                            medicines=data.get("medicines"),
                            created_at=str(data.get("createdAt", data.get("date", ""))),
                        )
                    )
            except Exception as e:
                logger.error(f"Error querying Firestore medical_records: {e}")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Database query error while retrieving EHR records."
                )

        if not records and self._in_memory_records:
            for rid, rdata in self._in_memory_records.items():
                if rdata.get("patientId") == patient_id:
                    records.append(
                        EHRRecordResponse(
                            id=rid,
                            patient_id=rdata.get("patientId", patient_id),
                            doctor_id=rdata.get("doctorId", ""),
                            doctor_name=rdata.get("doctorName", "Attending Physician"),
                            diagnosis=rdata.get("diagnosis", ""),
                            notes=rdata.get("notes"),
                            prescription=rdata.get("prescription"),
                            medicines=rdata.get("medicines"),
                            created_at=str(rdata.get("createdAt", rdata.get("date", ""))),
                        )
                    )

        logger.info(
            f"EHR records retrieved for patient={patient_id} by actor={actor.uid} (Role={actor.role.value}). Count={len(records)}"
        )
        return records

    async def create_patient_record(
        self, record_in: EHRRecordCreate, actor: AuthenticatedUser
    ) -> EHRRecordResponse:
        """
        Creates a new medical record for a patient.
        Strict authorization enforcement:
        - Only Doctors and Admins may create clinical medical records.
        - Patients are strictly forbidden from authoring medical records.
        """
        if actor.role not in [UserRole.DOCTOR, UserRole.ADMIN]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Only licensed healthcare providers or administrators can author medical records."
            )

        db = self._get_db()
        record_id = f"ehr_{int(datetime.now(timezone.utc).timestamp() * 1000)}"
        now_iso = datetime.now(timezone.utc).isoformat()

        if db:
            try:
                doc_ref = db.collection("medical_records").document()
                record_id = doc_ref.id
                doc_data = {
                    "patientId": record_in.patient_id,
                    "doctorId": actor.uid,
                    "doctorName": actor.claims.get("name", "Attending Physician"),
                    "diagnosis": record_in.diagnosis,
                    "notes": record_in.notes,
                    "prescription": record_in.prescription,
                    "medicines": record_in.medicines,
                    "date": datetime.now(timezone.utc).strftime("%d-%m-%Y"),
                    "createdAt": firestore.SERVER_TIMESTAMP,
                }
                doc_ref.set(doc_data)
            except Exception as e:
                logger.error(f"Error writing to Firestore medical_records: {e}")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Database write error while saving EHR record."
                )

        record_dict = {
            "id": record_id,
            "patientId": record_in.patient_id,
            "doctorId": actor.uid,
            "doctorName": actor.claims.get("name", "Attending Physician"),
            "diagnosis": record_in.diagnosis,
            "notes": record_in.notes,
            "prescription": record_in.prescription,
            "medicines": record_in.medicines,
            "date": datetime.now(timezone.utc).strftime("%d-%m-%Y"),
            "createdAt": now_iso,
        }
        self._in_memory_records[record_id] = record_dict

        logger.info(
            f"EHR record created ID={record_id} for patient={record_in.patient_id} by doctor={actor.uid}"
        )

        return EHRRecordResponse(
            id=record_id,
            patient_id=record_in.patient_id,
            doctor_id=actor.uid,
            doctor_name=actor.claims.get("name", "Attending Physician"),
            diagnosis=record_in.diagnosis,
            notes=record_in.notes,
            prescription=record_in.prescription,
            medicines=record_in.medicines,
            created_at=now_iso,
        )

    async def get_record_by_id(
        self, record_id: str, actor: AuthenticatedUser
    ) -> Optional[Dict[str, Any]]:
        """
        Retrieves a single medical record by recordId with strict authorization.
        Patients can only retrieve their own records.
        """
        db = self._get_db()
        record_data: Optional[Dict[str, Any]] = None

        if db:
            try:
                doc = db.collection("medical_records").document(record_id).get()
                if doc.exists:
                    record_data = doc.to_dict()
                    if record_data:
                        record_data["id"] = doc.id
            except Exception as e:
                logger.error(f"Error fetching record {record_id} from Firestore: {e}")

        if not record_data and record_id in self._in_memory_records:
            record_data = dict(self._in_memory_records[record_id])

        if not record_data:
            return None

        # Patient isolation check
        patient_id = record_data.get("patientId")
        if actor.role == UserRole.PATIENT and actor.uid != patient_id:
            logger.warning(
                f"Unauthorized record lookup attempt: Patient actor={actor.uid} requested record={record_id} belonging to patient={patient_id}"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Patients may only access their own medical records."
            )

        return record_data


ehr_service = EHRService()
