from typing import Any, Callable, Dict, List, Optional
from fastapi import Depends, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import firebase_admin
from firebase_admin import auth as fb_auth, firestore
from app.core.config import settings
from app.core.logging_config import logger
from app.core.security import verify_firebase_id_token
from app.models.schemas import AuthenticatedUser, UserRole

# Reusable security scheme for Bearer token extraction
security_scheme = HTTPBearer(auto_error=False)


def _resolve_user_role(uid: str, decoded_token: Dict[str, Any]) -> UserRole:
    """
    Authoritatively determines user role from verified token claims or Firestore.
    Never relies on client headers or arbitrary request body assertions.
    """
    # 1. Check custom claims in verified token
    token_role = decoded_token.get("role") or decoded_token.get("claims", {}).get("role")
    if token_role:
        try:
            return UserRole(token_role.lower())
        except ValueError:
            pass

    # 2. Lookup Firestore users/{uid} if Firebase Admin is connected
    try:
        if len(firebase_admin._apps) > 0:
            db = firestore.client()
            user_doc = db.collection("users").document(uid).get()
            if user_doc.exists:
                data = user_doc.to_dict() or {}
                role_str = data.get("role", "").lower()
                if role_str in [r.value for r in UserRole]:
                    return UserRole(role_str)
    except Exception as e:
        logger.debug(f"Firestore role lookup deferred or unavailable in offline mode: {e}")

    # 3. Default fallback based on verified token context
    # If admin claim exists
    if decoded_token.get("admin") is True:
        return UserRole.ADMIN

    # Default to patient (least privileged role)
    return UserRole.PATIENT


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security_scheme)
) -> AuthenticatedUser:
    """
    FastAPI dependency that extracts and validates the Firebase ID token from the Authorization header.
    Derives UID and Role securely without trusting client claims.
    """
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required. Missing Bearer ID token in Authorization header.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials.strip()

    try:
        decoded_token = verify_firebase_id_token(token)
    except Exception as e:
        logger.warning(f"Rejected invalid or expired authentication token: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid, expired, or revoked authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    uid = decoded_token.get("uid") or decoded_token.get("user_id")
    if not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token verification succeeded but no authenticated UID was found.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    email = decoded_token.get("email")
    role = _resolve_user_role(uid, decoded_token)

    return AuthenticatedUser(
        uid=uid,
        email=email,
        role=role,
        claims=decoded_token
    )


def require_role(allowed_roles: List[UserRole]) -> Callable[[AuthenticatedUser], AuthenticatedUser]:
    """
    Dependency factory that enforces server-side role-based access control (RBAC).
    Raises HTTP 403 Forbidden if user's role is not within allowed_roles.
    """
    async def role_checker(current_user: AuthenticatedUser = Depends(get_current_user)) -> AuthenticatedUser:
        if current_user.role not in allowed_roles:
            logger.warning(
                f"Unauthorized access attempt by actor UID={current_user.uid} (Role={current_user.role}) "
                f"to resource requiring {[r.value for r in allowed_roles]}."
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Required role in {[r.value for r in allowed_roles]}, but user has role '{current_user.role.value}'.",
            )
        return current_user

    return role_checker


# Role-specific convenience dependencies
require_patient = require_role([UserRole.PATIENT])
require_doctor = require_role([UserRole.DOCTOR])
require_admin = require_role([UserRole.ADMIN])
require_clinical_staff = require_role([UserRole.DOCTOR, UserRole.ADMIN])
require_authenticated = get_current_user
