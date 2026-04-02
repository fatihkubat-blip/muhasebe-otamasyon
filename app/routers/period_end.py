from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.services import period_end as svc

router = APIRouter(prefix="/period-end", tags=["Period End"])


@router.get("/checklist")
def checklist(company_id: int, fiscal_year_id: int, period_id: int, db: Session = Depends(get_db)):
    return svc.period_close_checklist(db, company_id, fiscal_year_id, period_id)


@router.post("/close-period")
def close_period(company_id: int, fiscal_year_id: int, period_id: int, db: Session = Depends(get_db)):
    try:
        result = svc.close_period(db, company_id, fiscal_year_id, period_id, closed_by=1)
        db.commit()
        return result
    except ValueError as exc:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/close-fiscal-year")
def close_fiscal_year(company_id: int, fiscal_year_id: int, db: Session = Depends(get_db)):
    try:
        result = svc.close_fiscal_year(db, company_id, fiscal_year_id, closed_by=1)
        db.commit()
        return result
    except ValueError as exc:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(exc)) from exc
