-- ============================================================
-- YEVMİYE DEFTERİ
-- Parametreler: @company_id, @fiscal_year_id, @start_date, @end_date
-- §21.1: yevmiye defteri, fiş bazlı, sıra numarası korunur
-- ============================================================

DECLARE
    @company_id     INT  = :company_id,
    @fiscal_year_id INT  = :fiscal_year_id,
    @start_date     DATE = :start_date,
    @end_date       DATE = :end_date;

SELECT
    v.journal_sequence_no,
    v.voucher_no,
    vt.code                                 AS voucher_type_code,
    vt.name                                 AS voucher_type_name,
    v.document_date,
    v.posting_date,
    fp.period_no,
    vl.line_no,
    a.code                                  AS account_code,
    a.name                                  AS account_name,
    COALESCE(vl.description, v.description) AS line_description,
    v.source_document_no,
    v.module_source,
    CAST(vl.debit_kurus  AS DECIMAL(18,2)) / 100  AS debit_amount,
    CAST(vl.credit_kurus AS DECIMAL(18,2)) / 100  AS credit_amount,
    vl.currency_code,
    vl.foreign_amount,
    vl.exchange_rate,
    ca.code                                 AS current_account_code,
    ca.title                                AS current_account_title,
    cc.code                                 AS cost_center_code,
    pr.code                                 AS project_code,
    vc.code                                 AS vat_code,
    CAST(vl.vat_base_kurus   AS DECIMAL(18,2)) / 100  AS vat_base,
    CAST(vl.vat_amount_kurus AS DECIMAL(18,2)) / 100  AS vat_amount,
    v.status,
    v.approved_by,
    v.approved_at
FROM dbo.voucher_lines          vl
INNER JOIN dbo.vouchers         v   ON v.id  = vl.voucher_id
INNER JOIN dbo.voucher_types    vt  ON vt.id = v.voucher_type_id
INNER JOIN dbo.accounts         a   ON a.id  = vl.account_id
INNER JOIN dbo.fiscal_periods   fp  ON fp.id = v.fiscal_period_id
LEFT  JOIN dbo.current_accounts ca  ON ca.id = vl.current_account_id
LEFT  JOIN dbo.cost_centers     cc  ON cc.id = vl.cost_center_id
LEFT  JOIN dbo.projects         pr  ON pr.id = vl.project_id
LEFT  JOIN dbo.vat_codes        vc  ON vc.id = vl.vat_code_id
WHERE v.company_id      = @company_id
  AND v.fiscal_year_id  = @fiscal_year_id
  AND v.posting_date BETWEEN @start_date AND @end_date
  AND v.status         <> N'IPTAL'
ORDER BY
    v.posting_date,
    v.journal_sequence_no,
    vl.line_no;
