-- ============================================================
-- BÜYÜK DEFTERİ (GENEL MUAVIN)
-- Hesap bazlı açılış bakiyesi + kümülatif hareketler
-- Parametreler: @company_id, @fiscal_year_id, @start_date, @end_date, @account_code_like
-- ============================================================

DECLARE
    @company_id        INT           = :company_id,
    @fiscal_year_id    INT           = :fiscal_year_id,
    @start_date        DATE          = :start_date,
    @end_date          DATE          = :end_date,
    @account_code_like NVARCHAR(50)  = :account_code_like;  -- örn: '100%' veya NULL

-- ---- 1. Dönem başı bakiyesi (start_date öncesi) ------------------------
WITH opening AS (
    SELECT
        a.id              AS account_id,
        a.code            AS account_code,
        a.name            AS account_name,
        a.normal_balance,
        SUM(vl.debit_kurus)  AS ob_debit_kurus,
        SUM(vl.credit_kurus) AS ob_credit_kurus
    FROM dbo.voucher_lines        vl
    INNER JOIN dbo.vouchers       v  ON v.id = vl.voucher_id
    INNER JOIN dbo.accounts       a  ON a.id = vl.account_id
    WHERE v.company_id     = @company_id
      AND v.fiscal_year_id = @fiscal_year_id
      AND v.posting_date   < @start_date
      AND v.status        <> N'IPTAL'
      AND (@account_code_like IS NULL OR a.code LIKE @account_code_like)
    GROUP BY a.id, a.code, a.name, a.normal_balance
),
-- ---- 2. Dönem hareketleri ----------------------------------------------
period_lines AS (
    SELECT
        a.id              AS account_id,
        a.code            AS account_code,
        a.name            AS account_name,
        a.normal_balance,
        v.journal_sequence_no,
        v.voucher_no,
        vt.code           AS voucher_type_code,
        v.document_date,
        v.posting_date,
        fp.period_no,
        vl.line_no,
        COALESCE(vl.description, v.description) AS line_description,
        v.source_document_no,
        ca.code           AS current_account_code,
        ca.title          AS current_account_title,
        cc.code           AS cost_center_code,
        pr.code           AS project_code,
        vl.debit_kurus,
        vl.credit_kurus,
        vl.currency_code,
        vl.foreign_amount,
        vl.exchange_rate
    FROM dbo.voucher_lines          vl
    INNER JOIN dbo.vouchers         v   ON v.id  = vl.voucher_id
    INNER JOIN dbo.voucher_types    vt  ON vt.id = v.voucher_type_id
    INNER JOIN dbo.accounts         a   ON a.id  = vl.account_id
    INNER JOIN dbo.fiscal_periods   fp  ON fp.id = v.fiscal_period_id
    LEFT  JOIN dbo.current_accounts ca  ON ca.id = vl.current_account_id
    LEFT  JOIN dbo.cost_centers     cc  ON cc.id = vl.cost_center_id
    LEFT  JOIN dbo.projects         pr  ON pr.id = vl.project_id
    WHERE v.company_id     = @company_id
      AND v.fiscal_year_id = @fiscal_year_id
      AND v.posting_date BETWEEN @start_date AND @end_date
      AND v.status        <> N'IPTAL'
      AND (@account_code_like IS NULL OR a.code LIKE @account_code_like)
),
-- ---- 3. Satır bazında kümülatif bakiye ---------------------------------
numbered AS (
    SELECT
        pl.*,
        ROW_NUMBER() OVER (PARTITION BY pl.account_id ORDER BY pl.posting_date, pl.journal_sequence_no, pl.line_no) AS rn
    FROM period_lines pl
),
cumulative AS (
    SELECT
        n.*,
        COALESCE(o.ob_debit_kurus,  0) AS ob_debit_kurus,
        COALESCE(o.ob_credit_kurus, 0) AS ob_credit_kurus,
        -- kümülatif borç / alacak
        SUM(n.debit_kurus)  OVER (PARTITION BY n.account_id ORDER BY n.posting_date, n.journal_sequence_no, n.line_no
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            + COALESCE(o.ob_debit_kurus, 0)  AS cum_debit_kurus,
        SUM(n.credit_kurus) OVER (PARTITION BY n.account_id ORDER BY n.posting_date, n.journal_sequence_no, n.line_no
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            + COALESCE(o.ob_credit_kurus, 0) AS cum_credit_kurus
    FROM numbered n
    LEFT JOIN opening o ON o.account_id = n.account_id
)
-- ---- 4. Final çıktı ----------------------------------------------------
SELECT
    c.account_code,
    c.account_name,
    c.normal_balance,
    -- Dönem başı bakiyesi
    CAST(c.ob_debit_kurus  AS DECIMAL(18,2)) / 100  AS ob_debit,
    CAST(c.ob_credit_kurus AS DECIMAL(18,2)) / 100  AS ob_credit,
    CASE c.normal_balance
         WHEN N'B' THEN CAST((c.ob_debit_kurus - c.ob_credit_kurus) AS DECIMAL(18,2)) / 100
         ELSE NULL END                              AS ob_debit_balance,
    CASE c.normal_balance
         WHEN N'A' THEN CAST((c.ob_credit_kurus - c.ob_debit_kurus) AS DECIMAL(18,2)) / 100
         ELSE NULL END                              AS ob_credit_balance,
    -- Satır bilgileri
    c.posting_date,
    c.period_no,
    c.journal_sequence_no,
    c.voucher_no,
    c.voucher_type_code,
    c.document_date,
    c.source_document_no,
    c.line_description,
    c.current_account_code,
    c.current_account_title,
    c.cost_center_code,
    c.project_code,
    c.currency_code,
    c.foreign_amount,
    c.exchange_rate,
    -- Hareket
    CAST(c.debit_kurus  AS DECIMAL(18,2)) / 100 AS debit_amount,
    CAST(c.credit_kurus AS DECIMAL(18,2)) / 100 AS credit_amount,
    -- Kümülatif bakiye
    CAST(c.cum_debit_kurus  AS DECIMAL(18,2)) / 100 AS cum_debit,
    CAST(c.cum_credit_kurus AS DECIMAL(18,2)) / 100 AS cum_credit,
    CASE c.normal_balance
         WHEN N'B' THEN CAST((c.cum_debit_kurus - c.cum_credit_kurus) AS DECIMAL(18,2)) / 100
         ELSE NULL END                              AS running_debit_balance,
    CASE c.normal_balance
         WHEN N'A' THEN CAST((c.cum_credit_kurus - c.cum_debit_kurus) AS DECIMAL(18,2)) / 100
         ELSE NULL END                              AS running_credit_balance
FROM cumulative c
ORDER BY c.account_code, c.posting_date, c.journal_sequence_no, c.line_no;
