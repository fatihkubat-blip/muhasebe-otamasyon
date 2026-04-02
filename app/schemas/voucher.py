"""Yevmiye fişi şemaları"""

from __future__ import annotations
from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field, model_validator


class VoucherLineIn(BaseModel):
    line_no: int = Field(..., ge=1)
    account_id: int
    description: Optional[str] = Field(None, max_length=500)
    debit_amount: Decimal = Field(Decimal("0"), ge=0, decimal_places=2)
    credit_amount: Decimal = Field(Decimal("0"), ge=0, decimal_places=2)
    # Döviz
    currency_code: Optional[str] = Field(None, max_length=3)
    foreign_amount: Optional[Decimal] = Field(None, ge=0)
    exchange_rate: Optional[Decimal] = Field(None, gt=0)
    # Yardımcı modüller
    current_account_id: Optional[int] = None
    cost_center_id: Optional[int] = None
    project_id: Optional[int] = None
    # Vergi
    vat_code_id: Optional[int] = None
    vat_base_amount: Optional[Decimal] = Field(None, ge=0, decimal_places=2)
    vat_amount: Optional[Decimal] = Field(None, ge=0, decimal_places=2)
    withholding_vat_code_id: Optional[int] = None
    withholding_vat_base_amount: Optional[Decimal] = Field(None, ge=0, decimal_places=2)
    withholding_vat_amount: Optional[Decimal] = Field(None, ge=0, decimal_places=2)
    stopaj_code_id: Optional[int] = None
    stopaj_base_amount: Optional[Decimal] = Field(None, ge=0, decimal_places=2)
    stopaj_amount: Optional[Decimal] = Field(None, ge=0, decimal_places=2)
    # Vade
    due_date: Optional[date] = None

    @model_validator(mode="after")
    def exactly_one_side(self) -> VoucherLineIn:
        d = self.debit_amount or Decimal("0")
        c = self.credit_amount or Decimal("0")
        if d > 0 and c > 0:
            raise ValueError("Bir satırda hem borç hem alacak olamaz")
        if d == 0 and c == 0:
            raise ValueError("Satırda borç veya alacak tutarı girilmelidir")
        return self


class VoucherCreate(BaseModel):
    company_id: int
    fiscal_year_id: int
    fiscal_period_id: int
    voucher_type_id: int
    document_date: date
    posting_date: date
    description: str = Field(..., min_length=1, max_length=500)
    source_document_no: Optional[str] = Field(None, max_length=50)
    module_source: Optional[str] = Field(None, max_length=30)
    branch_id: Optional[int] = None
    lines: list[VoucherLineIn] = Field(..., min_length=2)

    @model_validator(mode="after")
    def balanced_entry(self) -> VoucherCreate:
        total_debit = sum(ln.debit_amount for ln in self.lines)
        total_credit = sum(ln.credit_amount for ln in self.lines)
        if total_debit != total_credit:
            raise ValueError(
                f"Fiş dengesiz: Borç {total_debit} ≠ Alacak {total_credit}"
            )
        return self


class VoucherApprove(BaseModel):
    voucher_id: int
    approved_by: int
    notes: Optional[str] = Field(None, max_length=500)


class VoucherReverse(BaseModel):
    voucher_id: int
    reverse_date: date
    reverse_description: Optional[str] = Field(None, max_length=500)
    reversed_by: int


class VoucherLineOut(BaseModel):
    id: int
    line_no: int
    account_id: int
    account_code: Optional[str] = None
    account_name: Optional[str] = None
    description: Optional[str] = None
    debit_amount: Decimal
    credit_amount: Decimal
    currency_code: Optional[str] = None
    foreign_amount: Optional[Decimal] = None
    exchange_rate: Optional[Decimal] = None
    current_account_id: Optional[int] = None
    cost_center_id: Optional[int] = None
    project_id: Optional[int] = None
    vat_code_id: Optional[int] = None
    vat_base_amount: Optional[Decimal] = None
    vat_amount: Optional[Decimal] = None
    due_date: Optional[date] = None

    model_config = {"from_attributes": True}


class VoucherOut(BaseModel):
    id: int
    company_id: int
    fiscal_year_id: int
    fiscal_period_id: int
    voucher_type_id: int
    journal_sequence_no: Optional[int] = None
    voucher_no: Optional[str] = None
    document_date: date
    posting_date: date
    description: str
    source_document_no: Optional[str] = None
    module_source: Optional[str] = None
    total_debit: Decimal
    total_credit: Decimal
    status: str
    created_by: Optional[int] = None
    created_at: datetime
    approved_by: Optional[int] = None
    approved_at: Optional[datetime] = None
    reverse_of_id: Optional[int] = None
    reversed_by_id: Optional[int] = None
    lines: list[VoucherLineOut] = []

    model_config = {"from_attributes": True}
