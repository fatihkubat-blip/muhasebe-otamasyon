"""Hesap planı router'ı"""

from __future__ import annotations
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.account import AccountCreate, AccountOut, AccountUpdate
from app.services import account as svc

router = APIRouter(prefix="/accounts", tags=["Hesap Planı"])

DbDep = Annotated[Session, Depends(get_db)]


@router.get("", response_model=list[AccountOut])
def list_accounts(
    db: DbDep,
    company_id: int = Query(...),
    account_class: Optional[str] = Query(None),
    is_detail: Optional[bool] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=1000),
):
    return svc.list_accounts(db, company_id, account_class, is_detail, skip=skip, limit=limit)


@router.get("/{account_id}", response_model=AccountOut)
def get_account(account_id: int, company_id: int = Query(...), db: DbDep = None):
    row = svc.get_account(db, company_id, account_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Hesap bulunamadı")
    return row


@router.post("", response_model=AccountOut, status_code=status.HTTP_201_CREATED)
def create_account(data: AccountCreate, db: DbDep = None):
    existing = svc.get_account_by_code(db, data.company_id, data.code)
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Hesap kodu zaten mevcut")
    result = svc.create_account(db, data, created_by=1)  # TODO: JWT'den user_id al
    db.commit()
    return result


@router.patch("/{account_id}", response_model=AccountOut)
def update_account(
    account_id: int,
    data: AccountUpdate,
    company_id: int = Query(...),
    db: DbDep = None,
):
    result = svc.update_account(db, company_id, account_id, data)
    if not result:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Hesap bulunamadı")
    db.commit()
    return result


@router.get("/{account_id}/balance")
def get_balance(
    account_id: int,
    company_id: int = Query(...),
    fiscal_year_id: int = Query(...),
    as_of_date: str = Query(..., description="YYYY-MM-DD"),
    db: DbDep = None,
):
    return svc.get_account_balance(db, company_id, account_id, fiscal_year_id, as_of_date)
