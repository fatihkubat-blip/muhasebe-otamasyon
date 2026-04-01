-- ============================================================
-- 001_sample_data.sql — Örnek veri (seed)
-- ============================================================

-- ------------------------------------------------------------
-- Firma
-- ------------------------------------------------------------
INSERT INTO company (kod, unvan, vergi_no, vergi_dairesi, adres)
VALUES (
    'DEMO01',
    'Demo Yazılım ve Danışmanlık A.Ş.',
    '1234567890',
    'Üsküdar',
    'Atatürk Cad. No:1 İstanbul'
) ON CONFLICT (kod) DO NOTHING;

-- ------------------------------------------------------------
-- Mali Dönem — 2024
-- ------------------------------------------------------------
INSERT INTO fiscal_period (company_id, tanim, baslangic, bitis, is_closed)
SELECT id, '2024 Yılı', '2024-01-01', '2024-12-31', FALSE
  FROM company WHERE kod = 'DEMO01'
ON CONFLICT (company_id, baslangic, bitis) DO NOTHING;

-- ------------------------------------------------------------
-- Hesap Planı (THP — kısmi örnek)
-- ------------------------------------------------------------
WITH firma AS (SELECT id FROM company WHERE kod = 'DEMO01')
INSERT INTO account (company_id, hesap_kodu, hesap_adi, hesap_turu)
SELECT firma.id, kod, ad, tur
  FROM firma,
  (VALUES
    ('100', 'Kasa',                           'AKTİF'),
    ('102', 'Bankalar',                       'AKTİF'),
    ('120', 'Alıcılar',                       'AKTİF'),
    ('191', 'İndirilecek KDV',               'AKTİF'),
    ('320', 'Satıcılar',                      'PASİF'),
    ('391', 'Hesaplanan KDV',                'PASİF'),
    ('500', 'Sermaye',                        'PASİF'),
    ('600', 'Yurtiçi Satışlar',              'GELİR'),
    ('710', 'Direkt İlk Madde ve Malzeme',   'GİDER'),
    ('740', 'Hizmet Üretim Maliyeti',        'GİDER'),
    ('770', 'Genel Yönetim Giderleri',       'GİDER')
  ) AS t(kod, ad, tur)
ON CONFLICT (company_id, hesap_kodu) DO NOTHING;

-- ------------------------------------------------------------
-- Örnek Yevmiye Fişi 1 — Mal satışı + KDV
-- Müşteriden alacak doğdu, KDV hesaplandı, satış geliri oluştu
-- ------------------------------------------------------------
WITH firma  AS (SELECT id FROM company      WHERE kod = 'DEMO01'),
     donem  AS (SELECT id FROM fiscal_period
                 WHERE company_id = (SELECT id FROM firma)
                   AND baslangic  = '2024-01-01')
INSERT INTO journal_entry (company_id, period_id, fis_no, fis_tarihi, aciklama, kaynak)
SELECT firma.id, donem.id, 'YF-2024-001', '2024-01-15',
       'Müşteriye hizmet satışı (KDV dahil)', 'MANUEL'
  FROM firma, donem
ON CONFLICT (company_id, fis_no) DO NOTHING;

-- Fiş satırları
WITH entry AS (
    SELECT je.id
      FROM journal_entry je
      JOIN company c ON c.id = je.company_id
     WHERE c.kod = 'DEMO01'
       AND je.fis_no = 'YF-2024-001'
),
accts AS (
    SELECT a.hesap_kodu, a.id AS acc_id
      FROM account a
      JOIN company c ON c.id = a.company_id
     WHERE c.kod = 'DEMO01'
)
INSERT INTO journal_line (entry_id, account_id, borclu, alacakli, aciklama, sira_no)
SELECT entry.id, accts.acc_id, borclu, alacakli, aciklama, sira_no
  FROM entry,
  (VALUES
    ('120',  1180.00,    0.00, 'Alıcılar — müşteri alacağı',        1),
    ('600',     0.00, 1000.00, 'Yurtiçi Satışlar',                  2),
    ('391',     0.00,  180.00, 'Hesaplanan KDV %18',                3)
  ) AS v(kod, borclu, alacakli, aciklama, sira_no)
  JOIN accts ON accts.hesap_kodu = v.kod;

-- ------------------------------------------------------------
-- Örnek Yevmiye Fişi 2 — Bankaya tahsilat
-- Müşteri borcu tahsil edildi
-- ------------------------------------------------------------
WITH firma  AS (SELECT id FROM company      WHERE kod = 'DEMO01'),
     donem  AS (SELECT id FROM fiscal_period
                 WHERE company_id = (SELECT id FROM firma)
                   AND baslangic  = '2024-01-01')
INSERT INTO journal_entry (company_id, period_id, fis_no, fis_tarihi, aciklama, kaynak)
SELECT firma.id, donem.id, 'YF-2024-002', '2024-01-20',
       'Müşteri tahsilatı — banka', 'MANUEL'
  FROM firma, donem
ON CONFLICT (company_id, fis_no) DO NOTHING;

WITH entry AS (
    SELECT je.id
      FROM journal_entry je
      JOIN company c ON c.id = je.company_id
     WHERE c.kod = 'DEMO01'
       AND je.fis_no = 'YF-2024-002'
),
accts AS (
    SELECT a.hesap_kodu, a.id AS acc_id
      FROM account a
      JOIN company c ON c.id = a.company_id
     WHERE c.kod = 'DEMO01'
)
INSERT INTO journal_line (entry_id, account_id, borclu, alacakli, aciklama, sira_no)
SELECT entry.id, accts.acc_id, borclu, alacakli, aciklama, sira_no
  FROM entry,
  (VALUES
    ('102', 1180.00,    0.00, 'Bankalar — tahsilat',  1),
    ('120',    0.00, 1180.00, 'Alıcılar — kapatma',   2)
  ) AS v(kod, borclu, alacakli, aciklama, sira_no)
  JOIN accts ON accts.hesap_kodu = v.kod;

-- ------------------------------------------------------------
-- Örnek Yevmiye Fişi 3 — Genel yönetim gideri
-- ------------------------------------------------------------
WITH firma  AS (SELECT id FROM company      WHERE kod = 'DEMO01'),
     donem  AS (SELECT id FROM fiscal_period
                 WHERE company_id = (SELECT id FROM firma)
                   AND baslangic  = '2024-01-01')
INSERT INTO journal_entry (company_id, period_id, fis_no, fis_tarihi, aciklama, kaynak)
SELECT firma.id, donem.id, 'YF-2024-003', '2024-01-25',
       'Ofis kirası — ocak', 'MANUEL'
  FROM firma, donem
ON CONFLICT (company_id, fis_no) DO NOTHING;

WITH entry AS (
    SELECT je.id
      FROM journal_entry je
      JOIN company c ON c.id = je.company_id
     WHERE c.kod = 'DEMO01'
       AND je.fis_no = 'YF-2024-003'
),
accts AS (
    SELECT a.hesap_kodu, a.id AS acc_id
      FROM account a
      JOIN company c ON c.id = a.company_id
     WHERE c.kod = 'DEMO01'
)
INSERT INTO journal_line (entry_id, account_id, borclu, alacakli, aciklama, sira_no)
SELECT entry.id, accts.acc_id, borclu, alacakli, aciklama, sira_no
  FROM entry,
  (VALUES
    ('770',  5000.00,    0.00, 'Genel Yönetim Giderleri — kira',  1),
    ('191',   900.00,    0.00, 'İndirilecek KDV %18',              2),
    ('320',     0.00, 5900.00, 'Satıcılar — kiraya veren borç',   3)
  ) AS v(kod, borclu, alacakli, aciklama, sira_no)
  JOIN accts ON accts.hesap_kodu = v.kod;
