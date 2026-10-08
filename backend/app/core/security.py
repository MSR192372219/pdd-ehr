import json
import os
from typing import Any, Dict, Optional
import firebase_admin
from firebase_admin import auth, credentials, firestore
from app.core.config import settings
from app.core.logging_config import logger

_firebase_initialized = False


def initialize_firebase_admin() -> Optional[firebase_admin.App]:
    """
    Safely initializes the Firebase Admin SDK using secure credentials or project configuration.
    Never hardcodes credentials or exposes private keys.
    """
    global _firebase_initialized

    if len(firebase_admin._apps) > 0:
        _firebase_initialized = True
        return firebase_admin.get_app()

    try:
        cred = None
        # Option 1: File path to service account credentials (if securely mounted)
        if settings.FIREBASE_SERVICE_ACCOUNT_PATH and os.path.exists(settings.FIREBASE_SERVICE_ACCOUNT_PATH):
            cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
            logger.info("Initializing Firebase Admin SDK using certificate file path.")

        # Option 2: Environment variable credentials (e.g. AWS Secrets Manager or CI)
        elif settings.FIREBASE_CLIENT_EMAIL and settings.FIREBASE_PRIVATE_KEY:
            # Handle newline formatting in private key
            private_key = settings.FIREBASE_PRIVATE_KEY.replace("\\n", "\n")
            cred_dict = {
                "type": "service_account",
                "project_id": settings.FIREBASE_PROJECT_ID,
                "client_email": settings.FIREBASE_CLIENT_EMAIL,
                "private_key": private_key,
                "token_uri": "https://oauth2.googleapis.com/token",
            }
            cred = credentials.Certificate(cred_dict)
            logger.info("Initializing Firebase Admin SDK using environment credentials.")

        # Option 3: Default application credentials or project ID
        if cred:
            app = firebase_admin.initialize_app(cred, {"projectId": settings.FIREBASE_PROJECT_ID})
        else:
            # Initializes with Google Application Default Credentials or standard project options
            app = firebase_admin.initialize_app(options={"projectId": settings.FIREBASE_PROJECT_ID})
            logger.info(f"Initializing Firebase Admin SDK with default credentials for project {settings.FIREBASE_PROJECT_ID}.")

        _firebase_initialized = True
        return app

    except Exception as e:
        logger.warning(f"Firebase Admin SDK initialization deferred or running in offline mode: {e}")
        return None


def verify_firebase_id_token(id_token: str) -> Dict[str, Any]:
    """
    Verifies a Firebase Authentication ID token cryptographically.
    Extracts the authenticated payload and strictly verifies expiration, signature, and project ID.
    Raises ValueError or auth.InvalidIdTokenError on failure.
    """
    if not id_token or not id_token.strip():
        raise ValueError("Token string is missing or empty.")

    # Ensure Firebase Admin is initialized before verification
    initialize_firebase_admin()

    try:
        # verify_id_token validates token signature, expiration, and audience against FIREBASE_PROJECT_ID
        decoded_token = auth.verify_id_token(id_token, check_revoked=True)
        return decoded_token
    except Exception as e:
        logger.warning(f"Firebase token verification failed: {e}")
        raise
