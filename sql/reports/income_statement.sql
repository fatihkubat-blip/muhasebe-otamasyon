-- ============================================================
-- GELİR TABLOSU (Tek Düzen Hesap Planı bazlı)
-- §21.5 — 6. ve 7. sınıf hesaplar, dönem kâr/zarar
-- Parametreler: @company_id, @fiscal_year_id, @start_date, @end_date
-- ============================================================

DECLARE
    @company_id     INT  = :company_id,
    @fiscal_year_id INT  = :fiscal_year_id,
    @start_date     DATE = :start_date,
    @end_date       DATE = :end_date;

WITH net AS (
    SELECT
        a.id             AS account_id,
        a.code           AS account_code,
        a.name           AS account_name,
        a.account_class,
        a.normal_balance,
        a.income_stmt_group,
        a.income_stmt_line,
        SUM(vl.debit_kurus)  AS total_debit_kurus,
        SUM(vl.credit_kurus) AS total_credit_kurus
    FROM dbo.voucher_lines        vl
    INNER JOIN dbo.vouchers       v ON v.id = vl.voucher_id
    INNER JOIN dbo.accounts       a ON a.id = vl.account_id
    WHERE v.company_id     = @company_id
      AND v.fiscal_year_id = @fiscal_year_id
      AND v.posting_date BETWEEN @start_date AND @end_date
      AND v.status        <> N'IPTAL'
      AND a.account_class IN (N'6', N'7')
    GROUP BY
        a.id, a.code, a.name, a.account_class,
        a.normal_balance, a.income_stmt_group, a.income_stmt_line
),
balances AS (
    SELECT
        n.*,
        CASE n.normal_balance
            WHEN N'A' THEN n.total_credit_kurus - n.total_debit_kurus
            WHEN N'B' THEN n.total_debit_kurus  - n.total_credit_kurus
            ELSE            n.total_debit_kurus  - n.total_credit_kurus
        END AS net_balance_kurus
    FROM net n
),
-- Gelir ve gider kategorileri
categorized AS (
    SELECT
        b.*,
        CASE
            -- 6. Sınıf: Gelir Tablosu
            WHEN b.account_code BETWEEN N'600' AND N'602' THEN N'NET SATIŞLAR'
            WHEN b.account_code BETWEEN N'610' AND N'612' THEN N'SATIŞLARIN MALİYETİ (eksi)'
            WHEN b.account_code BETWEEN N'620' AND N'622' THEN N'SATIŞLARIN MALİYETİ (eksi)'
            WHEN b.account_code BETWEEN N'630' AND N'632' THEN N'FAALİYET GİDERLERİ (eksi)'
            WHEN b.account_code BETWEEN N'640' AND N'649' THEN N'DİĞER FAALİYET GELİRLERİ'
            WHEN b.account_code BETWEEN N'650' AND N'659' THEN N'DİĞER FAALİYET GİDERLERİ (eksi)'
            WHEN b.account_code BETWEEN N'660' AND N'669' THEN N'FİNANSMAN GELİRLERİ'
            WHEN b.account_code BETWEEN N'670' AND N'679' THEN N'FİNANSMAN GİDERLERİ (eksi)'
            WHEN b.account_code BETWEEN N'680' AND N'689' THEN N'OLAĞANDIŞI GELİR VE KÂRLAR'
            WHEN b.account_code BETWEEN N'690' AND N'692' THEN N'DÖNEMİN NET KÂRI/ZARARI'
            -- 7. Sınıf: Maliyet Hesapları
            WHEN b.account_code LIKE N'7%'               THEN N'MALİYET HESAPLARI'
            ELSE N'DİĞER'
        END AS income_stmt_category,
        CASE
            WHEN b.account_code BETWEEN N'600' AND N'609' THEN 1
            WHEN b.account_code BETWEEN N'610' AND N'629' THEN 2
            WHEN b.account_code BETWEEN N'630' AND N'639' THEN 3
            WHEN b.account_code BETWEEN N'640' AND N'649' THEN 4
            WHEN b.account_code BETWEEN N'650' AND N'659' THEN 5
            WHEN b.account_code BETWEEN N'660' AND N'669' THEN 6
            WHEN b.account_code BETWEEN N'670' AND N'679' THEN 7
            WHEN b.account_code BETWEEN N'680' AND N'689' THEN 8
            WHEN b.account_code BETWEEN N'690' AND N'692' THEN 9
            WHEN b.account_code LIKE N'7%'               THEN 10
            ELSE 99
        END AS sort_order
    FROM balances b
)
SELECT
    c.account_class,
    c.sort_order,
    c.income_stmt_category,
    c.income_stmt_group,
    c.income_stmt_line,
    c.account_code,
    c.account_name,
    c.normal_balance,
    CAST(c.total_debit_kurus  AS DECIMAL(18,2)) / 100 AS total_debit,
    CAST(c.total_credit_kurus AS DECIMAL(18,2)) / 100 AS total_credit,
    CAST(c.net_balance_kurus  AS DECIMAL(18,2)) / 100 AS net_balance
FROM categorized c
WHERE c.net_balance_kurus <> 0
ORDER BY c.sort_order, c.account_code;

-- ---- Özet (client tarafında hesaplanabilir):
-- NET SATIŞ - SATIŞLARIN MALİYETİ = BRÜT SATIŞ KÂRI
-- BRÜT SATIŞ KÂRI - FAALİYET GİDERLERİ + DİĞER FAALİYET GELİRLERİ = FAALİYET KÂRI
-- FAALİYET KÂRI ± FİNANSMAN GELİR/GİDER ± OLAĞANDIŞI = DÖNEM NET KÂRI
