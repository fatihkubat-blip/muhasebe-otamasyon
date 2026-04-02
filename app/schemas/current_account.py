"""Cari hesap şemaları"""

from __future__ import annotations
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, field_validator


class CurrentAccountCreate(BaseModel):
    company_id: int
    type_id: int
    code: str = Field(..., min_length=1, max_length=30)
    title: str = Field(..., min_length=1, max_length=200)
    tax_number: Optional[str] = Field(None, max_length=11)
    tax_office: Optional[str] = Field(None, max_length=100)
    mersis_no: Optional[str] = Field(None, max_length=20)
    trade_register_no: Optional[str] = Field(None, max_length=50)
    address: Optional[str] = Field(None, max_length=500)
    city: Optional[str] = Field(None, max_length=100)
    district: Optional[str] = Field(None, max_length=100)
    country_code: str = Field("TR", max_length=2)
    phone: Optional[str] = Field(None, max_length=20)
    email: Optional[str] = Field(None, max_length=200)
    iban: Optional[str] = Field(None, max_length=34)
    account_id: Optional[int] = None
    payment_days: int = Field(30, ge=0, le=365)
    credit_limit: Optional[float] = Field(None, ge=0)
    currency_code: str = Field("TRY", max_length=3)
    e_invoice_registered: bool = False
    e_invoice_alias: Optional[str] = Field(None, max_length=100)
    e_archive_applicable: bool = False
    withholding_applicable: bool = False
    stopaj_applicable: bool = False
    reconciliation_type: Optional[str] = Field(None, max_length=20)

    @field_validator("tax_number")
    @classmethod
    def validate_tax_number(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            if not v.isdigit():
                raise ValueError("VKN/TCKN yalnızca rakam içermelidir")
            if len(v) not in (10, 11):
                raise ValueError("VKN 10 haneli, TCKN 11 haneli olmalıdır")
        return v


class CurrentAccountUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    address: Optional[str] = Field(None, max_length=500)
    city: Optional[str] = Field(None, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    email: Optional[str] = Field(None, max_length=200)
    iban: Optional[str] = Field(None, max_length=34)
    payment_days: Optional[int] = Field(None, ge=0, le=365)
    credit_limit: Optional[float] = Field(None, ge=0)
    e_invoice_registered: Optional[bool] = None
    e_invoice_alias: Optional[str] = Field(None, max_length=100)
    e_archive_applicable: Optional[bool] = None
    withholding_applicable: Optional[bool] = None
    stopaj_applicable: Optional[bool] = None
    reconciliation_type: Optional[str] = Field(None, max_length=20)
    is_active: Optional[bool] = None


class CurrentAccountOut(CurrentAccountCreate):
    id: int
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}
