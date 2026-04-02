"""Sistem/mevzuat parametre ve vergi kodu şemaları"""

from __future__ import annotations
from datetime import datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field


class SystemParameterOut(BaseModel):
    id: int
    company_id: Optional[int]
    parameter_key: str
    parameter_value: str
    description: Optional[str]
    updated_at: Optional[datetime]

    model_config = {"from_attributes": True}


class RegulatoryParameterOut(BaseModel):
    id: int
    parameter_key: str
    parameter_value: str
    effective_date: str
    description: Optional[str]

    model_config = {"from_attributes": True}


class VatCodeOut(BaseModel):
    id: int
    code: str
    name: str
    vat_rate: Decimal
    vat_type: str
    vat_direction: str
    is_active: bool

    model_config = {"from_attributes": True}


class WithholdingVatCodeOut(BaseModel):
    id: int
    code: str
    name: str
    withholding_rate: Decimal
    description: Optional[str]
    is_active: bool

    model_config = {"from_attributes": True}


class StopajCodeOut(BaseModel):
    id: int
    code: str
    name: str
    stopaj_rate: Decimal
    legal_basis: Optional[str]
    is_active: bool

    model_config = {"from_attributes": True}
