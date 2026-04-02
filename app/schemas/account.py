"""Hesap planı şemaları"""

from __future__ import annotations
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class AccountCreate(BaseModel):
    company_id: int
    code: str = Field(..., min_length=1, max_length=20)
    name: str = Field(..., min_length=1, max_length=200)
    short_name: Optional[str] = Field(None, max_length=50)
    account_class: str = Field(..., pattern=r"^[1-9]$")
    account_type: str = Field(
        ..., pattern=r"^(asset|liability|equity|revenue|expense|off_balance)$"
    )
    normal_balance: str = Field(..., pattern=r"^(D|A|B)$")
    parent_account_code: Optional[str] = Field(None, max_length=20)
    is_detail: bool = True                    # Detay hesap mı (fiş girilebilir)?
    currency_code: Optional[str] = Field(None, max_length=3)  # Dövizli hesap
    # TFRS/BOBİ/KÜMİ haritalama
    tfrs_mapping_code: Optional[str] = Field(None, max_length=30)
    bobi_mapping_code: Optional[str] = Field(None, max_length=30)
    kumi_mapping_code: Optional[str] = Field(None, max_length=30)
    # Bilanço / Gelir tablosu gruplaması
    balance_sheet_group: Optional[str] = Field(None, max_length=100)
    balance_sheet_line: Optional[str] = Field(None, max_length=100)
    income_stmt_group: Optional[str] = Field(None, max_length=100)
    income_stmt_line: Optional[str] = Field(None, max_length=100)
    # İlgili hesap (yansıtma hesabı)
    reflection_account_code: Optional[str] = Field(None, max_length=20)
    # Vergi ilişkisi
    tax_relation_type: Optional[str] = Field(None, max_length=30)
    default_vat_code_id: Optional[int] = None
    # Otomatik KDV hesabı
    auto_vat_account_code: Optional[str] = Field(None, max_length=20)
    notes: Optional[str] = None


class AccountUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    short_name: Optional[str] = Field(None, max_length=50)
    tfrs_mapping_code: Optional[str] = Field(None, max_length=30)
    bobi_mapping_code: Optional[str] = Field(None, max_length=30)
    kumi_mapping_code: Optional[str] = Field(None, max_length=30)
    balance_sheet_group: Optional[str] = Field(None, max_length=100)
    balance_sheet_line: Optional[str] = Field(None, max_length=100)
    income_stmt_group: Optional[str] = Field(None, max_length=100)
    income_stmt_line: Optional[str] = Field(None, max_length=100)
    reflection_account_code: Optional[str] = Field(None, max_length=20)
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class AccountOut(AccountCreate):
    id: int
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ── Masraf Merkezi ───────────────────────────────────────────────────────────

class CostCenterCreate(BaseModel):
    company_id: int
    code: str = Field(..., min_length=1, max_length=20)
    name: str = Field(..., min_length=1, max_length=200)
    parent_id: Optional[int] = None
    responsible_user_id: Optional[int] = None


class CostCenterOut(CostCenterCreate):
    id: int
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Proje ─────────────────────────────────────────────────────────────────────

class ProjectCreate(BaseModel):
    company_id: int
    code: str = Field(..., min_length=1, max_length=20)
    name: str = Field(..., min_length=1, max_length=200)
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    budget_kurus: Optional[int] = Field(None, ge=0)
    responsible_user_id: Optional[int] = None


class ProjectOut(ProjectCreate):
    id: int
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}
