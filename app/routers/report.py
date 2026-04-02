from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.report import (
    TrialBalanceParams,
    JournalParams,
    GeneralLedgerParams,
    SubLedgerParams,
    BalanceSheetParams,
    IncomeStatementParams,
    TaxReportParams,
    AgingReportParams,
)
from app.services import report as svc

router = APIRouter(prefix="/reports", tags=["Reports"])


@router.post("/trial-balance")
def trial_balance(params: TrialBalanceParams, db: Session = Depends(get_db)):
    return svc.trial_balance(db, params)


@router.post("/journal")
def journal(params: JournalParams, db: Session = Depends(get_db)):
    return svc.journal(db, params)


@router.post("/general-ledger")
def general_ledger(params: GeneralLedgerParams, db: Session = Depends(get_db)):
    return svc.general_ledger(db, params)


@router.post("/sub-ledger")
def sub_ledger(params: SubLedgerParams, db: Session = Depends(get_db)):
    return svc.sub_ledger(db, params)


@router.post("/balance-sheet")
def balance_sheet(params: BalanceSheetParams, db: Session = Depends(get_db)):
    return svc.balance_sheet(db, params)


@router.post("/income-statement")
def income_statement(params: IncomeStatementParams, db: Session = Depends(get_db)):
    return svc.income_statement(db, params)


@router.post("/tax")
def tax_report(params: TaxReportParams, db: Session = Depends(get_db)):
    return svc.tax_report_kdv(db, params)


@router.post("/aging")
def aging(params: AgingReportParams, db: Session = Depends(get_db)):
    return svc.aging_report(db, params)
