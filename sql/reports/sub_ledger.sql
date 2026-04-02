-- ============================================================
-- MUAVİN DEFTERİ (CARİ HESAP BAZLI)
-- §21.3 — cari hesap açık/kapalı kalemler, yaşlandırma bilgisi
-- Parametreler: @company_id, @fiscal_year_id, @start_date, @end_date,
--               @current_account_id (NULL=tümü), @only_open BIT
-- ============================================================

DECLARE
    @company_id        INT  = :company_id,
    @fiscal_year_id    INT  = :fiscal_year_id,
    @start_date        DATE = :start_date,
    @end_date          DATE = :end_date,
    @current_account_id INT = :current_account_id,   -- NULL = tümü
    @only_open         BIT  = :only_open;             -- 1 = sadece açık kalemler

-- ---- Dönem başı cari bakiyesi -------------------------------------------
WITH ca_opening AS (
    SELECT
        vl.current_account_id,
        SUM(vl.debit_kurus)  AS ob_debit_kurus,
        SUM(vl.credit_kurus) AS ob_credit_kurus
    FROM dbo.voucher_lines  vl
    INNER JOIN dbo.vouchers v ON v.id = vl.voucher_id
    WHERE v.company_id     = @company_id
      AND v.fiscal_year_id = @fiscal_year_id
      AND v.posting_date   < @start_date
      AND v.status        <> N'IPTAL'
      AND vl.current_account_id IS NOT NULL
      AND (@current_account_id IS NULL OR vl.current_account_id = @current_account_id)
    GROUP BY vl.current_account_id
),
-- ---- Dönem hareketleri ---------------------------------------------------
ca_lines AS (
    SELECT
        ca.id              AS current_account_id,
        ca.code            AS current_account_code,
        ca.title           AS current_account_title,
        cat.name           AS current_account_type,
        a.code             AS account_code,
        a.name             AS account_name,
        v.posting_date,
        v.journal_sequence_no,
        v.voucher_no,
        vt.code            AS voucher_type_code,
        v.document_date,
        v.source_document_no,
        COALESCE(vl.description, v.description) AS line_description,
        fp.period_no,
        vl.debit_kurus,
        vl.credit_kurus,
        vl.currency_code,
        vl.foreign_amount,
        vl.exchange_rate,
        vl.due_date,
        DATEDIFF(DAY, vl.due_date, CAST(GETDATE() AS DATE)) AS overdue_days
    FROM dbo.voucher_lines          vl
    INNER JOIN dbo.vouchers         v   ON v.id   = vl.voucher_id
    INNER JOIN dbo.voucher_types    vt  ON vt.id  = v.voucher_type_id
    INNER JOIN dbo.accounts         a   ON a.id   = vl.account_id
    INNER JOIN dbo.current_accounts ca  ON ca.id  = vl.current_account_id
    INNER JOIN dbo.current_account_types cat ON cat.id = ca.type_id
    INNER JOIN dbo.fiscal_periods   fp  ON fp.id  = v.fiscal_period_id
    WHERE v.company_id     = @company_id
      AND v.fiscal_year_id = @fiscal_year_id
      AND v.posting_date BETWEEN @start_date AND @end_date
      AND v.status        <> N'IPTAL'
      AND vl.current_account_id IS NOT NULL
      AND (@current_account_id IS NULL OR vl.current_account_id = @current_account_id)
),
-- ---- Kapatma bilgisi (cari_account_closings tablosundan) -----------------
closed_lines AS (
    SELECT DISTINCT debit_voucher_line_id AS voucher_line_id
    FROM dbo.current_account_closings
    WHERE company_id = @company_id
    UNION
    SELECT DISTINCT credit_voucher_line_id AS voucher_line_id
    FROM dbo.current_account_closings
    WHERE company_id = @company_id
),
-- ---- Kümülatif bakiye ---------------------------------------------------
numbered AS (
    SELECT
        cl.*,
        ROW_NUMBER() OVER (
            PARTITION BY cl.current_account_id
            ORDER BY cl.posting_date, cl.journal_sequence_no
        ) AS rn,
        COALESCE(ob.ob_debit_kurus,  0) AS ob_debit_kurus,
        COALESCE(ob.ob_credit_kurus, 0) AS ob_credit_kurus
    FROM ca_lines cl
    LEFT JOIN ca_opening ob ON ob.current_account_id = cl.current_account_id
),
cumulative AS (
    SELECT
        n.*,
        SUM(n.debit_kurus)  OVER (PARTITION BY n.current_account_id
                                  ORDER BY n.posting_date, n.journal_sequence_no
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            + n.ob_debit_kurus   AS cum_debit_kurus,
        SUM(n.credit_kurus) OVER (PARTITION BY n.current_account_id
                                  ORDER BY n.posting_date, n.journal_sequence_no
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            + n.ob_credit_kurus  AS cum_credit_kurus
    FROM numbered n
)
SELECT
    c.current_account_code,
    c.current_account_title,
    c.current_account_type,
    c.account_code,
    c.account_name,
    -- Dönem başı bakiyesi (sadece ilk satırda anlamlı)
    CASE WHEN c.rn = 1
         THEN CAST(c.ob_debit_kurus  AS DECIMAL(18,2)) / 100 END AS ob_debit,
    CASE WHEN c.rn = 1
         THEN CAST(c.ob_credit_kurus AS DECIMAL(18,2)) / 100 END AS ob_credit,
    -- Hareket
    c.posting_date,
    c.period_no,
    c.journal_sequence_no,
    c.voucher_no,
    c.voucher_type_code,
    c.document_date,
    c.source_document_no,
    c.line_description,
    c.due_date,
    c.overdue_days,
    c.currency_code,
    c.foreign_amount,
    c.exchange_rate,
    CAST(c.debit_kurus  AS DECIMAL(18,2)) / 100 AS debit_amount,
    CAST(c.credit_kurus AS DECIMAL(18,2)) / 100 AS credit_amount,
    -- Kümülatif bakiye
    CAST(c.cum_debit_kurus  AS DECIMAL(18,2)) / 100 AS cum_debit,
    CAST(c.cum_credit_kurus AS DECIMAL(18,2)) / 100 AS cum_credit,
    CAST((c.cum_debit_kurus - c.cum_credit_kurus) AS DECIMAL(18,2)) / 100 AS balance
FROM cumulative c
ORDER BY c.current_account_code, c.posting_date, c.journal_sequence_no;
