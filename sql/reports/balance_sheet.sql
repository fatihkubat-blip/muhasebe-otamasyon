-- ============================================================
-- BİLANÇO (Tek Düzen Hesap Planı bazlı)
-- §21.4 — Dönem sonu bilanço (1-5. sınıf hesaplar)
-- Parametreler: @company_id, @fiscal_year_id, @as_of_date
-- ============================================================

DECLARE
    @company_id     INT  = :company_id,
    @fiscal_year_id INT  = :fiscal_year_id,
    @as_of_date     DATE = :as_of_date;

WITH net AS (
    SELECT
        a.id             AS account_id,
        a.code           AS account_code,
        a.name           AS account_name,
        a.account_class,
        a.normal_balance,
        a.balance_sheet_group,
        a.balance_sheet_line,
        SUM(vl.debit_kurus)  AS total_debit_kurus,
        SUM(vl.credit_kurus) AS total_credit_kurus
    FROM dbo.voucher_lines        vl
    INNER JOIN dbo.vouchers       v ON v.id = vl.voucher_id
    INNER JOIN dbo.accounts       a ON a.id = vl.account_id
    WHERE v.company_id     = @company_id
      AND v.fiscal_year_id = @fiscal_year_id
      AND v.posting_date  <= @as_of_date
      AND v.status        <> N'IPTAL'
      AND a.account_class IN (N'1', N'2', N'3', N'4', N'5')
    GROUP BY
        a.id, a.code, a.name, a.account_class,
        a.normal_balance, a.balance_sheet_group, a.balance_sheet_line
),
balances AS (
    SELECT
        n.*,
        -- Net bakiye (normal bakiye yönünde pozitif, ters yönde negatif)
        CASE n.normal_balance
            WHEN N'B' THEN n.total_debit_kurus  - n.total_credit_kurus
            WHEN N'A' THEN n.total_credit_kurus - n.total_debit_kurus
            ELSE            n.total_debit_kurus  - n.total_credit_kurus
        END AS net_balance_kurus
    FROM net n
)
SELECT
    b.account_class,
    CASE b.account_class
        WHEN N'1' THEN N'DÖNEN VARLIKLAR'
        WHEN N'2' THEN N'DURAN VARLIKLAR'
        WHEN N'3' THEN N'KISA VADELİ YABANCI KAYNAKLAR'
        WHEN N'4' THEN N'UZUN VADELİ YABANCI KAYNAKLAR'
        WHEN N'5' THEN N'ÖZKAYNAKLAR'
    END AS balance_sheet_section,
    b.balance_sheet_group,
    b.balance_sheet_line,
    b.account_code,
    b.account_name,
    b.normal_balance,
    CAST(b.total_debit_kurus  AS DECIMAL(18,2)) / 100 AS total_debit,
    CAST(b.total_credit_kurus AS DECIMAL(18,2)) / 100 AS total_credit,
    CAST(b.net_balance_kurus  AS DECIMAL(18,2)) / 100 AS net_balance,
    -- Bilanço tarafı (aktif/pasif)
    CASE
        WHEN b.account_class IN (N'1', N'2') THEN N'AKTİF'
        ELSE N'PASİF'
    END AS balance_sheet_side
FROM balances b
WHERE b.net_balance_kurus <> 0
ORDER BY b.account_class, b.account_code;

-- ---- Aktif / Pasif toplamları -----------------------------------------------
-- (Client tarafında hesaplanabilir; doğrulama için ek sorgu):
/*
SELECT
    CASE WHEN account_class IN ('1','2') THEN 'AKTİF' ELSE 'PASİF' END AS side,
    SUM(net_balance) AS total
FROM (yukarıdaki sorgu) x
GROUP BY CASE WHEN account_class IN ('1','2') THEN 'AKTİF' ELSE 'PASİF' END;
*/
