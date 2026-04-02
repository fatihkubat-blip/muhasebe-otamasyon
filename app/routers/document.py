from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.document import DocumentCreate, DocumentUpdate

router = APIRouter(prefix="/documents", tags=["Document"])


def _last_insert_id(db: Session) -> int:
    dialect = db.bind.dialect.name if db.bind is not None else ""
    if dialect.startswith("mssql"):
        return int(db.execute(text("SELECT CAST(SCOPE_IDENTITY() AS INT) AS id")).fetchone().id)
    return int(db.execute(text("SELECT last_insert_rowid() AS id")).fetchone().id)


@router.post("", status_code=201)
def create_document(payload: DocumentCreate, db: Session = Depends(get_db)):
    # Header insert
    db.execute(
        text("""
            INSERT INTO document_headers (
                company_id, document_type_id, fiscal_year_id, fiscal_period_id,
                current_account_id, branch_id,
                document_no, document_date, due_date,
                currency_code, exchange_rate,
                subtotal_kurus, discount_kurus, vat_base_kurus, vat_amount_kurus, tevkifat_kurus, total_kurus,
                description, e_document_uuid,
                is_accounted, is_cancelled
            ) VALUES (
                :company_id, :document_type_id, :fiscal_year_id, :fiscal_period_id,
                :current_account_id, :branch_id,
                :document_no, :document_date, :due_date,
                :currency_code, :exchange_rate,
                0, 0, 0, 0, 0, 0,
                :description, :e_document_uuid,
                0, 0
            )
        """),
        {
            **payload.model_dump(exclude={"lines"}),
            "exchange_rate": str(payload.exchange_rate),
        },
    )
    doc_id = _last_insert_id(db)

    subtotal = 0
    total_vat = 0
    total_withholding = 0

    for ln in payload.lines:
        line_net = (ln.quantity * ln.unit_price) * (1 - (ln.discount_rate / 100))
        line_vat = Decimal("0")
        line_total = line_net + line_vat

        net_kurus = int(line_net * 100)
        vat_kurus = int(line_vat * 100)
        total_kurus = int(line_total * 100)

        subtotal += net_kurus
        total_vat += vat_kurus

        db.execute(
            text("""
                INSERT INTO document_lines (
                    document_id, line_no,
                    inventory_item_id, service_item_id,
                    description, quantity, unit_code,
                    unit_price, discount_rate, discount_amount_kurus,
                    vat_code_id, vat_base_kurus, vat_amount_kurus,
                    withholding_code_id, tevkifat_kurus,
                    stopaj_code_id, stopaj_kurus,
                    line_total_kurus, warehouse_id,
                    cost_center_id, project_id
                ) VALUES (
                    :hid, :line_no,
                    :inventory_item_id, :service_item_id,
                    :description, :quantity, :unit_code,
                    :unit_price, :discount_rate, :discount_amount_kurus,
                    :vat_code_id, :vat_base_kurus, :vat_amount_kurus,
                    :withholding_code_id, :tevkifat_kurus,
                    :stopaj_code_id, :stopaj_kurus,
                    :line_total_kurus, :warehouse_id,
                    :cost_center_id, :project_id
                )
            """),
            {
                "hid": doc_id,
                "line_no": ln.line_no,
                "inventory_item_id": ln.inventory_item_id,
                "service_item_id": ln.service_item_id,
                "description": ln.description,
                "quantity": float(ln.quantity),
                "unit_code": ln.unit_code,
                "unit_price": float(ln.unit_price),
                "discount_rate": float(ln.discount_rate),
                "discount_amount_kurus": int((ln.quantity * ln.unit_price * (ln.discount_rate / 100)) * 100),
                "vat_code_id": ln.vat_code_id,
                "vat_base_kurus": net_kurus,
                "vat_amount_kurus": vat_kurus,
                "withholding_code_id": ln.withholding_code_id,
                "tevkifat_kurus": 0,
                "stopaj_code_id": ln.stopaj_code_id,
                "stopaj_kurus": 0,
                "line_total_kurus": total_kurus,
                "warehouse_id": ln.warehouse_id,
                "cost_center_id": ln.cost_center_id,
                "project_id": ln.project_id,
            },
        )

    total = subtotal + total_vat - total_withholding

    db.execute(
        text("""
            UPDATE document_headers
            SET subtotal_kurus = :subtotal,
                vat_base_kurus = :subtotal,
                vat_amount_kurus = :vat,
                tevkifat_kurus = :w,
                total_kurus = :total
            WHERE id = :id
        """),
        {"subtotal": subtotal, "vat": total_vat, "w": total_withholding, "total": total, "id": doc_id},
    )

    db.commit()
    row = db.execute(text("SELECT * FROM document_headers WHERE id = :id"), {"id": doc_id}).fetchone()
    return dict(row._mapping)


@router.get("")
def list_documents(company_id: int = Query(...), db: Session = Depends(get_db)):
    rows = db.execute(
        text("SELECT * FROM document_headers WHERE company_id = :cid ORDER BY document_date DESC, id DESC"),
        {"cid": company_id},
    ).fetchall()
    return [dict(r._mapping) for r in rows]


@router.patch("/{document_id}")
def update_document(document_id: int, payload: DocumentUpdate, db: Session = Depends(get_db)):
    changes = payload.model_dump(exclude_none=True)
    if not changes:
        row = db.execute(text("SELECT * FROM document_headers WHERE id = :id"), {"id": document_id}).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Belge bulunamadı")
        return dict(row._mapping)

    set_clause = ", ".join(f"{k} = :{k}" for k in changes)
    changes["id"] = document_id
    db.execute(text(f"UPDATE document_headers SET {set_clause} WHERE id = :id"), changes)
    db.commit()

    row = db.execute(text("SELECT * FROM document_headers WHERE id = :id"), {"id": document_id}).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Belge bulunamadı")
    return dict(row._mapping)
