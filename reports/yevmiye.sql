-- ============================================================
-- yevmiye.sql — Fiş Sırasıyla Satır Dökümü
-- ============================================================
-- Parametreler:
--   :p_company_id  — firma ID
--   :p_baslangic   — başlangıç tarihi (dahil)
--   :p_bitis       — bitiş tarihi (dahil)
-- ============================================================

SELECT
    je.fis_tarihi,
    je.fis_no,
    je.aciklama                 AS fis_aciklama,
    jl.sira_no,
    a.hesap_kodu,
    a.hesap_adi,
    jl.borclu,
    jl.alacakli,
    jl.aciklama                 AS satir_aciklama
FROM journal_entry je
JOIN journal_line  jl ON jl.entry_id   = je.id
JOIN account        a ON a.id          = jl.account_id
WHERE je.company_id   = :p_company_id
  AND je.fis_tarihi  BETWEEN :p_baslangic AND :p_bitis
ORDER BY je.fis_tarihi, je.fis_no, jl.sira_no;
