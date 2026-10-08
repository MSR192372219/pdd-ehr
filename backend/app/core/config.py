import os
from typing import List
from pydantic_settings import BaseSettings
from pydantic import Field, field_validator


class Settings(BaseSettings):
    """
    Centralized configuration for the Private Cloud Backend.
    Values are loaded from environment variables or .env file.
    """
    APP_NAME: str = "AI-Enabled Secure EHR Management System — Private Cloud API"
    APP_VERSION: str = "1.0.0"
    ENVIRONMENT: str = Field(default="development", description="Environment: development, staging, production")
    
    HOST: str = Field(default="127.0.0.1", description="Server bind host")
    PORT: int = Field(default=8000, description="Server bind port")
    
    LOG_LEVEL: str = Field(default="INFO", description="Log level: DEBUG, INFO, WARNING, ERROR")
    API_V1_PREFIX: str = Field(default="/api/v1", description="Root prefix for API version 1")
    
    # CORS Configuration - Comma separated origins or list
    ALLOWED_ORIGINS: str = Field(
        default="http://localhost:3000,http://localhost:8080,http://127.0.0.1:3000,http://127.0.0.1:8080",
        description="Comma-separated allowed origins for CORS. Wildcard '*' is forbidden in production."
    )
    
    # Firebase Server-Side Access Configuration
    FIREBASE_PROJECT_ID: str = Field(default="ehrsystem-32674f7e", description="Firebase project ID")
    FIREBASE_SERVICE_ACCOUNT_PATH: str | None = Field(default=None, description="Optional path to service account JSON")
    FIREBASE_CLIENT_EMAIL: str | None = Field(default=None, description="Optional service account client email")
    FIREBASE_PRIVATE_KEY: str | None = Field(default=None, description="Optional service account private key")
    
    # Blockchain Configuration
    BLOCKCHAIN_NETWORK: str = Field(
        default="LOCAL DEVELOPMENT BLOCKCHAIN (EVM)",
        description="Target blockchain network identifier"
    )
    BLOCKCHAIN_RPC_URL: str | None = Field(
        default=None,
        description="Optional JSON-RPC provider URL (e.g. http://127.0.0.1:8545). Defaults to in-process EVM."
    )
    BLOCKCHAIN_CONTRACT_ADDRESS: str | None = Field(
        default=None,
        description="Pre-deployed EHRIntegrityRegistry contract address. If None, auto-deploys on startup."
    )
    BLOCKCHAIN_ENABLED: bool = Field(
        default=True,
        description="Enable blockchain cryptographic anchoring"
    )
    
    # Phase 4: AI Provider Configuration
    AI_PROVIDER: str = Field(
        default="clinical_engine",
        description="AI provider: clinical_engine (local deterministic), openai, gemini, custom"
    )
    AI_API_KEY: str | None = Field(
        default=None,
        description="Optional API key for external AI provider"
    )
    AI_MODEL: str = Field(
        default="gpt-4o-mini",
        description="Model identifier for external AI provider"
    )
    AI_BASE_URL: str = Field(
        default="https://api.openai.com/v1",
        description="Base URL for external AI provider API"
    )
    AI_TIMEOUT_SECONDS: float = Field(
        default=15.0,
        description="Network timeout in seconds for AI calls"
    )
    AI_RATE_LIMIT_PER_MINUTE: int = Field(
        default=20,
        description="Rate limit: maximum AI requests per user per minute"
    )
    
    @property
    def cors_origins(self) -> List[str]:
        """Parses ALLOWED_ORIGINS string into a sanitized list of origin strings."""
        if not self.ALLOWED_ORIGINS:
            return []
        origins = [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",") if origin.strip()]
        if self.is_production and "*" in origins:
            raise ValueError("Wildcard '*' in ALLOWED_ORIGINS is strictly prohibited in production mode.")
        return origins

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT.lower() == "production"

    @property
    def is_development(self) -> bool:
        return self.ENVIRONMENT.lower() == "development"

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "extra": "ignore"
    }


# Singleton configuration instance
settings = Settings()
