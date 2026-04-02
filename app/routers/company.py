from calendar import monthrange
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.company import (
    CompanyCreate, CompanyUpdate, CompanyOut,
    BranchCreate, BranchOut,
    FiscalYearCreate, FiscalYearOut,
)

router = APIRouter(prefix="/companies", tags=["Company"])


@router.post("", response_model=CompanyOut, status_code=201)
def create_company(payload: CompanyCreate, db: Session = Depends(get_db)):
    try:
        db.execute(
            text("""
                INSERT INTO companies (
                    code, legal_name, trade_name, tax_number, tax_office,
                    mersis_no, trade_register_no,
                    address, city, district, country_code,
                    phone, email, web_site,
                    local_currency_code, reporting_currency_code,
                    fiscal_year_start_month, accounting_standard,
                    is_vat_liable, e_invoice_active, e_archive_active, e_ledger_active,
                    is_active
                ) VALUES (
                    :code, :legal_name, :trade_name, :tax_number, :tax_office,
                    :mersis_no, :trade_register_no,
                    :address, :city, :district, :country_code,
                    :phone, :email, :web_site,
                    :local_currency_code, :reporting_currency_code,
                    :fiscal_year_start_month, :accounting_standard,
                    :is_vat_liable, :e_invoice_active, :e_archive_active, :e_ledger_active,
                    1
                )
            """),
            payload.model_dump(),
        )
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Sirket kodu veya vergi numarasi zaten mevcut") from exc

    row = db.execute(
        text("SELECT * FROM companies WHERE code = :code"),
        {"code": payload.code},
    ).fetchone()
    return dict(row._mapping)


@router.get("", response_model=list[CompanyOut])
def list_companies(
    db: Session = Depends(get_db),
    is_active: bool = Query(True),
):
    rows = db.execute(
        text("SELECT * FROM companies WHERE is_active = :active ORDER BY code"),
        {"active": 1 if is_active else 0},
    ).fetchall()
    return [dict(r._mapping) for r in rows]


@router.get("/{company_id}", response_model=CompanyOut)
def get_company(company_id: int, db: Session = Depends(get_db)):
    row = db.execute(
        text("SELECT * FROM companies WHERE id = :id"),
        {"id": company_id},
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Şirket bulunamadı")
    return dict(row._mapping)


@router.patch("/{company_id}", response_model=CompanyOut)
def update_company(company_id: int, payload: CompanyUpdate, db: Session = Depends(get_db)):
    changes = payload.model_dump(exclude_none=True)
    if not changes:
        return get_company(company_id, db)

    set_clause = ", ".join(f"{k} = :{k}" for k in changes)
    changes["id"] = company_id

    db.execute(text(f"UPDATE companies SET {set_clause} WHERE id = :id"), changes)
    db.commit()
    return get_company(company_id, db)


# ── Şube uçları ───────────────────────────────────────────────────────────────

@router.post("/{company_id}/branches", response_model=BranchOut, status_code=201)
def create_branch(company_id: int, payload: BranchCreate, db: Session = Depends(get_db)):
    data = payload.model_dump()
    data["company_id"] = company_id

    db.execute(
        text("""
            INSERT INTO branches
                (company_id, code, name, address, city, is_head_office, is_active)
            VALUES
                (:company_id, :code, :name, :address, :city, :is_head_office, 1)
        """),
        data,
    )
    db.commit()

    row = db.execute(
        text("SELECT * FROM branches WHERE company_id = :cid AND code = :code"),
        {"cid": company_id, "code": payload.code},
    ).fetchone()
    return dict(row._mapping)


@router.get("/{company_id}/branches", response_model=list[BranchOut])
def list_branches(company_id: int, db: Session = Depends(get_db)):
    rows = db.execute(
        text("SELECT * FROM branches WHERE company_id = :cid ORDER BY code"),
        {"cid": company_id},
    ).fetchall()
    return [dict(r._mapping) for r in rows]


# ── Mali yıl uçları ───────────────────────────────────────────────────────────

@router.post("/{company_id}/fiscal-years", response_model=FiscalYearOut, status_code=201)
def create_fiscal_year(company_id: int, payload: FiscalYearCreate, db: Session = Depends(get_db)):
    data = payload.model_dump()
    data["company_id"] = company_id
    data["year_code"] = str(payload.fiscal_year)

    db.execute(
        text("""
            INSERT INTO fiscal_years
                (company_id, fiscal_year, year_code, start_date, end_date, is_closed)
            VALUES
                (:company_id, :fiscal_year, :year_code, :start_date, :end_date, 0)
        """),
        data,
    )

    # 12 aylık dönemleri otomatik üret
    fy = db.execute(
        text("""
            SELECT id, fiscal_year, start_date
            FROM fiscal_years
            WHERE company_id = :cid AND fiscal_year = :fy
        """),
        {"cid": company_id, "fy": payload.fiscal_year},
    ).fetchone()

    if fy:
        for i in range(1, 13):
            period_start = date(payload.fiscal_year, i, 1)
            period_end = date(payload.fiscal_year, i, monthrange(payload.fiscal_year, i)[1])
            db.execute(
                text("""
                    INSERT INTO fiscal_periods (
                        company_id, fiscal_year_id, period_no, period_name,
                        start_date, end_date, is_closed, is_locked, allow_retroactive_entry
                    ) VALUES (
                        :cid, :fyid, :pno, :pname,
                        :pstart, :pend,
                        0, 0, 0
                    )
                """),
                {
                    "cid": company_id,
                    "fyid": fy.id,
                    "pno": i,
                    "pname": f"{payload.fiscal_year}-{i:02d}",
                    "pstart": str(period_start),
                    "pend": str(period_end),
                },
            )

    db.commit()

    row = db.execute(
        text("SELECT * FROM fiscal_years WHERE company_id = :cid AND fiscal_year = :fy"),
        {"cid": company_id, "fy": payload.fiscal_year},
    ).fetchone()
    return dict(row._mapping)
