from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db

router = APIRouter(prefix="/parameters", tags=["Parameters"])


@router.get("/system")
def list_system_parameters(
    company_id: int | None = Query(None),
    db: Session = Depends(get_db),
):
    if company_id is None:
        rows = db.execute(
            text("SELECT * FROM system_parameters WHERE company_id IS NULL ORDER BY parameter_key")
        ).fetchall()
    else:
        rows = db.execute(
            text("""
                SELECT * FROM system_parameters
                WHERE company_id = :cid OR company_id IS NULL
                ORDER BY company_id DESC, parameter_key
            """),
            {"cid": company_id},
        ).fetchall()
    return [dict(r._mapping) for r in rows]


@router.get("/regulatory")
def list_regulatory_parameters(db: Session = Depends(get_db)):
    rows = db.execute(
        text("SELECT * FROM regulatory_parameters ORDER BY parameter_key, effective_date DESC")
    ).fetchall()
    return [dict(r._mapping) for r in rows]


@router.get("/vat-codes")
def list_vat_codes(db: Session = Depends(get_db), active: bool = Query(True)):
    rows = db.execute(
        text("SELECT * FROM vat_codes WHERE is_active = :active ORDER BY code"),
        {"active": 1 if active else 0},
    ).fetchall()
    return [dict(r._mapping) for r in rows]


@router.get("/withholding-vat-codes")
def list_withholding_vat_codes(db: Session = Depends(get_db), active: bool = Query(True)):
    rows = db.execute(
        text("SELECT * FROM withholding_vat_codes WHERE is_active = :active ORDER BY code"),
        {"active": 1 if active else 0},
    ).fetchall()
    return [dict(r._mapping) for r in rows]


@router.get("/stopaj-codes")
def list_stopaj_codes(db: Session = Depends(get_db), active: bool = Query(True)):
    rows = db.execute(
        text("SELECT * FROM stopaj_codes WHERE is_active = :active ORDER BY code"),
        {"active": 1 if active else 0},
    ).fetchall()
    return [dict(r._mapping) for r in rows]
