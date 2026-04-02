from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.current_account import CurrentAccountCreate, CurrentAccountUpdate, CurrentAccountOut

router = APIRouter(prefix="/current-accounts", tags=["Current Account"])


@router.post("", response_model=CurrentAccountOut, status_code=201)
def create_current_account(payload: CurrentAccountCreate, db: Session = Depends(get_db)):
    db.execute(
        text("""
            INSERT INTO current_accounts (
                company_id, type_id, code, title,
                tax_number, tax_office, mersis_no, trade_register_no,
                address, city, district, country_code,
                phone, email, iban,
                account_id, payment_days, credit_limit,
                currency_code, e_invoice_registered, e_invoice_alias,
                e_archive_applicable, withholding_applicable, stopaj_applicable,
                reconciliation_type, is_active
            ) VALUES (
                :company_id, :type_id, :code, :title,
                :tax_number, :tax_office, :mersis_no, :trade_register_no,
                :address, :city, :district, :country_code,
                :phone, :email, :iban,
                :account_id, :payment_days, :credit_limit,
                :currency_code, :e_invoice_registered, :e_invoice_alias,
                :e_archive_applicable, :withholding_applicable, :stopaj_applicable,
                :reconciliation_type, 1
            )
        """),
        payload.model_dump(),
    )
    db.commit()
    row = db.execute(
        text("SELECT * FROM current_accounts WHERE company_id = :cid AND code = :code"),
        {"cid": payload.company_id, "code": payload.code},
    ).fetchone()
    return dict(row._mapping)


@router.get("", response_model=list[CurrentAccountOut])
def list_current_accounts(
    company_id: int = Query(...),
    is_active: bool = Query(True),
    db: Session = Depends(get_db),
):
    rows = db.execute(
        text("""
            SELECT * FROM current_accounts
            WHERE company_id = :cid AND is_active = :active
            ORDER BY code
        """),
        {"cid": company_id, "active": 1 if is_active else 0},
    ).fetchall()
    return [dict(r._mapping) for r in rows]


@router.patch("/{current_account_id}", response_model=CurrentAccountOut)
def update_current_account(
    current_account_id: int,
    payload: CurrentAccountUpdate,
    company_id: int = Query(...),
    db: Session = Depends(get_db),
):
    changes = payload.model_dump(exclude_none=True)
    if not changes:
        row = db.execute(
            text("SELECT * FROM current_accounts WHERE id = :id AND company_id = :cid"),
            {"id": current_account_id, "cid": company_id},
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Cari hesap bulunamadı")
        return dict(row._mapping)

    set_clause = ", ".join(f"{k} = :{k}" for k in changes)
    changes["id"] = current_account_id
    changes["cid"] = company_id

    db.execute(
        text(f"UPDATE current_accounts SET {set_clause} WHERE id = :id AND company_id = :cid"),
        changes,
    )
    db.commit()

    row = db.execute(
        text("SELECT * FROM current_accounts WHERE id = :id AND company_id = :cid"),
        {"id": current_account_id, "cid": company_id},
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Cari hesap bulunamadı")
    return dict(row._mapping)
