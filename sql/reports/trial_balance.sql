-- ============================================================
-- MİZAN RAPORU (Dönem Başı / Dönem Hareketi / Dönem Sonu)
-- Parametreler: @company_id, @fiscal_year_id, @start_date, @end_date
-- Şartname §21.1 - mizan, aylık mizan, iki tarih arası mizan
-- ============================================================

DECLARE
    @company_id    INT          = :company_id,
    @fiscal_year_id INT         = :fiscal_year_id,
    @start_date    DATE         = :start_date,
    @end_date      DATE         = :end_date;

WITH base AS (
    SELECT
        a.company_id,
        a.id                   AS account_id,
        a.code                 AS account_code,
        a.name                 AS account_name,
        a.account_class,
        a.account_type,
        a.normal_balance,
        -- Dönem başı (start_date öncesi tüm hareketler)
        COALESCE(SUM(CASE WHEN v.posting_date < @start_date THEN vl.debit_kurus  ELSE 0 END), 0)
            AS opening_debit_kurus,
        COALESCE(SUM(CASE WHEN v.posting_date < @start_date THEN vl.credit_kurus ELSE 0 END), 0)
            AS opening_credit_kurus,
        -- Dönem hareketi
        COALESCE(SUM(CASE WHEN v.posting_date BETWEEN @start_date AND @end_date
                          THEN vl.debit_kurus  ELSE 0 END), 0)
            AS period_debit_kurus,
        COALESCE(SUM(CASE WHEN v.posting_date BETWEEN @start_date AND @end_date
                          THEN vl.credit_kurus ELSE 0 END), 0)
            AS period_credit_kurus
    FROM dbo.accounts a
    LEFT JOIN dbo.voucher_lines vl ON vl.account_id = a.id
    LEFT JOIN dbo.vouchers      v  ON v.id = vl.voucher_id
                                  AND v.company_id     = @company_id
                                  AND v.fiscal_year_id = @fiscal_year_id
                                  AND v.status        <> N'IPTAL'
                                  AND v.posting_date  <= @end_date
    WHERE a.company_id  = @company_id
      AND a.is_active   = 1
    GROUP BY a.id, a.company_id, a.code, a.name,
             a.account_class, a.account_type, a.normal_balance
),
calculated AS (
    SELECT
        account_id,
        account_code,
        account_name,
        account_class,
        account_type,
        normal_balance,
        opening_debit_kurus,
        opening_credit_kurus,
        -- Dönem başı bakiye (borç - alacak)
        opening_debit_kurus - opening_credit_kurus   AS opening_balance_kurus,
        period_debit_kurus,
        period_credit_kurus,
        -- Dönem sonu = dönem başı + dönem hareketi
        (opening_debit_kurus  + period_debit_kurus)  AS closing_debit_kurus,
        (opening_credit_kurus + period_credit_kurus) AS closing_credit_kurus,
        (opening_debit_kurus  - opening_credit_kurus
         + period_debit_kurus - period_credit_kurus) AS closing_balance_kurus
    FROM base
    WHERE opening_debit_kurus  > 0
       OR opening_credit_kurus > 0
       OR period_debit_kurus   > 0
       OR period_credit_kurus  > 0
)
SELECT
    account_code,
    account_name,
    account_class,
    account_type,
    normal_balance,
    -- Dönem başı (borç / alacak kolonu)
    CASE WHEN opening_balance_kurus > 0
         THEN CAST(opening_balance_kurus  AS DECIMAL(18,2)) / 100 ELSE 0 END  AS opening_debit,
    CASE WHEN opening_balance_kurus < 0
         THEN CAST(-opening_balance_kurus AS DECIMAL(18,2)) / 100 ELSE 0 END  AS opening_credit,
    -- Dönem hareketi
    CAST(period_debit_kurus  AS DECIMAL(18,2)) / 100  AS period_debit,
    CAST(period_credit_kurus AS DECIMAL(18,2)) / 100  AS period_credit,
    -- Dönem sonu (borç / alacak kolonu)
    CASE WHEN closing_balance_kurus > 0
         THEN CAST(closing_balance_kurus  AS DECIMAL(18,2)) / 100 ELSE 0 END  AS closing_debit,
    CASE WHEN closing_balance_kurus < 0
         THEN CAST(-closing_balance_kurus AS DECIMAL(18,2)) / 100 ELSE 0 END  AS closing_credit
FROM calculated
ORDER BY account_code;
