from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.voucher import VoucherCreate, VoucherApprove, VoucherReverse
from app.services import voucher as svc

router = APIRouter(prefix="/vouchers", tags=["Voucher"])


@router.post("", status_code=status.HTTP_201_CREATED)
def create_voucher(payload: VoucherCreate, db: Session = Depends(get_db)):
    try:
        result = svc.create_voucher(db, payload, created_by=1)
        db.commit()
        return result
    except ValueError as exc:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("", status_code=200)
def list_vouchers(
    company_id: int = Query(...),
    fiscal_year_id: int = Query(...),
    start_date: date | None = Query(None),
    end_date: date | None = Query(None),
    status_filter: str | None = Query(None, alias="status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
):
    return svc.list_vouchers(
        db,
        company_id=company_id,
        fiscal_year_id=fiscal_year_id,
        start_date=start_date,
        end_date=end_date,
        status=status_filter,
        skip=skip,
        limit=limit,
    )


@router.get("/{voucher_id}")
def get_voucher(voucher_id: int, company_id: int = Query(...), db: Session = Depends(get_db)):
    row = svc.get_voucher(db, company_id=company_id, voucher_id=voucher_id)
    if not row:
        raise HTTPException(status_code=404, detail="Fiş bulunamadı")
    return row


@router.post("/{voucher_id}/approve")
def approve_voucher(voucher_id: int, payload: VoucherApprove, db: Session = Depends(get_db)):
    if payload.voucher_id != voucher_id:
        raise HTTPException(status_code=400, detail="URL ve payload fiş no uyuşmuyor")
    try:
        result = svc.approve_voucher(db, payload)
        db.commit()
        return result
    except ValueError as exc:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/{voucher_id}/reverse")
def reverse_voucher(voucher_id: int, payload: VoucherReverse, db: Session = Depends(get_db)):
    if payload.voucher_id != voucher_id:
        raise HTTPException(status_code=400, detail="URL ve payload fiş no uyuşmuyor")
    try:
        result = svc.reverse_voucher(db, payload)
        db.commit()
        return result
    except ValueError as exc:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/{voucher_id}/cancel")
def cancel_voucher(voucher_id: int, company_id: int = Query(...), db: Session = Depends(get_db)):
    try:
        result = svc.cancel_voucher(db, company_id=company_id, voucher_id=voucher_id, cancelled_by=1)
        db.commit()
        return result
    except ValueError as exc:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(exc)) from exc
