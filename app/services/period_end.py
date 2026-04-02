"""
Dönem sonu kapanış servisi
§18 — Kontrol listesi, dönem kapanışı, yeni dönem açılışı
"""

from __future__ import annotations
from typing import Any

from sqlalchemy import text
from sqlalchemy.orm import Session


def period_close_checklist(
    db: Session, company_id: int, fiscal_year_id: int, period_id: int
) -> list[dict[str, Any]]:
    """Dönem kapanış ön koşullarını kontrol eder."""
    checks = []

    # 1. Dengesiz fiş var mı?
    row = db.execute(
        text("""
            SELECT COUNT(*) AS cnt
            FROM vouchers
            WHERE company_id = :cid AND fiscal_year_id = :fid
              AND fiscal_period_id = :pid
              AND status = 'TASLAK'
        """),
        {"cid": company_id, "fid": fiscal_year_id, "pid": period_id},
    ).fetchone()
    checks.append({
        "check": "Onaysız fiş yok",
        "passed": (row.cnt == 0),
        "detail": f"{row.cnt} adet onaysız fiş mevcut" if row.cnt else None,
    })

    # 2. KDV beyanı hazır mı? (KDV dönemlerinde)
    row2 = db.execute(
        text("""
            SELECT COUNT(*) AS cnt
            FROM vat_periods
            WHERE company_id = :cid
              AND fiscal_period_id = :pid
              AND status NOT IN ('BEYAN_EDILDI', 'KAPALI')
        """),
        {"cid": company_id, "pid": period_id},
    ).fetchone()
    checks.append({
        "check": "KDV beyan hazır",
        "passed": (row2.cnt == 0),
        "detail": f"{row2.cnt} adet açık KDV dönemi" if row2.cnt else None,
    })

    # 3. Banka mutabakatı tamamlandı mı?
    row3 = db.execute(
        text("""
            SELECT COUNT(*) AS cnt
            FROM bank_transactions
            WHERE company_id = :cid
              AND transaction_date <= (
                  SELECT end_date FROM fiscal_periods WHERE id = :pid
              )
              AND is_reconciled = 0
        """),
        {"cid": company_id, "pid": period_id},
    ).fetchone()
    checks.append({
        "check": "Banka mutabakatı tamamlandı",
        "passed": (row3.cnt == 0),
        "detail": f"{row3.cnt} adet mutabakatlanmamış banka hareketi" if row3.cnt else None,
    })

    return checks


def close_period(
    db: Session,
    company_id: int,
    fiscal_year_id: int,
    period_id: int,
    closed_by: int,
) -> dict:
    """Dönemi kilitler ve kapanış kaydı oluşturur."""
    checks = period_close_checklist(db, company_id, fiscal_year_id, period_id)
    failed = [c for c in checks if not c["passed"]]
    if failed:
        details = "; ".join(c["check"] for c in failed)
        raise ValueError(f"Dönem kapatılamaz — başarısız kontroller: {details}")

    db.execute(
        text("""
            UPDATE fiscal_periods
            SET is_closed = 1, is_locked = 1,
                closed_at = CURRENT_TIMESTAMP, closed_by = :by
            WHERE company_id = :cid AND id = :pid
        """),
        {"by": closed_by, "cid": company_id, "pid": period_id},
    )

    db.execute(
        text("""
            INSERT INTO period_closing_records
                (company_id, fiscal_period_id, step_code, step_name, status, completed_at, completed_by, created_by)
            VALUES (:cid, :pid, 'PERIOD_CLOSE', 'Donem Kapanisi', 'TAMAMLANDI', CURRENT_TIMESTAMP, :by, :by)
        """),
        {"cid": company_id, "pid": period_id, "by": closed_by},
    )
    db.flush()
    return {"status": "closed", "period_id": period_id, "closed_by": closed_by}


def close_fiscal_year(
    db: Session,
    company_id: int,
    fiscal_year_id: int,
    closed_by: int,
) -> dict:
    """Mali yılı kapatır (tüm dönemler önce kapatılmış olmalı)."""
    open_periods = db.execute(
        text("""
            SELECT COUNT(*) AS cnt
            FROM fiscal_periods
            WHERE company_id = :cid AND fiscal_year_id = :fid AND is_closed = 0
        """),
        {"cid": company_id, "fid": fiscal_year_id},
    ).fetchone()

    if open_periods.cnt > 0:
        raise ValueError(
            f"Mali yıl kapatılamaz: {open_periods.cnt} açık dönem mevcut"
        )

    db.execute(
        text("""
            UPDATE fiscal_years
            SET is_closed = 1, closed_at = CURRENT_TIMESTAMP, closed_by = :by
            WHERE company_id = :cid AND id = :fid
        """),
        {"by": closed_by, "cid": company_id, "fid": fiscal_year_id},
    )
    db.flush()
    return {"status": "fiscal_year_closed", "fiscal_year_id": fiscal_year_id}
