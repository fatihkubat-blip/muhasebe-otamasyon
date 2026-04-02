-- Yevmiye defteri: belirli tarih araligindaki tum fiş satirlari.
SELECT
    voucher_no,
    voucher_type,
    posting_date,
    line_no,
    account_code,
    account_name,
    line_description,
    ROUND(debit_kurus / 100.0, 2) AS debit,
    ROUND(credit_kurus / 100.0, 2) AS credit
FROM vw_journal_entries
WHERE posting_date BETWEEN :start_date AND :end_date
ORDER BY posting_date, voucher_no, line_no;

-- Buyuk defter: tek bir hesabin hareketleri.
SELECT
    v.posting_date,
    v.voucher_no,
    vt.code AS voucher_type,
    COALESCE(vl.description, v.description) AS line_description,
    ROUND(vl.debit_kurus / 100.0, 2) AS debit,
    ROUND(vl.credit_kurus / 100.0, 2) AS credit
FROM voucher_lines vl
INNER JOIN vouchers v ON v.id = vl.voucher_id
INNER JOIN voucher_types vt ON vt.id = v.voucher_type_id
INNER JOIN accounts a ON a.id = vl.account_id
WHERE a.code = :account_code
  AND v.posting_date BETWEEN :start_date AND :end_date
ORDER BY v.posting_date, v.voucher_no, vl.line_no;

-- Donem mizani: donem basi, hareket ve donem sonu bakiyeleri.
SELECT
    a.code AS account_code,
    a.name AS account_name,
    ROUND(MAX(opening_balance, 0) / 100.0, 2) AS opening_debit,
    ROUND(ABS(MIN(opening_balance, 0)) / 100.0, 2) AS opening_credit,
    ROUND(period_debit / 100.0, 2) AS period_debit,
    ROUND(period_credit / 100.0, 2) AS period_credit,
    ROUND(MAX(closing_balance, 0) / 100.0, 2) AS closing_debit,
    ROUND(ABS(MIN(closing_balance, 0)) / 100.0, 2) AS closing_credit
FROM (
    SELECT
        a.id,
        a.code,
        a.name,
        COALESCE(SUM(CASE WHEN v.posting_date < :start_date THEN vl.debit_kurus - vl.credit_kurus ELSE 0 END), 0) AS opening_balance,
        COALESCE(SUM(CASE WHEN v.posting_date BETWEEN :start_date AND :end_date THEN vl.debit_kurus ELSE 0 END), 0) AS period_debit,
        COALESCE(SUM(CASE WHEN v.posting_date BETWEEN :start_date AND :end_date THEN vl.credit_kurus ELSE 0 END), 0) AS period_credit,
        COALESCE(SUM(CASE WHEN v.posting_date <= :end_date THEN vl.debit_kurus - vl.credit_kurus ELSE 0 END), 0) AS closing_balance
    FROM accounts a
    LEFT JOIN voucher_lines vl ON vl.account_id = a.id
    LEFT JOIN vouchers v ON v.id = vl.voucher_id
    GROUP BY a.id, a.code, a.name
) t
INNER JOIN accounts a ON a.id = t.id
WHERE opening_balance <> 0
   OR period_debit <> 0
   OR period_credit <> 0
ORDER BY account_code;
