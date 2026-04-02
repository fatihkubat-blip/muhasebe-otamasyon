"""Şirket, şube, mali yıl ve dönem şemaları"""

from __future__ import annotations
from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, Field, field_validator


class CompanyCreate(BaseModel):
    code: str = Field(..., min_length=1, max_length=20)
    legal_name: str = Field(..., min_length=1, max_length=200)
    trade_name: Optional[str] = Field(None, max_length=200)
    tax_number: str = Field(..., min_length=10, max_length=11)
    tax_office: Optional[str] = Field(None, max_length=100)
    mersis_no: Optional[str] = Field(None, max_length=20)
    trade_register_no: Optional[str] = Field(None, max_length=50)
    address: Optional[str] = Field(None, max_length=500)
    city: Optional[str] = Field(None, max_length=100)
    district: Optional[str] = Field(None, max_length=100)
    country_code: str = Field("TR", max_length=2)
    phone: Optional[str] = Field(None, max_length=20)
    email: Optional[str] = Field(None, max_length=200)
    web_site: Optional[str] = Field(None, max_length=200)
    local_currency_code: str = Field("TRY", max_length=3)
    reporting_currency_code: Optional[str] = Field(None, max_length=3)
    fiscal_year_start_month: int = Field(1, ge=1, le=12)
    accounting_standard: str = Field(
        "VUK",
        pattern=r"^(VUK|TFRS|BOBI_FRS|KUMI_FRS)$",
    )
    is_vat_liable: bool = True
    e_invoice_active: bool = False
    e_archive_active: bool = False
    e_ledger_active: bool = False

    @field_validator("tax_number")
    @classmethod
    def validate_tax_number(cls, v: str) -> str:
        if not v.isdigit():
            raise ValueError("VKN/TCKN yalnızca rakam içermelidir")
        if len(v) not in (10, 11):
            raise ValueError("VKN 10 haneli, TCKN 11 haneli olmalıdır")
        return v


class CompanyUpdate(BaseModel):
    legal_name: Optional[str] = Field(None, min_length=1, max_length=200)
    trade_name: Optional[str] = Field(None, max_length=200)
    tax_office: Optional[str] = Field(None, max_length=100)
    address: Optional[str] = Field(None, max_length=500)
    city: Optional[str] = Field(None, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    email: Optional[str] = Field(None, max_length=200)
    e_invoice_active: Optional[bool] = None
    e_archive_active: Optional[bool] = None
    e_ledger_active: Optional[bool] = None
    is_active: Optional[bool] = None


class CompanyOut(CompanyCreate):
    id: int
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ── Şube ─────────────────────────────────────────────────────────────────────

class BranchCreate(BaseModel):
    company_id: int
    code: str = Field(..., min_length=1, max_length=20)
    name: str = Field(..., min_length=1, max_length=200)
    address: Optional[str] = Field(None, max_length=500)
    city: Optional[str] = Field(None, max_length=100)
    is_head_office: bool = False


class BranchOut(BranchCreate):
    id: int
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Mali Yıl ─────────────────────────────────────────────────────────────────

class FiscalYearCreate(BaseModel):
    company_id: int
    fiscal_year: int = Field(..., ge=2000, le=2099)
    start_date: date
    end_date: date

    @field_validator("end_date")
    @classmethod
    def end_after_start(cls, v: date, info) -> date:
        if "start_date" in info.data and v <= info.data["start_date"]:
            raise ValueError("Bitiş tarihi başlangıç tarihinden sonra olmalıdır")
        return v


class FiscalYearOut(FiscalYearCreate):
    id: int
    year_code: str
    is_closed: bool
    closed_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ── Mali Dönem ────────────────────────────────────────────────────────────────

class FiscalPeriodOut(BaseModel):
    id: int
    fiscal_year_id: int
    company_id: int
    period_no: int
    period_name: str
    start_date: date
    end_date: date
    is_closed: bool
    is_locked: bool

    model_config = {"from_attributes": True}
