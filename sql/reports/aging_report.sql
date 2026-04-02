-- ============================================================
-- CARİ HESAP YAŞLANDIRMA RAPORU
-- §21.7 — 0-30, 31-60, 61-90, 91-120, 120+ gün vadeleri
-- Parametreler: @company_id, @as_of_date, @current_account_type_id (NULL=tümü)
-- ============================================================

DECLARE
    @company_id              INT  = :company_id,
    @as_of_date              DATE = :as_of_date,
    @current_account_type_id INT  = :current_account_type_id;

WITH open_lines AS (
    -- Açık kalemleri bul (kapatılmamış fatura/tahsilat satırları)
    SELECT
        ca.id              AS current_account_id,
        ca.code            AS current_account_code,
        ca.title           AS current_account_title,
        cat.name           AS current_account_type,
        ca.tax_number,
        ca.city,
        v.voucher_no,
        vt.code            AS voucher_type_code,
        v.document_date,
        v.posting_date,
        v.source_document_no,
        COALESCE(vl.description, v.description) AS line_description,
        vl.due_date,
        -- Bakiye (borç - alacak)
        (vl.debit_kurus - vl.credit_kurus) AS net_kurus,
        vl.currency_code,
        vl.foreign_amount,
        -- Vade geçen gün sayısı
        CASE
            WHEN vl.due_date IS NOT NULL THEN DATEDIFF(DAY, vl.due_date, @as_of_date)
            ELSE DATEDIFF(DAY, v.posting_date, @as_of_date)
        END AS age_days
    FROM dbo.voucher_lines          vl
    INNER JOIN dbo.vouchers         v   ON v.id  = vl.voucher_id
    INNER JOIN dbo.voucher_types    vt  ON vt.id = v.voucher_type_id
    INNER JOIN dbo.current_accounts ca  ON ca.id = vl.current_account_id
    INNER JOIN dbo.current_account_types cat ON cat.id = ca.type_id
    WHERE v.company_id  = @company_id
      AND v.posting_date <= @as_of_date
      AND v.status       <> N'IPTAL'
      AND vl.current_account_id IS NOT NULL
    AND (@current_account_type_id IS NULL OR ca.type_id = @current_account_type_id)
      -- Kapatılmamış kalemler
      AND NOT EXISTS (
          SELECT 1 FROM dbo.current_account_closings cac
                    WHERE (cac.debit_voucher_line_id = vl.id OR cac.credit_voucher_line_id = vl.id)
            AND cac.company_id = @company_id
      )
),
-- Net bakiyesi olan kalemler
with_balance AS (
    SELECT * FROM open_lines WHERE net_kurus <> 0
),
-- Yaşlandırma kutuları
aged AS (
    SELECT
        w.*,
        -- Vadesi geçip geçmediği
        CASE WHEN w.age_days < 0 THEN N'VADESİ GELMEMİŞ' ELSE N'VADESİ GEÇMİŞ' END AS maturity_status,
        -- Yaşlandırma kovası
        CASE
            WHEN w.age_days <  0  THEN N'VADESİZ'
            WHEN w.age_days <= 30 THEN N'0-30 GÜN'
            WHEN w.age_days <= 60 THEN N'31-60 GÜN'
            WHEN w.age_days <= 90 THEN N'61-90 GÜN'
            WHEN w.age_days <=120 THEN N'91-120 GÜN'
            ELSE                       N'120+ GÜN'
        END AS age_bucket,
        CASE
            WHEN w.age_days <  0  THEN 0
            WHEN w.age_days <= 30 THEN 1
            WHEN w.age_days <= 60 THEN 2
            WHEN w.age_days <= 90 THEN 3
            WHEN w.age_days <=120 THEN 4
            ELSE                       5
        END AS age_bucket_sort
    FROM with_balance w
)
-- ---- Detay raporu
SELECT
    a.current_account_code,
    a.current_account_title,
    a.current_account_type,
    a.tax_number,
    a.city,
    a.voucher_no,
    a.voucher_type_code,
    a.document_date,
    a.posting_date,
    a.source_document_no,
    a.line_description,
    a.due_date,
    a.age_days,
    a.maturity_status,
    a.age_bucket,
    a.currency_code,
    a.foreign_amount,
    -- TL bakiye
    CAST(a.net_kurus AS DECIMAL(18,2)) / 100 AS balance_tl,
    -- Kova tutarları (pivot benzeri kova)
    CAST(CASE WHEN a.age_bucket_sort = 0 THEN a.net_kurus  ELSE 0 END AS DECIMAL(18,2)) / 100 AS not_due,
    CAST(CASE WHEN a.age_bucket_sort = 1 THEN a.net_kurus  ELSE 0 END AS DECIMAL(18,2)) / 100 AS days_0_30,
    CAST(CASE WHEN a.age_bucket_sort = 2 THEN a.net_kurus  ELSE 0 END AS DECIMAL(18,2)) / 100 AS days_31_60,
    CAST(CASE WHEN a.age_bucket_sort = 3 THEN a.net_kurus  ELSE 0 END AS DECIMAL(18,2)) / 100 AS days_61_90,
    CAST(CASE WHEN a.age_bucket_sort = 4 THEN a.net_kurus  ELSE 0 END AS DECIMAL(18,2)) / 100 AS days_91_120,
    CAST(CASE WHEN a.age_bucket_sort = 5 THEN a.net_kurus  ELSE 0 END AS DECIMAL(18,2)) / 100 AS days_over_120
FROM aged a
ORDER BY a.current_account_code, a.age_bucket_sort DESC, a.due_date;

-- ---- Özet (müşteri bazında toplam) ----------------------------------------
/*
SELECT
    current_account_code,
    current_account_title,
    current_account_type,
    tax_number,
    SUM(balance_tl)   AS total_balance,
    SUM(not_due)      AS not_due,
    SUM(days_0_30)    AS days_0_30,
    SUM(days_31_60)   AS days_31_60,
    SUM(days_61_90)   AS days_61_90,
    SUM(days_91_120)  AS days_91_120,
    SUM(days_over_120) AS days_over_120
FROM (yukarıdaki sorgu) x
GROUP BY current_account_code, current_account_title, current_account_type, tax_number
ORDER BY current_account_code;
*/
