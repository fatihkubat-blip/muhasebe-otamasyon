-- ============================================================
-- mizan.sql — Hesap Bazında Borç/Alacak Toplamları ve Bakiye
-- ============================================================
-- Parametreler (psql \set veya uygulama katmanıyla geçilir):
--   :p_company_id  — firma ID
--   :p_baslangic   — başlangıç tarihi (dahil), örn. '2024-01-01'
--   :p_bitis       — bitiş tarihi (dahil),    örn. '2024-12-31'
-- ============================================================

SELECT
    a.hesap_kodu,
    a.hesap_adi,
    a.hesap_turu,
    COALESCE(SUM(jl.borclu),   0)                              AS toplam_borclu,
    COALESCE(SUM(jl.alacakli), 0)                              AS toplam_alacakli,
    COALESCE(SUM(jl.borclu), 0) - COALESCE(SUM(jl.alacakli), 0) AS bakiye
FROM account a
LEFT JOIN journal_line  jl ON jl.account_id = a.id
LEFT JOIN journal_entry je ON je.id = jl.entry_id
                           AND je.company_id = :p_company_id
                           AND je.fis_tarihi BETWEEN :p_baslangic AND :p_bitis
WHERE a.company_id = :p_company_id
  AND a.aktif = TRUE
GROUP BY a.hesap_kodu, a.hesap_adi, a.hesap_turu
ORDER BY a.hesap_kodu;
