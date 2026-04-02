-- ============================================================
-- VERGI RAPORLARI
-- A) KDV Beyan Hazirlik Raporu
-- B) Ba/Bs Form Veri Seti
-- C) Tevkifat / Stopaj Ozeti
-- Parametreler: :company_id, :period_from, :period_to, :threshold_kurus
-- ============================================================

DECLARE
    @company_id  INT  = :company_id,
    @period_from DATE = :period_from,
    @period_to   DATE = :period_to,
    @threshold_kurus BIGINT = :threshold_kurus;

-- A) KDV (SATIS)
SELECT
    N'HESAPLANAN KDV' AS kdv_direction,
    vc.code AS vat_code,
    vc.name AS vat_code_name,
    vc.vat_rate AS kdv_orani,
    vc.vat_direction,
    dt.code AS document_type_code,
    COUNT(*) AS transaction_count,
    CAST(SUM(vl.vat_base_kurus) AS DECIMAL(18,2)) / 100 AS matrah,
    CAST(SUM(vl.vat_amount_kurus) AS DECIMAL(18,2)) / 100 AS kdv_tutari
FROM dbo.voucher_lines vl
INNER JOIN dbo.vouchers v ON v.id = vl.voucher_id
INNER JOIN dbo.vat_codes vc ON vc.id = vl.vat_code_id
LEFT JOIN dbo.document_headers dh ON dh.document_no = v.source_document_no AND dh.company_id = v.company_id
LEFT JOIN dbo.document_types dt ON dt.id = dh.document_type_id
WHERE v.company_id = @company_id
  AND v.posting_date BETWEEN @period_from AND @period_to
  AND v.status <> N'IPTAL'
  AND vl.vat_amount_kurus <> 0
  AND vc.vat_direction = N'SATIS'
GROUP BY vc.code, vc.name, vc.vat_rate, vc.vat_direction, dt.code
ORDER BY vc.vat_rate DESC, vc.code;

-- A) KDV (ALIS)
SELECT
    N'INDIRILECEK KDV' AS kdv_direction,
    vc.code AS vat_code,
    vc.name AS vat_code_name,
    vc.vat_rate AS kdv_orani,
    vc.vat_direction,
    dt.code AS document_type_code,
    COUNT(*) AS transaction_count,
    CAST(SUM(vl.vat_base_kurus) AS DECIMAL(18,2)) / 100 AS matrah,
    CAST(SUM(vl.vat_amount_kurus) AS DECIMAL(18,2)) / 100 AS kdv_tutari
FROM dbo.voucher_lines vl
INNER JOIN dbo.vouchers v ON v.id = vl.voucher_id
INNER JOIN dbo.vat_codes vc ON vc.id = vl.vat_code_id
LEFT JOIN dbo.document_headers dh ON dh.document_no = v.source_document_no AND dh.company_id = v.company_id
LEFT JOIN dbo.document_types dt ON dt.id = dh.document_type_id
WHERE v.company_id = @company_id
  AND v.posting_date BETWEEN @period_from AND @period_to
  AND v.status <> N'IPTAL'
  AND vl.vat_amount_kurus <> 0
  AND vc.vat_direction = N'ALIS'
GROUP BY vc.code, vc.name, vc.vat_rate, vc.vat_direction, dt.code
ORDER BY vc.vat_rate DESC, vc.code;

-- B) BA/BS veri seti
SELECT
    dh.document_date,
    YEAR(dh.document_date)  AS fiskal_yil,
    MONTH(dh.document_date) AS fiskal_ay,
    dt.direction,
    ca.code AS current_account_code,
    ca.title AS current_account_title,
    ca.tax_number AS vkn_tckn,
    CAST(SUM(dl.quantity * dl.unit_price) AS DECIMAL(18,2)) AS tutar_tl,
    CAST(SUM(dl.vat_amount_kurus) AS DECIMAL(18,2)) / 100 AS kdv_tutari_tl,
    COUNT(DISTINCT dh.id) AS belge_sayisi
FROM dbo.document_headers dh
INNER JOIN dbo.document_types dt ON dt.id = dh.document_type_id
INNER JOIN dbo.document_lines dl ON dl.document_id = dh.id
INNER JOIN dbo.current_accounts ca ON ca.id = dh.current_account_id
WHERE dh.company_id = @company_id
  AND dh.document_date BETWEEN @period_from AND @period_to
  AND dh.is_cancelled = 0
  AND dt.direction IN ('ALIS', 'SATIS')
GROUP BY
    YEAR(dh.document_date), MONTH(dh.document_date), dt.direction,
    ca.code, ca.title, ca.tax_number, dh.document_date
HAVING SUM(dl.quantity * dl.unit_price * 100) >= @threshold_kurus
ORDER BY YEAR(dh.document_date), MONTH(dh.document_date), dt.direction, ca.code;

-- C) Tevkifat / Stopaj
SELECT
    CASE WHEN wc.id IS NOT NULL THEN N'TEVKIFAT' ELSE N'STOPAJ' END AS kesinti_turu,
    COALESCE(wc.code, sc.code) AS kod,
    COALESCE(wc.name, sc.name) AS aciklama,
    COALESCE(wc.withholding_rate, sc.stopaj_rate) AS oran,
    ca.code AS current_account_code,
    ca.title AS current_account_title,
    ca.tax_number AS vkn_tckn,
    COUNT(*) AS islem_sayisi,
    CAST(SUM(vl.vat_base_kurus) AS DECIMAL(18,2)) / 100 AS matrah,
    CAST(SUM(COALESCE(vl.vat_amount_kurus, 0)) AS DECIMAL(18,2)) / 100 AS kesinti_tutari
FROM dbo.voucher_lines vl
INNER JOIN dbo.vouchers v ON v.id = vl.voucher_id
LEFT JOIN dbo.withholding_vat_codes wc ON wc.id = vl.withholding_code_id
LEFT JOIN dbo.stopaj_codes sc ON sc.id = vl.stopaj_code_id
LEFT JOIN dbo.current_accounts ca ON ca.id = vl.current_account_id
WHERE v.company_id = @company_id
  AND v.posting_date BETWEEN @period_from AND @period_to
  AND v.status <> N'IPTAL'
  AND (vl.withholding_code_id IS NOT NULL OR vl.stopaj_code_id IS NOT NULL)
GROUP BY
    CASE WHEN wc.id IS NOT NULL THEN N'TEVKIFAT' ELSE N'STOPAJ' END,
    wc.code, wc.name, wc.withholding_rate,
    sc.code, sc.name, sc.stopaj_rate,
    ca.code, ca.title, ca.tax_number
ORDER BY kesinti_turu, kod, ca.code;
