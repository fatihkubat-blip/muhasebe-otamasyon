-- ============================================================
-- V009: Raporlama View'ları
-- Şartname §21 (Rapor Motoru): yevmiye, muavin, büyük defter,
-- mizan, bilanço veri grubu, gelir tablosu veri grubu,
-- KDV özet, cari yaşlandırma, sabit kıymet listesi
-- ============================================================

SET NOCOUNT ON;
GO

-- --------------------------------------------------------
-- VW: Yevmiye Defteri (vw_journal)
-- --------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_journal
AS
SELECT
    v.company_id,
    v.fiscal_year_id,
    fy.fiscal_year,
    v.fiscal_period_id,
    v.id                                   AS voucher_id,
    v.journal_sequence_no,
    v.voucher_no,
    vt.code                                AS voucher_type_code,
    vt.name                                AS voucher_type_name,
    v.document_date,
    v.posting_date,
    v.description                          AS voucher_description,
    v.source_document_no,
    v.module_source,
    v.status,
    vl.id                                  AS line_id,
    vl.line_no,
    a.code                                 AS account_code,
    a.name                                 AS account_name,
    a.account_type,
    COALESCE(vl.description, v.description) AS line_description,
    vl.debit_kurus,
    vl.credit_kurus,
    CAST(vl.debit_kurus  AS DECIMAL(18,2)) / 100  AS debit_amount,
    CAST(vl.credit_kurus AS DECIMAL(18,2)) / 100  AS credit_amount,
    vl.currency_code,
    vl.foreign_amount,
    vl.exchange_rate,
    ca.code                                AS current_account_code,
    ca.title                               AS current_account_title,
    cc.code                                AS cost_center_code,
    pr.code                                AS project_code,
    vl.vat_code_id,
    vl.vat_base_kurus,
    vl.vat_amount_kurus,
    v.branch_id,
    b.code                                 AS branch_code
FROM dbo.voucher_lines        vl
INNER JOIN dbo.vouchers       v  ON v.id  = vl.voucher_id
INNER JOIN dbo.fiscal_years   fy ON fy.id = v.fiscal_year_id
INNER JOIN dbo.voucher_types  vt ON vt.id = v.voucher_type_id
INNER JOIN dbo.accounts       a  ON a.id  = vl.account_id
LEFT  JOIN dbo.current_accounts ca ON ca.id = vl.current_account_id
LEFT  JOIN dbo.cost_centers     cc ON cc.id = vl.cost_center_id
LEFT  JOIN dbo.projects         pr ON pr.id = vl.project_id
LEFT  JOIN dbo.branches          b ON  b.id = v.branch_id
WHERE v.status <> 'IPTAL';
GO

-- --------------------------------------------------------
-- VW: Muavin / Büyük Defter (vw_general_ledger)
-- Her hesap için tarih sıralamalı hareketler
-- --------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_general_ledger
AS
SELECT
    v.company_id,
    v.fiscal_year_id,
    fy.fiscal_year,
    v.fiscal_period_id,
    a.id                                   AS account_id,
    a.code                                 AS account_code,
    a.name                                 AS account_name,
    a.account_type,
    v.id                                   AS voucher_id,
    v.journal_sequence_no,
    v.voucher_no,
    vt.code                                AS voucher_type_code,
    v.document_date,
    v.posting_date,
    vl.line_no,
    COALESCE(vl.description, v.description) AS line_description,
    vl.debit_kurus,
    vl.credit_kurus,
    CAST(vl.debit_kurus  AS DECIMAL(18,2)) / 100  AS debit_amount,
    CAST(vl.credit_kurus AS DECIMAL(18,2)) / 100  AS credit_amount,
    vl.currency_code,
    vl.foreign_amount,
    ca.code                                AS current_account_code,
    ca.title                               AS current_account_title,
    vl.cost_center_id,
    vl.project_id,
    v.branch_id
FROM dbo.voucher_lines        vl
INNER JOIN dbo.vouchers       v  ON v.id  = vl.voucher_id
INNER JOIN dbo.fiscal_years   fy ON fy.id = v.fiscal_year_id
INNER JOIN dbo.voucher_types  vt ON vt.id = v.voucher_type_id
INNER JOIN dbo.accounts       a  ON a.id  = vl.account_id
LEFT  JOIN dbo.current_accounts ca ON ca.id = vl.current_account_id
WHERE v.status <> 'IPTAL';
GO

-- --------------------------------------------------------
-- VW: Mizan Ham Verisi (vw_trial_balance_raw)
-- API katmanı bu view üzerinden dönem bası/hareket/kapanış hesaplar.
-- --------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_trial_balance_raw
AS
SELECT
    v.company_id,
    v.fiscal_year_id,
    fy.fiscal_year,
    a.id                    AS account_id,
    a.code                  AS account_code,
    a.name                  AS account_name,
    a.account_class,
    a.account_type,
    a.normal_balance,
    v.posting_date,
    vl.debit_kurus,
    vl.credit_kurus
FROM dbo.voucher_lines        vl
INNER JOIN dbo.vouchers       v  ON v.id  = vl.voucher_id
INNER JOIN dbo.fiscal_years   fy ON fy.id = v.fiscal_year_id
INNER JOIN dbo.accounts       a  ON a.id  = vl.account_id
WHERE v.status <> 'IPTAL';
GO

-- --------------------------------------------------------
-- VW: Cari Açık Hareketler (vw_current_account_open_items)
-- --------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_current_account_open_items
AS
SELECT
    v.company_id,
    ca.id                                   AS current_account_id,
    ca.code                                 AS current_account_code,
    ca.title                                AS current_account_title,
    v.id                                    AS voucher_id,
    v.voucher_no,
    vl.id                                   AS line_id,
    vl.line_no,
    vt.code                                 AS voucher_type_code,
    v.document_date,
    v.posting_date,
    COALESCE(vl.description, v.description) AS description,
    vl.debit_kurus,
    vl.credit_kurus,
    vl.currency_code,
    vl.foreign_amount,
    vl.due_date,
    vl.document_no                          AS ref_document_no,
    -- Kapatılmış mı kontrol: current_account_closings ile join yapılır
    CASE
        WHEN cac_d.id IS NOT NULL OR cac_c.id IS NOT NULL THEN 1
        ELSE 0
    END                                     AS is_matched
FROM dbo.voucher_lines           vl
INNER JOIN dbo.vouchers          v   ON v.id  = vl.voucher_id
INNER JOIN dbo.voucher_types     vt  ON vt.id = v.voucher_type_id
INNER JOIN dbo.current_accounts  ca  ON ca.id = vl.current_account_id
LEFT  JOIN dbo.current_account_closings cac_d
    ON cac_d.debit_voucher_line_id  = vl.id
LEFT  JOIN dbo.current_account_closings cac_c
    ON cac_c.credit_voucher_line_id = vl.id
WHERE v.status <> 'IPTAL'
  AND vl.current_account_id IS NOT NULL;
GO

-- --------------------------------------------------------
-- VW: KDV Hareket Özeti (vw_vat_summary)
-- --------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_vat_summary
AS
SELECT
    v.company_id,
    v.fiscal_year_id,
    v.fiscal_period_id,
    fp.period_no,
    vc.code                                 AS vat_code,
    vc.vat_direction,
    vc.vat_rate,
    SUM(vl.vat_base_kurus)                  AS total_base_kurus,
    SUM(vl.vat_amount_kurus)                AS total_vat_kurus,
    CAST(SUM(vl.vat_base_kurus)   AS DECIMAL(18,2)) / 100  AS total_base,
    CAST(SUM(vl.vat_amount_kurus) AS DECIMAL(18,2)) / 100  AS total_vat
FROM dbo.voucher_lines          vl
INNER JOIN dbo.vouchers         v   ON v.id  = vl.voucher_id
INNER JOIN dbo.vat_codes        vc  ON vc.id = vl.vat_code_id
INNER JOIN dbo.fiscal_periods   fp  ON fp.id = v.fiscal_period_id
WHERE v.status <> 'IPTAL'
  AND vl.vat_code_id IS NOT NULL
  AND vl.vat_amount_kurus > 0
GROUP BY
    v.company_id, v.fiscal_year_id, v.fiscal_period_id,
    fp.period_no, vc.code, vc.vat_direction, vc.vat_rate;
GO

-- --------------------------------------------------------
-- VW: Sabit Kıymet Cetveli (vw_fixed_asset_schedule)  — §21.1
-- --------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_fixed_asset_schedule
AS
SELECT
    fa.company_id,
    fac.code                                AS category_code,
    fac.name                                AS category_name,
    fa.code                                 AS asset_code,
    fa.name                                 AS asset_name,
    fa.serial_no,
    fa.location,
    fa.acquisition_date,
    fa.acquisition_cost,
    fa.useful_life_months,
    fa.depreciation_method,
    fa.residual_value,
    fa.status,
    ISNULL(dep.total_depreciation, 0)       AS accumulated_depreciation,
    fa.acquisition_cost
        - ISNULL(dep.total_depreciation, 0)
        - fa.residual_value                 AS net_book_value,
    dep.last_depreciation_date
FROM dbo.fixed_assets fa
INNER JOIN dbo.fixed_asset_categories fac ON fac.id = fa.category_id
OUTER APPLY (
    SELECT
        SUM(dl.depreciation_amount) AS total_depreciation,
        MAX(dl.depreciation_date)   AS last_depreciation_date
    FROM dbo.depreciation_lines dl
    WHERE dl.fixed_asset_id = fa.id
      AND dl.is_posted = 1
) dep;
GO

-- --------------------------------------------------------
-- VW: Çek/Senet Portföy (vw_negotiable_portfolio)  — §15.3
-- --------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_negotiable_portfolio
AS
SELECT
    ni.company_id,
    ni.instrument_type,
    ni.direction,
    ni.serial_no,
    ni.bank_name,
    ni.due_date,
    CAST(ni.amount_kurus AS DECIMAL(18,2)) / 100  AS amount,
    ni.currency_code,
    ni.status,
    ca.code                                 AS current_account_code,
    ca.title                                AS current_account_title,
    ni.issue_date,
    ni.created_at
FROM dbo.negotiable_instruments ni
LEFT JOIN dbo.current_accounts ca ON ca.id = ni.current_account_id;
GO
