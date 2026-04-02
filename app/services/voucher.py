"""
Yevmiye fişi servisi
§5.4 — Tüm zorunlu alanlar, denge kontrolü, sıralı yevmiye numarası
"""

from __future__ import annotations
from datetime import date
from decimal import Decimal
from typing import Any

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.schemas.voucher import VoucherCreate, VoucherApprove, VoucherReverse


def _kurus(amount: Decimal) -> int:
    """Decimal TL tutarını kuruş BIGINT'e dönüştür."""
    return int((amount * 100).to_integral_value())


def _row_to_dict(row) -> dict[str, Any]:
    return dict(row._mapping) if row else {}


def _last_insert_id(db: Session) -> int:
    dialect = db.bind.dialect.name if db.bind is not None else ""
    if dialect.startswith("mssql"):
        return int(db.execute(text("SELECT CAST(SCOPE_IDENTITY() AS INT) AS id")).fetchone().id)
    return int(db.execute(text("SELECT last_insert_rowid() AS id")).fetchone().id)


def _is_sqlite(db: Session) -> bool:
    return (db.bind.dialect.name if db.bind is not None else "") == "sqlite"


# ── Temel CRUD ────────────────────────────────────────────────────────────────

def get_voucher(db: Session, company_id: int, voucher_id: int) -> dict | None:
    v = db.execute(
        text("SELECT * FROM vouchers WHERE company_id = :cid AND id = :id"),
        {"cid": company_id, "id": voucher_id},
    ).fetchone()
    if not v:
        return None
    result = _row_to_dict(v)
    lines = db.execute(
        text("""
            SELECT vl.*, a.code AS account_code, a.name AS account_name
            FROM voucher_lines vl
            INNER JOIN accounts a ON a.id = vl.account_id
            WHERE vl.voucher_id = :vid
            ORDER BY vl.line_no
        """),
        {"vid": voucher_id},
    ).fetchall()
    result["lines"] = [_row_to_dict(ln) for ln in lines]
    # TL dönüşümü
    for key in ("total_debit_kurus", "total_credit_kurus"):
        if key in result:
            result[key.replace("_kurus", "")] = Decimal(result[key]) / 100
    return result


def list_vouchers(
    db: Session,
    company_id: int,
    fiscal_year_id: int,
    start_date: date | None = None,
    end_date: date | None = None,
    status: str | None = None,
    skip: int = 0,
    limit: int = 50,
) -> list[dict]:
    filters = [
        "v.company_id = :cid",
        "v.fiscal_year_id = :fid",
    ]
    params: dict[str, Any] = {"cid": company_id, "fid": fiscal_year_id}

    if start_date:
        filters.append("v.posting_date >= :sd")
        params["sd"] = str(start_date)
    if end_date:
        filters.append("v.posting_date <= :ed")
        params["ed"] = str(end_date)
    if status:
        filters.append("v.status = :status")
        params["status"] = status

    params["skip"] = skip
    params["limit"] = limit

    if _is_sqlite(db):
        rows = db.execute(
            text(f"""
                SELECT v.*, vt.code AS voucher_type_code, vt.name AS voucher_type_name
                FROM vouchers v
                INNER JOIN voucher_types vt ON vt.id = v.voucher_type_id
                WHERE {' AND '.join(filters)}
                ORDER BY v.posting_date, v.journal_sequence_no
                LIMIT :limit OFFSET :skip
            """),
            params,
        ).fetchall()
    else:
        rows = db.execute(
            text(f"""
                SELECT v.*, vt.code AS voucher_type_code, vt.name AS voucher_type_name
                FROM vouchers v
                INNER JOIN voucher_types vt ON vt.id = v.voucher_type_id
                WHERE {' AND '.join(filters)}
                ORDER BY v.posting_date, v.journal_sequence_no
                OFFSET :skip ROWS FETCH NEXT :limit ROWS ONLY
            """),
            params,
        ).fetchall()
    return [_row_to_dict(r) for r in rows]


def create_voucher(db: Session, data: VoucherCreate, created_by: int) -> dict:
    # Dönem kilitli mi?
    period = db.execute(
        text("SELECT is_locked, is_closed FROM fiscal_periods WHERE id = :pid"),
        {"pid": data.fiscal_period_id},
    ).fetchone()
    if period and (period.is_locked or period.is_closed):
        raise ValueError("Seçilen dönem kilitli veya kapalı; fiş girilemez.")

    # Toplam borç / alacak (kuruş)
    total_d = sum(_kurus(ln.debit_amount) for ln in data.lines)
    total_c = sum(_kurus(ln.credit_amount) for ln in data.lines)
    if total_d != total_c:
        raise ValueError(f"Fiş dengesiz: borç {total_d} ≠ alacak {total_c} kuruş")

    # Fiş tipi kodu al
    vt = db.execute(
        text("SELECT code FROM voucher_types WHERE id = :id"),
        {"id": data.voucher_type_id},
    ).fetchone()
    vt_code = vt.code if vt else "GEN"

    # Fiş numarası (YIL-TIP-SIRA)
    seq_row = db.execute(
        text("""
            SELECT COALESCE(MAX(journal_sequence_no), 0) + 1 AS next_seq
            FROM vouchers
            WHERE company_id = :cid AND fiscal_year_id = :fid
        """),
        {"cid": data.company_id, "fid": data.fiscal_year_id},
    ).fetchone()
    seq_no = seq_row.next_seq if seq_row else 1
    voucher_no = f"{data.fiscal_year_id}-{vt_code}-{seq_no:06d}"

    # Fiş başlığı INSERT
    db.execute(
        text("""
            INSERT INTO vouchers (
                company_id, fiscal_year_id, fiscal_period_id, voucher_type_id,
                journal_sequence_no, voucher_no,
                document_date, posting_date, description,
                source_document_no,
                module_source, branch_id,
                total_debit_kurus, total_credit_kurus,
                status, created_by
            ) VALUES (
                :cid, :fid, :pid, :vtid,
                :seq, :vno,
                :docdt, :postdt, :desc,
                :srcdocno,
                :modsrc, :branchid,
                :td, :tc,
                'TASLAK', :createdby
            )
        """),
        {
            "cid": data.company_id, "fid": data.fiscal_year_id,
            "pid": data.fiscal_period_id, "vtid": data.voucher_type_id,
            "seq": seq_no, "vno": voucher_no,
            "docdt": str(data.document_date), "postdt": str(data.posting_date),
            "desc": data.description,
            "srcdocno": data.source_document_no,
            "modsrc": data.module_source, "branchid": data.branch_id,
            "td": total_d, "tc": total_c,
            "createdby": created_by,
        },
    )
    db.flush()
    voucher_id = _last_insert_id(db)

    # Satırları ekle
    for ln in data.lines:
        db.execute(
            text("""
                INSERT INTO voucher_lines (
                    voucher_id, line_no, company_id, branch_id, account_id, description,
                    debit_kurus, credit_kurus,
                    currency_code, foreign_amount, exchange_rate,
                    current_account_id, cost_center_id, project_id,
                    vat_code_id, vat_base_kurus, vat_amount_kurus,
                    withholding_code_id, stopaj_code_id,
                    due_date
                ) VALUES (
                    :vid, :lno, :cid, :brid, :aid, :desc,
                    :dk, :ck,
                    :cur, :fa, :er,
                    :caid, :ccid, :prid,
                    :vcid, :vbk, :vak,
                    :wcid, :scid,
                    :due
                )
            """),
            {
                "vid": voucher_id, "lno": ln.line_no, "aid": ln.account_id,
                "cid": data.company_id, "brid": data.branch_id,
                "desc": ln.description,
                "dk": _kurus(ln.debit_amount), "ck": _kurus(ln.credit_amount),
                "cur": ln.currency_code, "fa": str(ln.foreign_amount) if ln.foreign_amount else None,
                "er": str(ln.exchange_rate) if ln.exchange_rate else None,
                "caid": ln.current_account_id, "ccid": ln.cost_center_id, "prid": ln.project_id,
                "vcid": ln.vat_code_id,
                "vbk": _kurus(ln.vat_base_amount) if ln.vat_base_amount else 0,
                "vak": _kurus(ln.vat_amount) if ln.vat_amount else 0,
                "wcid": ln.withholding_vat_code_id,
                "scid": ln.stopaj_code_id,
                "due": str(ln.due_date) if ln.due_date else None,
            },
        )

    db.flush()
    return get_voucher(db, data.company_id, voucher_id)


def approve_voucher(db: Session, data: VoucherApprove) -> dict | None:
    v = db.execute(
        text("SELECT company_id, status FROM vouchers WHERE id = :id"),
        {"id": data.voucher_id},
    ).fetchone()
    if not v:
        raise ValueError("Fiş bulunamadı")
    if v.status != "TASLAK":
        raise ValueError(f"Yalnızca TASLAK fişler onaylanabilir (mevcut: {v.status})")

    db.execute(
        text("""
            UPDATE vouchers
            SET status = 'ONAYLANDI', approved_by = :ab, approved_at = CURRENT_TIMESTAMP
            WHERE id = :id
        """),
        {"ab": data.approved_by, "id": data.voucher_id},
    )
    db.flush()
    return get_voucher(db, v.company_id, data.voucher_id)


def cancel_voucher(db: Session, company_id: int, voucher_id: int, cancelled_by: int) -> dict | None:
    v = db.execute(
        text("SELECT status FROM vouchers WHERE company_id = :cid AND id = :id"),
        {"cid": company_id, "id": voucher_id},
    ).fetchone()
    if not v:
        raise ValueError("Fiş bulunamadı")
    if v.status == "ONAYLANDI":
        raise ValueError("Onaylı fiş iptal edilemez; ters kayıt oluşturun.")

    db.execute(
        text("""
            UPDATE vouchers SET status = 'IPTAL', updated_by = :by
            WHERE company_id = :cid AND id = :id
        """),
        {"by": cancelled_by, "cid": company_id, "id": voucher_id},
    )
    db.flush()
    return get_voucher(db, company_id, voucher_id)


def reverse_voucher(db: Session, data: VoucherReverse) -> dict:
    original = get_voucher(db, db.execute(
        text("SELECT company_id FROM vouchers WHERE id = :id"),
        {"id": data.voucher_id},
    ).fetchone().company_id, data.voucher_id)

    if not original:
        raise ValueError("Orijinal fiş bulunamadı")
    if original["status"] != "ONAYLANDI":
        raise ValueError("Yalnızca onaylı fişlerin ters kaydı oluşturulabilir")
    if original.get("reversed_by_id"):
        raise ValueError("Bu fiş zaten ters kaydedilmiş")

    # Ters fiş satırları (borç↔alacak yer değiştirir)
    from app.schemas.voucher import VoucherCreate, VoucherLineIn
    reverse_lines = []
    for ln in original["lines"]:
        reverse_lines.append(VoucherLineIn(
            line_no=ln["line_no"],
            account_id=ln["account_id"],
            description=ln.get("description"),
            debit_amount=Decimal(ln.get("credit_kurus", 0)) / 100,
            credit_amount=Decimal(ln.get("debit_kurus", 0)) / 100,
            currency_code=ln.get("currency_code"),
            foreign_amount=Decimal(ln["foreign_amount"]) if ln.get("foreign_amount") else None,
            exchange_rate=Decimal(ln["exchange_rate"]) if ln.get("exchange_rate") else None,
            current_account_id=ln.get("current_account_id"),
            cost_center_id=ln.get("cost_center_id"),
            project_id=ln.get("project_id"),
        ))

    reverse_data = VoucherCreate(
        company_id=original["company_id"],
        fiscal_year_id=original["fiscal_year_id"],
        fiscal_period_id=original["fiscal_period_id"],
        voucher_type_id=original["voucher_type_id"],
        document_date=data.reverse_date,
        posting_date=data.reverse_date,
        description=data.reverse_description or f"TERS KAYIT: {original['voucher_no']}",
        module_source="REVERSE",
        lines=reverse_lines,
    )

    new_voucher = create_voucher(db, reverse_data, data.reversed_by)

    # Çapraz bağlantı
    db.execute(
        text("UPDATE vouchers SET reverse_of_id = :orig WHERE id = :new_id"),
        {"orig": data.voucher_id, "new_id": new_voucher["id"]},
    )
    db.execute(
        text("UPDATE vouchers SET reversed_by_id = :new_id WHERE id = :orig"),
        {"new_id": new_voucher["id"], "orig": data.voucher_id},
    )
    db.flush()
    return new_voucher
