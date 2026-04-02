"""
Veritabanı motoru ve oturum yönetimi
SQLAlchemy 2.x — SQL Server (üretim) ve SQLite (geliştirme) desteği
"""

from contextlib import contextmanager
from pathlib import Path
from typing import Generator

from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import settings

BASE_DIR = Path(__file__).resolve().parent.parent

# ── Motor parametreleri ──────────────────────────────────────────────────────
_connect_args: dict = {}
_pool_kwargs: dict = {}

if settings.is_sqlite:
    # SQLite veri dizinini oluştur
    _db_path = BASE_DIR / "data"
    _db_path.mkdir(parents=True, exist_ok=True)
    _connect_args = {"check_same_thread": False}
else:
    _pool_kwargs = {
        "pool_size": settings.DB_POOL_SIZE,
        "max_overflow": settings.DB_MAX_OVERFLOW,
        "pool_timeout": settings.DB_POOL_TIMEOUT,
        "pool_pre_ping": True,
    }

engine = create_engine(
    settings.DATABASE_URL,
    connect_args=_connect_args,
    echo=settings.DB_ECHO,
    **_pool_kwargs,
)

# SQLite: WAL modu + yabancı anahtar zorlaması
if settings.is_sqlite:
    @event.listens_for(engine, "connect")
    def _sqlite_pragmas(dbapi_conn, _connection_record):
        cur = dbapi_conn.cursor()
        cur.execute("PRAGMA journal_mode=WAL")
        cur.execute("PRAGMA foreign_keys=ON")
        cur.close()

SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    """FastAPI bağımlılığı: her istek için izole DB oturumu."""
    db = SessionLocal()
    try:
        yield db
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


@contextmanager
def db_session() -> Generator[Session, None, None]:
    """Servis katmanında context manager olarak kullanım."""
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def init_db() -> None:
    """
    SQLite geliştirme modunda şemayı başlatır.
    Üretimde Flyway veya Alembic kullanılır.
    """
    if settings.is_sqlite:
        schema_path = BASE_DIR / "sql" / "schema.sql"
        seed_path = BASE_DIR / "sql" / "seed.sql"
        if schema_path.exists():
            sql_script = schema_path.read_text(encoding="utf-8")
            raw_conn = engine.raw_connection()
            try:
                cursor = raw_conn.cursor()
                cursor.executescript(sql_script)
                if seed_path.exists():
                    cursor.executescript(seed_path.read_text(encoding="utf-8"))
                raw_conn.commit()
                cursor.close()
            finally:
                raw_conn.close()


def health_check() -> bool:
    """Veritabanı bağlantısını denetler."""
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
