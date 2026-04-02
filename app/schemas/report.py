"""Rapor parametre şemaları"""

from __future__ import annotations
from datetime import date
from typing import Optional
from pydantic import BaseModel, Field


class _BaseReportParams(BaseModel):
    company_id: int
    fiscal_year_id: int


class TrialBalanceParams(_BaseReportParams):
    start_date: date
    end_date: date
    include_zero_balance: bool = False
    account_code_like: Optional[str] = Field(None, max_length=25)


class JournalParams(_BaseReportParams):
    start_date: date
    end_date: date
    voucher_type_id: Optional[int] = None
    account_code_like: Optional[str] = Field(None, max_length=25)


class GeneralLedgerParams(_BaseReportParams):
    start_date: date
    end_date: date
    account_code_like: Optional[str] = Field(None, max_length=25, description="Örn: '100%'")


class SubLedgerParams(_BaseReportParams):
    start_date: date
    end_date: date
    current_account_id: Optional[int] = None
    only_open: bool = False


class BalanceSheetParams(_BaseReportParams):
    as_of_date: date


class IncomeStatementParams(_BaseReportParams):
    start_date: date
    end_date: date


class TaxReportParams(BaseModel):
    company_id: int
    period_from: date
    period_to: date
    threshold_tl: float = Field(5000.0, ge=0, description="BA/BS sınır tutarı (TL)")


class AgingReportParams(BaseModel):
    company_id: int
    as_of_date: date
    current_account_type_id: Optional[int] = None
