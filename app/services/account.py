"""
Hesap servisi — CRUD + bakiye sorgulama
Kuruş dönüşümü: Decimal(2 hane) * 100 → BIGINT kuruş
"""

from __future__ import annotations
from decimal import Decimal
from typing import Any

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.schemas.account import AccountCreate, AccountUpdate


def _to_account_row(row) -> dict[str, Any]:
    d = dict(row._mapping)
    return d


def get_account(db: Session, company_id: int, account_id: int) -> dict | None:
    result = db.execute(
        text("""
            SELECT a.*, p.code AS parent_code
            FROM accounts a
            LEFT JOIN accounts p ON p.id = a.parent_account_id
            WHERE a.company_id = :cid AND a.id = :id
        """),
        {"cid": company_id, "id": account_id},
    ).fetchone()
    return _to_account_row(result) if result else None


def get_account_by_code(db: Session, company_id: int, code: str) -> dict | None:
    result = db.execute(
        text("SELECT * FROM accounts WHERE company_id = :cid AND code = :code"),
        {"cid": company_id, "code": code},
    ).fetchone()
    return _to_account_row(result) if result else None


def list_accounts(
    db: Session,
    company_id: int,
    account_class: str | None = None,
    is_detail: bool | None = None,
    is_active: bool = True,
    skip: int = 0,
    limit: int = 200,
) -> list[dict]:
    filters = ["a.company_id = :cid", "a.is_active = :active"]
    params: dict[str, Any] = {"cid": company_id, "active": 1 if is_active else 0}

    if account_class:
        filters.append("a.account_class = :cls")
        params["cls"] = account_class
    if is_detail is not None:
        filters.append("a.is_detail = :det")
        params["det"] = 1 if is_detail else 0

    params["skip"] = skip
    params["limit"] = limit

    dialect = db.bind.dialect.name if db.bind is not None else ""
    if dialect.startswith("mssql"):
        sql = f"""
            SELECT a.*
            FROM accounts a
            WHERE {' AND '.join(filters)}
            ORDER BY a.code
            OFFSET :skip ROWS FETCH NEXT :limit ROWS ONLY
        """
    else:
        sql = f"""
            SELECT a.*
            FROM accounts a
            WHERE {' AND '.join(filters)}
            ORDER BY a.code
            LIMIT :limit OFFSET :skip
        """

    rows = db.execute(text(sql), params).fetchall()
    return [_to_account_row(r) for r in rows]


def create_account(db: Session, data: AccountCreate, created_by: int) -> dict:
    # Üst hesabı koddan bul
    parent_id = None
    if data.parent_account_code:
        parent = get_account_by_code(db, data.company_id, data.parent_account_code)
        if parent:
            parent_id = parent["id"]

    result = db.execute(
        text("""
            INSERT INTO accounts (
                company_id, code, name, short_name, account_class, account_type,
                normal_balance, parent_account_id, is_detail, currency_code,
                tfrs_mapping_code, bobi_mapping_code, kumi_mapping_code,
                balance_sheet_group, balance_sheet_line,
                income_stmt_group, income_stmt_line,
                reflection_account_code, tax_relation_type,
                default_vat_code_id, auto_vat_account_code,
                notes, is_active, created_by
            ) VALUES (
                :company_id, :code, :name, :short_name, :account_class, :account_type,
                :normal_balance, :parent_id, :is_detail, :currency_code,
                :tfrs, :bobi, :kumi, :bs_group, :bs_line,
                :is_group, :is_line, :reflection, :tax_rel, :vat_code_id, :auto_vat,
                :notes, 1, :created_by
            )
        """),
        {
            "company_id": data.company_id,
            "code": data.code,
            "name": data.name,
            "short_name": data.short_name,
            "account_class": data.account_class,
            "account_type": data.account_type,
            "normal_balance": data.normal_balance,
            "parent_id": parent_id,
            "is_detail": 1 if data.is_detail else 0,
            "currency_code": data.currency_code,
            "tfrs": data.tfrs_mapping_code,
            "bobi": data.bobi_mapping_code,
            "kumi": data.kumi_mapping_code,
            "bs_group": data.balance_sheet_group,
            "bs_line": data.balance_sheet_line,
            "is_group": data.income_stmt_group,
            "is_line": data.income_stmt_line,
            "reflection": data.reflection_account_code,
            "tax_rel": data.tax_relation_type,
            "vat_code_id": data.default_vat_code_id,
            "auto_vat": data.auto_vat_account_code,
            "notes": data.notes,
            "created_by": created_by,
        },
    )
    db.flush()
    new_id = result.lastrowid
    return get_account(db, data.company_id, new_id)


def update_account(
    db: Session, company_id: int, account_id: int, data: AccountUpdate
) -> dict | None:
    changes = data.model_dump(exclude_none=True)
    if not changes:
        return get_account(db, company_id, account_id)

    set_clause = ", ".join(f"{k} = :{k}" for k in changes)
    changes["cid"] = company_id
    changes["id"] = account_id

    db.execute(
        text(f"UPDATE accounts SET {set_clause} WHERE company_id = :cid AND id = :id"),
        changes,
    )
    db.flush()
    return get_account(db, company_id, account_id)


def get_account_balance(
    db: Session,
    company_id: int,
    account_id: int,
    fiscal_year_id: int,
    as_of_date: str,
) -> dict:
    row = db.execute(
        text("""
            SELECT
                SUM(vl.debit_kurus)  AS total_debit_kurus,
                SUM(vl.credit_kurus) AS total_credit_kurus
            FROM voucher_lines vl
            INNER JOIN vouchers v ON v.id = vl.voucher_id
            WHERE v.company_id     = :cid
              AND v.fiscal_year_id = :fid
              AND v.posting_date  <= :dt
              AND v.status        <> 'IPTAL'
              AND vl.account_id   = :aid
        """),
        {"cid": company_id, "fid": fiscal_year_id, "dt": as_of_date, "aid": account_id},
    ).fetchone()

    d = (row.total_debit_kurus or 0) if row else 0
    c = (row.total_credit_kurus or 0) if row else 0
    return {
        "account_id": account_id,
        "total_debit": Decimal(d) / 100,
        "total_credit": Decimal(c) / 100,
        "balance": Decimal(d - c) / 100,
    }
