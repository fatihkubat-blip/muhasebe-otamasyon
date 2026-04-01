-- ============================================================
-- buyuk_defter.sql — Seçilen Hesap İçin Hareket Dökümü + Koşan Bakiye
-- ============================================================
-- Parametreler:
--   :p_company_id  — firma ID
--   :p_hesap_kodu  — hesap kodu, örn. '102'
--   :p_baslangic   — başlangıç tarihi (dahil)
--   :p_bitis       — bitiş tarihi (dahil)
-- ============================================================

WITH hareketler AS (
    SELECT
        je.fis_tarihi,
        je.fis_no,
        je.aciklama                          AS fis_aciklama,
        jl.aciklama                          AS satir_aciklama,
        jl.borclu,
        jl.alacakli
    FROM journal_line  jl
    JOIN journal_entry je ON je.id = jl.entry_id
    JOIN account        a ON a.id  = jl.account_id
    WHERE a.company_id   = :p_company_id
      AND a.hesap_kodu   = :p_hesap_kodu
      AND je.fis_tarihi BETWEEN :p_baslangic AND :p_bitis
)
SELECT
    fis_tarihi,
    fis_no,
    fis_aciklama,
    satir_aciklama,
    borclu,
    alacakli,
    SUM(borclu - alacakli) OVER (
        ORDER BY fis_tarihi, fis_no
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS kosan_bakiye
FROM hareketler
ORDER BY fis_tarihi, fis_no;
