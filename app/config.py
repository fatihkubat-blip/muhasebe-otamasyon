"""
Uygulama yapılandırması — pydantic-settings ile .env desteği
"""

from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ── Ortam ───────────────────────────────────────────────────────────────
    ENVIRONMENT: str = "development"          # development | staging | production
    DEBUG: bool = True

    # ── Veritabanı ──────────────────────────────────────────────────────────
    # Geliştirme: sqlite:///./data/muhasebe.db
    # Üretim:     mssql+pyodbc://user:pass@server:1433/muhasebe?driver=ODBC+Driver+18+for+SQL+Server
    DATABASE_URL: str = "sqlite:///./data/muhasebe.db"

    # SQL Server bağlantı havuzu ayarları (SQLite için göz ardı edilir)
    DB_POOL_SIZE: int = 5
    DB_MAX_OVERFLOW: int = 10
    DB_POOL_TIMEOUT: int = 30
    DB_ECHO: bool = False          # True → tüm SQL loglanır (geliştirme)

    # ── Güvenlik ────────────────────────────────────────────────────────────
    SECRET_KEY: str = "CHANGE_THIS_IN_PRODUCTION_MIN_32_CHARS"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # ── Şifreleme ────────────────────────────────────────────────────────────
    # bcrypt iş yükü faktörü (12 üretim için önerilir)
    BCRYPT_ROUNDS: int = 12

    # ── Sayfalama ────────────────────────────────────────────────────────────
    DEFAULT_PAGE_SIZE: int = 50
    MAX_PAGE_SIZE: int = 1000

    # ── e-Fatura / GİB entegrasyonu ─────────────────────────────────────────
    GIB_PROD_URL: str = "https://earsivportal.efatura.gov.tr"
    GIB_TEST_URL: str = "https://earsivportaltest.efatura.gov.tr"
    GIB_USE_PROD: bool = False
    GIB_API_USERNAME: str = ""
    GIB_API_PASSWORD: str = ""

    # ── e-Defter ─────────────────────────────────────────────────────────────
    ELEDGER_SUBMIT_URL: str = ""

    # ── E-posta (bildirimler) ────────────────────────────────────────────────
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_TLS: bool = True

    # ── Uygulama ─────────────────────────────────────────────────────────────
    APP_NAME: str = "Muhasebe Otomasyonu"
    APP_VERSION: str = "1.0.0"
    API_V1_PREFIX: str = "/api/v1"
    ALLOWED_HOSTS: list[str] = ["*"]

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT == "production"

    @property
    def is_sqlite(self) -> bool:
        return self.DATABASE_URL.startswith("sqlite")


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
