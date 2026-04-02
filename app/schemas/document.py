"""Belge (fatura / alış belgesi / irsaliye vb.) şemaları"""

from __future__ import annotations
from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field


class DocumentLineIn(BaseModel):
    line_no: int = Field(..., ge=1)
    inventory_item_id: Optional[int] = None
    service_item_id: Optional[int] = None
    description: str = Field(..., min_length=1, max_length=500)
    quantity: Decimal = Field(..., gt=0)
    unit_code: str = Field(..., max_length=10)
    unit_price: Decimal = Field(..., ge=0, decimal_places=4)
    vat_code_id: Optional[int] = None
    discount_rate: Decimal = Field(Decimal("0"), ge=0, le=100)
    withholding_code_id: Optional[int] = None
    stopaj_code_id: Optional[int] = None
    warehouse_id: Optional[int] = None
    cost_center_id: Optional[int] = None
    project_id: Optional[int] = None


class DocumentCreate(BaseModel):
    company_id: int
    document_type_id: int
    fiscal_year_id: int
    fiscal_period_id: int
    current_account_id: Optional[int] = None
    branch_id: Optional[int] = None
    document_no: str = Field(..., min_length=1, max_length=50)
    document_date: date
    due_date: Optional[date] = None
    currency_code: str = Field("TRY", max_length=3)
    exchange_rate: Decimal = Field(Decimal("1"), gt=0)
    description: Optional[str] = Field(None, max_length=500)
    e_document_uuid: Optional[str] = Field(None, max_length=36)
    lines: list[DocumentLineIn] = Field(..., min_length=1)


class DocumentUpdate(BaseModel):
    description: Optional[str] = Field(None, max_length=500)
    due_date: Optional[date] = None
    is_cancelled: Optional[bool] = None


class DocumentLineOut(DocumentLineIn):
    id: int
    net_amount: Decimal
    vat_amount: Decimal
    total_amount: Decimal

    model_config = {"from_attributes": True}


class DocumentOut(BaseModel):
    id: int
    company_id: int
    document_type_id: int
    current_account_id: Optional[int] = None
    document_no: str
    document_date: date
    due_date: Optional[date] = None
    currency_code: str
    exchange_rate: Decimal
    description: Optional[str] = None
    e_document_no: Optional[str] = None
    subtotal_amount: Decimal
    total_vat_amount: Decimal
    total_amount: Decimal
    is_accounted: bool
    accounted_voucher_id: Optional[int] = None
    is_cancelled: bool
    created_at: datetime
    lines: list[DocumentLineOut] = []

    model_config = {"from_attributes": True}
