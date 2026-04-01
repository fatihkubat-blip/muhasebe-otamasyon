-- ============================================================
-- 003_views.sql
-- Yardımcı view'lar
-- ============================================================

-- ------------------------------------------------------------
-- v_fis_dengesi — her fisin borç/alacak toplamı ve dengesi
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_fis_dengesi AS
SELECT
    je.id                          AS entry_id,
    je.company_id,
    je.period_id,
    je.fis_no,
    je.fis_tarihi,
    je.aciklama,
    COALESCE(SUM(jl.borclu),   0) AS toplam_borclu,
    COALESCE(SUM(jl.alacakli), 0) AS toplam_alacakli,
    COALESCE(SUM(jl.borclu),   0)
        - COALESCE(SUM(jl.alacakli), 0) AS fark   -- 0 ise dengeli
FROM journal_entry je
LEFT JOIN journal_line jl ON jl.entry_id = je.id
GROUP BY je.id, je.company_id, je.period_id, je.fis_no, je.fis_tarihi, je.aciklama;

COMMENT ON VIEW v_fis_dengesi IS 'Her yevmiye fisinin borclu/alacakli toplamı ve denge farkı';

-- ------------------------------------------------------------
-- v_hesap_bakiye — hesap bazında toplam bakiye (tüm dönem)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_hesap_bakiye AS
SELECT
    a.company_id,
    a.hesap_kodu,
    a.hesap_adi,
    a.hesap_turu,
    COALESCE(SUM(jl.borclu),   0) AS toplam_borclu,
    COALESCE(SUM(jl.alacakli), 0) AS toplam_alacakli,
    COALESCE(SUM(jl.borclu),   0)
        - COALESCE(SUM(jl.alacakli), 0) AS net_bakiye
FROM account a
LEFT JOIN journal_line jl   ON jl.account_id = a.id
LEFT JOIN journal_entry je  ON je.id = jl.entry_id
GROUP BY a.company_id, a.hesap_kodu, a.hesap_adi, a.hesap_turu;

COMMENT ON VIEW v_hesap_bakiye IS 'Hesap planındaki her hesabın toplam borç/alacak ve net bakiyesi';
