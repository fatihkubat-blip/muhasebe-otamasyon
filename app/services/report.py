"""
Rapor servisi — SQL dosyalarını okur ve parametrelerle çalıştırır
§21 — Tüm standart raporlar
"""

from __future__ import annotations
from pathlib import Path
from typing import Any

from sqlalchemy import text
from sqlalchemy.orm import Session

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

_SQL_DIR = Path(__file__).resolve().parent.parent.parent / "sql" / "reports"


def _load_sql(filename: str) -> str:
    return (_SQL_DIR / filename).read_text(encoding="utf-8")


def _rows_to_list(rows) -> list[dict[str, Any]]:
    return [dict(r._mapping) for r in rows]


def _is_sqlite(db: Session) -> bool:
    return (db.bind.dialect.name if db.bind is not None else "") == "sqlite"


def trial_balance(db: Session, params: TrialBalanceParams) -> list[dict]:
    if _is_sqlite(db):
        rows = db.execute(
            text(
                """
                WITH base AS (
                    SELECT
                        a.code AS account_code,
                        a.name AS account_name,
                        a.account_class,
                        a.account_type,
                        a.normal_balance,
                        COALESCE(SUM(CASE WHEN v.posting_date < :start_date THEN vl.debit_kurus ELSE 0 END), 0) AS opening_debit_kurus,
                        COALESCE(SUM(CASE WHEN v.posting_date < :start_date THEN vl.credit_kurus ELSE 0 END), 0) AS opening_credit_kurus,
                        COALESCE(SUM(CASE WHEN v.posting_date BETWEEN :start_date AND :end_date THEN vl.debit_kurus ELSE 0 END), 0) AS period_debit_kurus,
                        COALESCE(SUM(CASE WHEN v.posting_date BETWEEN :start_date AND :end_date THEN vl.credit_kurus ELSE 0 END), 0) AS period_credit_kurus
                    FROM accounts a
                    LEFT JOIN voucher_lines vl ON vl.account_id = a.id
                    LEFT JOIN vouchers v ON v.id = vl.voucher_id
                        AND v.company_id = :company_id
                        AND v.fiscal_year_id = :fiscal_year_id
                        AND v.status <> 'IPTAL'
                        AND v.posting_date <= :end_date
                    WHERE a.company_id = :company_id
                      AND a.is_active = 1
                    GROUP BY a.code, a.name, a.account_class, a.account_type, a.normal_balance
                )
                SELECT
                    account_code,
                    account_name,
                    account_class,
                    account_type,
                    normal_balance,
                    CASE
                        WHEN (opening_debit_kurus - opening_credit_kurus) > 0
                        THEN CAST((opening_debit_kurus - opening_credit_kurus) AS DECIMAL(18,2))/100
                        ELSE 0
                    END AS opening_debit,
                    CASE
                        WHEN (opening_debit_kurus - opening_credit_kurus) < 0
                        THEN CAST(-(opening_debit_kurus - opening_credit_kurus) AS DECIMAL(18,2))/100
                        ELSE 0
                    END AS opening_credit,
                    CAST(period_debit_kurus AS DECIMAL(18,2))/100 AS period_debit,
                    CAST(period_credit_kurus AS DECIMAL(18,2))/100 AS period_credit,
                    CASE
                        WHEN ((opening_debit_kurus - opening_credit_kurus) + (period_debit_kurus - period_credit_kurus)) > 0
                        THEN CAST(((opening_debit_kurus - opening_credit_kurus) + (period_debit_kurus - period_credit_kurus)) AS DECIMAL(18,2))/100
                        ELSE 0
                    END AS closing_debit,
                    CASE
                        WHEN ((opening_debit_kurus - opening_credit_kurus) + (period_debit_kurus - period_credit_kurus)) < 0
                        THEN CAST(-((opening_debit_kurus - opening_credit_kurus) + (period_debit_kurus - period_credit_kurus)) AS DECIMAL(18,2))/100
                        ELSE 0
                    END AS closing_credit
                FROM base
                ORDER BY account_code
                """
            ),
            {
                "company_id": params.company_id,
                "fiscal_year_id": params.fiscal_year_id,
                "start_date": str(params.start_date),
                "end_date": str(params.end_date),
            },
        ).fetchall()
        result = _rows_to_list(rows)
        if not params.include_zero_balance:
            result = [r for r in result if r.get("period_debit") or r.get("period_credit")
                      or r.get("closing_debit") or r.get("closing_credit")]
        if params.account_code_like:
            like = params.account_code_like.replace("%", "").lower()
            result = [r for r in result if r.get("account_code", "").lower().startswith(like.rstrip("%"))]
        return result

    sql = _load_sql("trial_balance.sql")
    rows = db.execute(
        text(sql),
        {
            "company_id": params.company_id,
            "fiscal_year_id": params.fiscal_year_id,
            "start_date": str(params.start_date),
            "end_date": str(params.end_date),
        },
    ).fetchall()
    result = _rows_to_list(rows)
    if not params.include_zero_balance:
        result = [r for r in result if r.get("period_debit") or r.get("period_credit")
                  or r.get("closing_debit") or r.get("closing_credit")]
    if params.account_code_like:
        like = params.account_code_like.replace("%", "").lower()
        result = [r for r in result if r.get("account_code", "").lower().startswith(like.rstrip("%"))]
    return result


def journal(db: Session, params: JournalParams) -> list[dict]:
    if _is_sqlite(db):
        rows = db.execute(
            text(
                """
                SELECT
                    v.id AS voucher_id,
                    v.voucher_no,
                    v.journal_sequence_no,
                    v.posting_date,
                    v.document_date,
                    vt.code AS voucher_type_code,
                    vt.name AS voucher_type_name,
                    vl.line_no,
                    a.code AS account_code,
                    a.name AS account_name,
                    vl.description,
                    CAST(vl.debit_kurus AS DECIMAL(18,2))/100 AS debit,
                    CAST(vl.credit_kurus AS DECIMAL(18,2))/100 AS credit,
                    ca.code AS current_account_code,
                    ca.title AS current_account_title
                FROM vouchers v
                INNER JOIN voucher_types vt ON vt.id = v.voucher_type_id
                INNER JOIN voucher_lines vl ON vl.voucher_id = v.id
                INNER JOIN accounts a ON a.id = vl.account_id
                LEFT JOIN current_accounts ca ON ca.id = vl.current_account_id
                WHERE v.company_id = :company_id
                  AND v.fiscal_year_id = :fiscal_year_id
                  AND v.status <> 'IPTAL'
                  AND v.posting_date BETWEEN :start_date AND :end_date
                ORDER BY v.posting_date, v.journal_sequence_no, vl.line_no
                """
            ),
            {
                "company_id": params.company_id,
                "fiscal_year_id": params.fiscal_year_id,
                "start_date": str(params.start_date),
                "end_date": str(params.end_date),
            },
        ).fetchall()
        result = _rows_to_list(rows)
        if params.voucher_type_id:
            result = [r for r in result if r.get("voucher_type_id") == params.voucher_type_id]
        return result

    sql = _load_sql("journal.sql")
    rows = db.execute(
        text(sql),
        {
            "company_id": params.company_id,
            "fiscal_year_id": params.fiscal_year_id,
            "start_date": str(params.start_date),
            "end_date": str(params.end_date),
        },
    ).fetchall()
    result = _rows_to_list(rows)
    if params.voucher_type_id:
        # İstemci tarafı filtre (SQL'e ek parametre eklemeden hafif filtreleme)
        result = [r for r in result if r.get("voucher_type_id") == params.voucher_type_id]
    return result


def general_ledger(db: Session, params: GeneralLedgerParams) -> list[dict]:
    if _is_sqlite(db):
        rows = db.execute(
            text(
                """
                WITH opening AS (
                    SELECT
                        vl.account_id,
                        COALESCE(SUM(vl.debit_kurus - vl.credit_kurus), 0) AS opening_kurus
                    FROM voucher_lines vl
                    INNER JOIN vouchers v ON v.id = vl.voucher_id
                    WHERE v.company_id = :company_id
                      AND v.fiscal_year_id = :fiscal_year_id
                      AND v.status <> 'IPTAL'
                      AND v.posting_date < :start_date
                    GROUP BY vl.account_id
                )
                SELECT
                    a.code AS account_code,
                    a.name AS account_name,
                    v.id AS voucher_id,
                    v.voucher_no,
                    v.posting_date,
                    vl.line_no,
                    vl.description,
                    CAST(vl.debit_kurus AS DECIMAL(18,2))/100 AS debit,
                    CAST(vl.credit_kurus AS DECIMAL(18,2))/100 AS credit,
                    CAST(COALESCE(o.opening_kurus, 0) AS DECIMAL(18,2))/100 AS opening_balance
                FROM voucher_lines vl
                INNER JOIN vouchers v ON v.id = vl.voucher_id
                INNER JOIN accounts a ON a.id = vl.account_id
                LEFT JOIN opening o ON o.account_id = vl.account_id
                WHERE v.company_id = :company_id
                  AND v.fiscal_year_id = :fiscal_year_id
                  AND v.status <> 'IPTAL'
                  AND v.posting_date BETWEEN :start_date AND :end_date
                  AND (:account_code_like IS NULL OR a.code LIKE :account_code_like)
                ORDER BY a.code, v.posting_date, v.journal_sequence_no, vl.line_no
                """
            ),
            {
                "company_id": params.company_id,
                "fiscal_year_id": params.fiscal_year_id,
                "start_date": str(params.start_date),
                "end_date": str(params.end_date),
                "account_code_like": params.account_code_like,
            },
        ).fetchall()
        return _rows_to_list(rows)

    sql = _load_sql("general_ledger.sql")
    rows = db.execute(
        text(sql),
        {
            "company_id": params.company_id,
            "fiscal_year_id": params.fiscal_year_id,
            "start_date": str(params.start_date),
            "end_date": str(params.end_date),
            "account_code_like": params.account_code_like,
        },
    ).fetchall()
    return _rows_to_list(rows)


def sub_ledger(db: Session, params: SubLedgerParams) -> list[dict]:
    if _is_sqlite(db):
        rows = db.execute(
            text(
                """
                SELECT
                    ca.code AS current_account_code,
                    ca.title AS current_account_title,
                    v.id AS voucher_id,
                    v.voucher_no,
                    v.posting_date,
                    vl.line_no,
                    COALESCE(vl.description, v.description) AS description,
                    CAST(vl.debit_kurus AS DECIMAL(18,2))/100 AS debit,
                    CAST(vl.credit_kurus AS DECIMAL(18,2))/100 AS credit,
                    CAST((vl.debit_kurus - vl.credit_kurus) AS DECIMAL(18,2))/100 AS net_balance
                FROM voucher_lines vl
                INNER JOIN vouchers v ON v.id = vl.voucher_id
                INNER JOIN current_accounts ca ON ca.id = vl.current_account_id
                WHERE v.company_id = :company_id
                  AND v.fiscal_year_id = :fiscal_year_id
                  AND v.status <> 'IPTAL'
                  AND v.posting_date BETWEEN :start_date AND :end_date
                  AND (:current_account_id IS NULL OR vl.current_account_id = :current_account_id)
                  AND (:only_open = 0 OR (vl.debit_kurus - vl.credit_kurus) <> 0)
                ORDER BY ca.code, v.posting_date, v.journal_sequence_no, vl.line_no
                """
            ),
            {
                "company_id": params.company_id,
                "fiscal_year_id": params.fiscal_year_id,
                "start_date": str(params.start_date),
                "end_date": str(params.end_date),
                "current_account_id": params.current_account_id,
                "only_open": 1 if params.only_open else 0,
            },
        ).fetchall()
        return _rows_to_list(rows)

    sql = _load_sql("sub_ledger.sql")
    rows = db.execute(
        text(sql),
        {
            "company_id": params.company_id,
            "fiscal_year_id": params.fiscal_year_id,
            "start_date": str(params.start_date),
            "end_date": str(params.end_date),
            "current_account_id": params.current_account_id,
            "only_open": 1 if params.only_open else 0,
        },
    ).fetchall()
    return _rows_to_list(rows)


def balance_sheet(db: Session, params: BalanceSheetParams) -> list[dict]:
    if _is_sqlite(db):
        rows = db.execute(
            text(
                """
                SELECT
                    a.account_type,
                    a.code AS account_code,
                    a.name AS account_name,
                    CAST(SUM(vl.debit_kurus - vl.credit_kurus) AS DECIMAL(18,2))/100 AS balance_tl
                FROM voucher_lines vl
                INNER JOIN vouchers v ON v.id = vl.voucher_id
                INNER JOIN accounts a ON a.id = vl.account_id
                WHERE v.company_id = :company_id
                  AND v.fiscal_year_id = :fiscal_year_id
                  AND v.status <> 'IPTAL'
                  AND v.posting_date <= :as_of_date
                  AND a.account_type IN ('asset','liability','equity')
                GROUP BY a.account_type, a.code, a.name
                ORDER BY a.code
                """
            ),
            {
                "company_id": params.company_id,
                "fiscal_year_id": params.fiscal_year_id,
                "as_of_date": str(params.as_of_date),
            },
        ).fetchall()
        return _rows_to_list(rows)

    sql = _load_sql("balance_sheet.sql")
    rows = db.execute(
        text(sql),
        {
            "company_id": params.company_id,
            "fiscal_year_id": params.fiscal_year_id,
            "as_of_date": str(params.as_of_date),
        },
    ).fetchall()
    return _rows_to_list(rows)


def income_statement(db: Session, params: IncomeStatementParams) -> list[dict]:
    if _is_sqlite(db):
        rows = db.execute(
            text(
                """
                SELECT
                    a.account_type,
                    a.code AS account_code,
                    a.name AS account_name,
                    CAST(SUM(vl.debit_kurus) AS DECIMAL(18,2))/100 AS debit_tl,
                    CAST(SUM(vl.credit_kurus) AS DECIMAL(18,2))/100 AS credit_tl,
                    CAST(SUM(vl.credit_kurus - vl.debit_kurus) AS DECIMAL(18,2))/100 AS net_tl
                FROM voucher_lines vl
                INNER JOIN vouchers v ON v.id = vl.voucher_id
                INNER JOIN accounts a ON a.id = vl.account_id
                WHERE v.company_id = :company_id
                  AND v.fiscal_year_id = :fiscal_year_id
                  AND v.status <> 'IPTAL'
                  AND v.posting_date BETWEEN :start_date AND :end_date
                  AND a.account_type IN ('revenue','expense')
                GROUP BY a.account_type, a.code, a.name
                ORDER BY a.code
                """
            ),
            {
                "company_id": params.company_id,
                "fiscal_year_id": params.fiscal_year_id,
                "start_date": str(params.start_date),
                "end_date": str(params.end_date),
            },
        ).fetchall()
        return _rows_to_list(rows)

    sql = _load_sql("income_statement.sql")
    rows = db.execute(
        text(sql),
        {
            "company_id": params.company_id,
            "fiscal_year_id": params.fiscal_year_id,
            "start_date": str(params.start_date),
            "end_date": str(params.end_date),
        },
    ).fetchall()
    return _rows_to_list(rows)


def tax_report_kdv(db: Session, params: TaxReportParams) -> dict:
    bind = {
        "company_id": params.company_id,
        "period_from": str(params.period_from),
        "period_to": str(params.period_to),
        "threshold_kurus": int(params.threshold_tl * 100),
    }

    sales = db.execute(
        text("""
            SELECT vc.code AS vat_code, vc.name AS vat_code_name, vc.vat_rate,
                   CAST(SUM(vl.vat_base_kurus) AS DECIMAL(18,2))/100 AS matrah,
                   CAST(SUM(vl.vat_amount_kurus) AS DECIMAL(18,2))/100 AS kdv_tutari
            FROM voucher_lines vl
            INNER JOIN vouchers v ON v.id = vl.voucher_id
            INNER JOIN vat_codes vc ON vc.id = vl.vat_code_id
            WHERE v.company_id = :company_id
              AND v.posting_date BETWEEN :period_from AND :period_to
              AND v.status <> 'IPTAL'
              AND vc.vat_direction = 'SATIS'
            GROUP BY vc.code, vc.name, vc.vat_rate
            ORDER BY vc.vat_rate DESC, vc.code
        """),
        bind,
    ).fetchall()

    purchase = db.execute(
        text("""
            SELECT vc.code AS vat_code, vc.name AS vat_code_name, vc.vat_rate,
                   CAST(SUM(vl.vat_base_kurus) AS DECIMAL(18,2))/100 AS matrah,
                   CAST(SUM(vl.vat_amount_kurus) AS DECIMAL(18,2))/100 AS kdv_tutari
            FROM voucher_lines vl
            INNER JOIN vouchers v ON v.id = vl.voucher_id
            INNER JOIN vat_codes vc ON vc.id = vl.vat_code_id
            WHERE v.company_id = :company_id
              AND v.posting_date BETWEEN :period_from AND :period_to
              AND v.status <> 'IPTAL'
              AND vc.vat_direction = 'ALIS'
            GROUP BY vc.code, vc.name, vc.vat_rate
            ORDER BY vc.vat_rate DESC, vc.code
        """),
        bind,
    ).fetchall()

    if _is_sqlite(db):
        ba_bs_sql = text(
            """
            SELECT
                CAST(strftime('%Y', dh.document_date) AS INTEGER) AS yil,
                CAST(strftime('%m', dh.document_date) AS INTEGER) AS ay,
                dt.direction,
                ca.code AS current_account_code,
                ca.title AS current_account_title,
                CAST(SUM(dl.line_total_kurus) AS DECIMAL(18,2))/100 AS tutar_tl,
                COUNT(DISTINCT dh.id) AS belge_sayisi
            FROM document_headers dh
            INNER JOIN document_types dt ON dt.id = dh.document_type_id
            INNER JOIN document_lines dl ON dl.document_id = dh.id
            INNER JOIN current_accounts ca ON ca.id = dh.current_account_id
            WHERE dh.company_id = :company_id
              AND dh.document_date BETWEEN :period_from AND :period_to
              AND dh.is_cancelled = 0
              AND dt.direction IN ('ALIS','SATIS')
            GROUP BY strftime('%Y', dh.document_date), strftime('%m', dh.document_date), dt.direction, ca.code, ca.title
            HAVING SUM(dl.line_total_kurus) >= :threshold_kurus
            ORDER BY yil, ay, dt.direction, ca.code
            """
        )
    else:
        ba_bs_sql = text(
            """
            SELECT YEAR(dh.document_date) AS yil, MONTH(dh.document_date) AS ay,
                   dt.direction, ca.code AS current_account_code, ca.title AS current_account_title,
                   CAST(SUM(dl.line_total_kurus) AS DECIMAL(18,2))/100 AS tutar_tl,
                   COUNT(DISTINCT dh.id) AS belge_sayisi
            FROM document_headers dh
            INNER JOIN document_types dt ON dt.id = dh.document_type_id
            INNER JOIN document_lines dl ON dl.document_id = dh.id
            INNER JOIN current_accounts ca ON ca.id = dh.current_account_id
            WHERE dh.company_id = :company_id
              AND dh.document_date BETWEEN :period_from AND :period_to
              AND dh.is_cancelled = 0
              AND dt.direction IN ('ALIS','SATIS')
            GROUP BY YEAR(dh.document_date), MONTH(dh.document_date), dt.direction, ca.code, ca.title
            HAVING SUM(dl.line_total_kurus) >= :threshold_kurus
            ORDER BY yil, ay, dt.direction, ca.code
            """
        )

    ba_bs = db.execute(ba_bs_sql, bind).fetchall()

    return {
        "kdv_sales": _rows_to_list(sales),
        "kdv_purchase": _rows_to_list(purchase),
        "ba_bs": _rows_to_list(ba_bs),
    }


def aging_report(db: Session, params: AgingReportParams) -> list[dict]:
    bind = {
        "company_id": params.company_id,
        "as_of_date": str(params.as_of_date),
        "current_account_type_id": params.current_account_type_id,
    }

    if _is_sqlite(db):
        rows = db.execute(
            text(
                """
                WITH open_lines AS (
                    SELECT
                        ca.code AS current_account_code,
                        ca.title AS current_account_title,
                        cat.name AS current_account_type,
                        ca.tax_number,
                        ca.city,
                        v.voucher_no,
                        vt.code AS voucher_type_code,
                        v.document_date,
                        v.posting_date,
                        v.source_document_no,
                        COALESCE(vl.description, v.description) AS line_description,
                        vl.due_date,
                        (vl.debit_kurus - vl.credit_kurus) AS net_kurus,
                        vl.currency_code,
                        vl.foreign_amount,
                        CAST(
                            julianday(:as_of_date) - julianday(COALESCE(vl.due_date, v.posting_date))
                            AS INTEGER
                        ) AS age_days
                    FROM voucher_lines vl
                    INNER JOIN vouchers v ON v.id = vl.voucher_id
                    INNER JOIN voucher_types vt ON vt.id = v.voucher_type_id
                    INNER JOIN current_accounts ca ON ca.id = vl.current_account_id
                    INNER JOIN current_account_types cat ON cat.id = ca.type_id
                    WHERE v.company_id = :company_id
                      AND v.posting_date <= :as_of_date
                      AND v.status <> 'IPTAL'
                      AND (:current_account_type_id IS NULL OR ca.type_id = :current_account_type_id)
                ),
                aged AS (
                    SELECT
                        o.*,
                        CASE
                            WHEN o.age_days < 0 THEN 'VADESI GELMEMIS'
                            WHEN o.age_days <= 30 THEN '0-30 GUN'
                            WHEN o.age_days <= 60 THEN '31-60 GUN'
                            WHEN o.age_days <= 90 THEN '61-90 GUN'
                            WHEN o.age_days <= 120 THEN '91-120 GUN'
                            ELSE '120+ GUN'
                        END AS age_bucket,
                        CASE
                            WHEN o.age_days < 0 THEN 0
                            WHEN o.age_days <= 30 THEN 1
                            WHEN o.age_days <= 60 THEN 2
                            WHEN o.age_days <= 90 THEN 3
                            WHEN o.age_days <= 120 THEN 4
                            ELSE 5
                        END AS age_bucket_sort
                    FROM open_lines o
                    WHERE o.net_kurus <> 0
                )
                SELECT
                    current_account_code,
                    current_account_title,
                    current_account_type,
                    tax_number,
                    city,
                    voucher_no,
                    voucher_type_code,
                    document_date,
                    posting_date,
                    source_document_no,
                    line_description,
                    due_date,
                    net_kurus,
                    CAST(net_kurus AS DECIMAL(18,2)) / 100 AS net_tl,
                    currency_code,
                    foreign_amount,
                    age_days,
                    age_bucket,
                    age_bucket_sort
                FROM aged
                ORDER BY current_account_code, age_bucket_sort, due_date, voucher_no
                """
            ),
            bind,
        ).fetchall()
    else:
        sql = _load_sql("aging_report.sql")
        rows = db.execute(text(sql), bind).fetchall()

    return _rows_to_list(rows)
