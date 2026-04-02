#!/usr/bin/env python3
"""SQL Server migration + seed bootstrap utility.

Runs all SQL files in sql/migrations in filename order, then executes sql/seed/seed_full.sql.
Designed to work from terminal only (no SSMS required).
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.engine import Connection

GO_SPLIT_RE = re.compile(r"^\s*GO\s*(?:--.*)?$", flags=re.IGNORECASE | re.MULTILINE)


def split_batches(sql_text: str) -> list[str]:
    parts = GO_SPLIT_RE.split(sql_text)
    return [p.strip() for p in parts if p.strip()]


def execute_sql_file(conn: Connection, sql_file: Path) -> None:
    sql_text = sql_file.read_text(encoding="utf-8")
    batches = split_batches(sql_text)
    if not batches:
        print(f"[SKIP] {sql_file.name}: no executable batch found")
        return

    print(f"[RUN ] {sql_file.name}: {len(batches)} batch")
    for i, batch in enumerate(batches, start=1):
        try:
            conn.exec_driver_sql(batch)
        except Exception as exc:  # noqa: BLE001
            print(f"[FAIL] {sql_file.name} batch {i}/{len(batches)}")
            raise RuntimeError(str(exc)) from exc
    print(f"[ OK ] {sql_file.name}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Bootstrap SQL Server schema and seed data")
    parser.add_argument(
        "--database-url",
        default=os.getenv("DATABASE_URL", ""),
        help="SQLAlchemy DB URL (mssql+pyodbc://...)",
    )
    parser.add_argument(
        "--migrations-dir",
        default="sql/migrations",
        help="Migration directory path",
    )
    parser.add_argument(
        "--seed-file",
        default="sql/seed/seed_full.sql",
        help="Seed SQL file path",
    )
    args = parser.parse_args()

    db_url = (args.database_url or "").strip()
    if not db_url:
        print("DATABASE_URL is required. Pass --database-url or set env var DATABASE_URL.")
        return 2
    if not db_url.startswith("mssql+"):
        print("This bootstrap is for SQL Server only. DATABASE_URL should start with 'mssql+'.")
        return 2

    migrations_dir = Path(args.migrations_dir)
    seed_file = Path(args.seed_file)

    if not migrations_dir.exists():
        print(f"Migrations directory not found: {migrations_dir}")
        return 2
    if not seed_file.exists():
        print(f"Seed file not found: {seed_file}")
        return 2

    migration_files = sorted(migrations_dir.glob("V*.sql"))
    if not migration_files:
        print(f"No migration files found in {migrations_dir}")
        return 2

    print("Connecting to SQL Server...")
    engine = create_engine(db_url, future=True)

    try:
        with engine.begin() as conn:
            for sql_file in migration_files:
                execute_sql_file(conn, sql_file)
            execute_sql_file(conn, seed_file)
    except Exception as exc:  # noqa: BLE001
        print(f"\nBootstrap failed: {exc}")
        return 1
    finally:
        engine.dispose()

    print("\nSQL Server bootstrap completed successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
