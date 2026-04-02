-- ============================================================
-- SEED: Tek Düzen Hesap Planı 1./2./3. Seviye (VUK/MSUGT)
-- Şartname §7 (9 sınıf zorunluluğu)
-- ============================================================

SET NOCOUNT ON;
GO

-- Para Birimleri
INSERT INTO dbo.currencies (code, name, symbol, decimal_places) VALUES
('TRY','Türk Lirası','₺',2),
('USD','Amerikan Doları','$',2),
('EUR','Euro','€',2),
('GBP','İngiliz Sterlini','£',2),
('CHF','İsviçre Frangı','₣',2),
('JPY','Japon Yeni','¥',0),
('SAR','Suudi Arabistan Riyali','﷼',2),
('AED','BAE Dirhemi','د.إ',2),
('CNY','Çin Yuanı','¥',2);
GO

-- Kur Tipleri
INSERT INTO dbo.exchange_rate_types (code, name, description) VALUES
('TCMB_ALIS',  'TCMB Döviz Alış',     'T.C. Merkez Bankası döviz alış kuru'),
('TCMB_SATIS', 'TCMB Döviz Satış',    'T.C. Merkez Bankası döviz satış kuru'),
('TCMB_EFT',   'TCMB Efektif Alış',   'T.C. Merkez Bankası efektif alış kuru'),
('MANUEL',     'Manuel Kur',          'Kullanıcı tarafından girilen kur');
GO

-- Fiş Tipleri (§8.2)
INSERT INTO dbo.voucher_types (code, name, category, numbering_prefix, requires_approval) VALUES
('ACILIS',          'Açılış Fişi',                    'MUHASEBE',  'ACL', 0),
('MAHSUP',          'Mahsup Fişi',                    'MUHASEBE',  'MHS', 0),
('TAHSIL',          'Tahsil Fişi',                    'KASA',      'TAH', 0),
('TEDIYE',          'Tediye Fişi',                    'KASA',      'TED', 0),
('BANKA_TAHSIL',    'Banka Tahsil Fişi',              'BANKA',     'BTH', 0),
('BANKA_TEDIYE',    'Banka Tediye Fişi',              'BANKA',     'BTD', 0),
('KUR_FARKI',       'Kur Farkı Fişi',                 'MUHASEBE',  'KRF', 0),
('AMORTIS',         'Amortisman Fişi',                'MUHASEBE',  'AMR', 0),
('REESKONT',        'Reeskont Fişi',                  'MUHASEBE',  'RES', 0),
('ENFLASYON',       'Enflasyon Düzeltme Fişi',        'MUHASEBE',  'ENF', 1),
('DUZELTME',        'Düzeltme Fişi',                  'MUHASEBE',  'DUZ', 1),
('TERS_KAYIT',      'Ters Kayıt Fişi',                'MUHASEBE',  'TRS', 1),
('ENTEGRASYON',     'Entegrasyon Fişi',               'ENTEGRASYON','ENT',0),
('MALIYET_DAGITIM', 'Maliyet Dağıtım Fişi',           'MUHASEBE',  'MAL', 1),
('PERSONEL',        'Personel/Bordro Entegrasyon Fişi','ENTEGRASYON','PRS',0),
('DEVIR',           'Devir Fişi',                     'MUHASEBE',  'DEV', 1),
('KAPANIS',         'Kapanış Fişi',                   'MUHASEBE',  'KPN', 1);
GO

-- Belge Tipleri (§11.1)
INSERT INTO dbo.document_types (code, name, direction, e_document_type, generates_voucher) VALUES
('SATIS_FAT',   'Satış Faturası',               'SATIS', 'EFATURA',    1),
('SATIS_IADE',  'Satış İade Faturası',           'SATIS', 'EFATURA',    1),
('SATIS_EARSIV','e-Arşiv Fatura',               'SATIS', 'EARSIV',     1),
('ALIS_FAT',    'Alış Faturası',                'ALIS',  'EFATURA',    1),
('ALIS_IADE',   'Alış İade Faturası',            'ALIS',  'EFATURA',    1),
('IRSALIYE',    'Sevk İrsaliyesi',              'SATIS', 'EIRSALIYE',  0),
('PROFORMA',    'Proforma Fatura',              'SATIS', NULL,          0),
('GIDER_PUS',   'Gider Pusulası',               'ALIS',  'EGIDER_PUSULASI',1),
('SMM',         'Serbest Meslek Makbuzu',        'ALIS',  'ESMM',       1),
('MUSTAHSIL',   'Müstahsil Makbuzu',            'ALIS',  'EMM',        1),
('FIYAT_FARKI', 'Fiyat Farkı Faturası',         'SATIS', 'EFATURA',    1),
('MASRAF_YAN',  'Masraf Yansıtma Faturası',      'SATIS', 'EFATURA',    1);
GO

-- Cari Hesap Türleri (§10.1)
INSERT INTO dbo.current_account_types (code, name) VALUES
('ALICI',       'Alıcı'),
('SATICI',      'Satıcı'),
('PERSONEL',    'Personel'),
('ORTAK',       'Ortak / Hissedar'),
('BAGLISTR',    'Bağlı Şirket / İştirak'),
('RESMI',       'Resmi Kurum'),
('BANKA_DIS',   'Banka Dışı Finans Kuruluşu'),
('MASRAF_TED',  'Masraf Tedarikçisi'),
('SMM_ERB',     'Serbest Meslek Erbabı'),
('CIFTCI',      'Çiftçi / Müstahsil'),
('IHRACAT',     'İhracat / Yurt Dışı Müşteri'),
('DIGER',       'Diğer');
GO

-- KDV Kodları (§12.3)
INSERT INTO dbo.vat_codes (code, name, vat_rate, vat_direction, valid_from,
                            deducted_vat_account, calculated_vat_account) VALUES
('KDV1_ALIS',   'Alış KDV %1',           0.0100, 'ALIS',    '2024-01-01', '191', '391'),
('KDV10_ALIS',  'Alış KDV %10',          0.1000, 'ALIS',    '2024-07-01', '191', '391'),
('KDV20_ALIS',  'Alış KDV %20',          0.2000, 'ALIS',    '2024-07-01', '191', '391'),
('KDV1_SAT',    'Satış KDV %1',          0.0100, 'SATIS',   '2024-01-01', '191', '391'),
('KDV10_SAT',   'Satış KDV %10',         0.1000, 'SATIS',   '2024-07-01', '191', '391'),
('KDV20_SAT',   'Satış KDV %20',         0.2000, 'SATIS',   '2024-07-01', '191', '391'),
('KDV0_IHR',    'İhracat İstisna KDV',   0.0000, 'IHRACAT', '2024-01-01', '191', '391'),
('KDV_ISTISNA', 'KDV İstisnalı',         0.0000, 'ISTISNA', '2024-01-01', '191', '391'),
('TEVKIF_24_9', 'Tevkifatlı KDV (4/9)',  0.2000, 'TEVKIFATLI','2024-01-01','191','391');
GO

-- Tevkifat Kodları
INSERT INTO dbo.withholding_vat_codes (code, name, withholding_rate, valid_from) VALUES
('TEV_49',  'Tevkifat 4/9 (Hizmet)',    0.4444, '2024-01-01'),
('TEV_59',  'Tevkifat 5/9 (Yapı)',      0.5556, '2024-01-01'),
('TEV_79',  'Tevkifat 7/9 (Temizlik)',  0.7778, '2024-01-01'),
('TEV_99',  'Tevkifat 9/9 (Tam)',       1.0000, '2024-01-01');
GO

-- Stopaj Kodları
INSERT INTO dbo.stopaj_codes (code, name, stopaj_rate, income_type, valid_from) VALUES
('STP94_10','Serbest Meslek %10',       0.1000, 'Serbest Meslek Kazancı',  '2024-01-01'),
('STP94_20','Kira Geliri %20',          0.2000, 'Gayrimenkul Kira',        '2024-01-01'),
('STP94_15','Çiftçi Ödemeleri %15',     0.1500, 'Zirai Ödeme',             '2024-01-01'),
('STP94_17','Müstahsil Makbuz %17',     0.1700, 'Müstahsil Ödemesi',       '2024-01-01');
GO

-- Mevzuat Parametreleri (§6.2)
INSERT INTO dbo.regulatory_parameters (param_key, param_value, description, legal_source, valid_from) VALUES
('EFATURA_ZORUNLU_CİRO',    '3000000', 'e-Fatura zorunluluk cirosu (TL)', 'GİB 2024 güncel eşik', '2024-01-01'),
('EARSIV_ZORUNLU_TUTAR',    '5000',    'e-Arşiv tek fatura tutarı (TL)', 'GİB 2024', '2024-01-01'),
('EDEFTER_ZORUNLU_CİRO',    '3000000', 'e-Defter zorunluluk cirosu (TL)', 'GİB 2024', '2024-01-01'),
('BA_BS_ESIK_AYLIK',        '5000',    'BA/BS beyan eşiği aylık (TL)', 'GİB 2024', '2024-01-01'),
('VUK_MUHAFAZA_SURE_YIL',   '5',       'VUK 253: Defter/Belge muhafaza süresi (yıl)', 'VUK Md.253', '2024-01-01'),
('REESKONT_FAIZ_ORANI',     '0.2000',  'Yıllık reeskont faiz oranı', 'TCMB 2024', '2024-01-01'),
('GECIKME_FAIZ_ORANI',      '0.0150',  'VUK gecikme faizi aylık oran', 'VUK 2024', '2024-01-01'),
('AGI_BEKARSIZ_TL',         '9300',    'AGİ bekar kişi (TL/yıl)', '2024 AGİ Tablosu', '2024-01-01');
GO

-- ==========================================================
-- TEK DÜZEN HESAP PLANI - 1. Dönen Varlıklar
-- ==========================================================
DECLARE @co INT;
SELECT @co = id FROM dbo.companies WHERE code = 'DEFAULT';
IF @co IS NULL BEGIN
    INSERT INTO dbo.companies (code, legal_name, tax_number)
    VALUES ('DEFAULT','Varsayılan Şirket','0000000001');
    SET @co = SCOPE_IDENTITY();
END;

INSERT INTO dbo.accounts (company_id, code, name, account_class, account_type, normal_balance, level, is_summary_account) VALUES
-- 1. SINIF - DÖNEN VARLIKLAR
(@co,'10','Hazır Değerler',                1,'asset','D',1,1),
(@co,'100','Kasa',                         1,'asset','D',2,0),
(@co,'101','Alınan Çekler',               1,'asset','D',2,0),
(@co,'102','Bankalar',                    1,'asset','D',2,0),
(@co,'103','Verilen Çekler ve Ödeme Emirleri',1,'asset','A',2,0),
(@co,'108','Diğer Hazır Değerler',        1,'asset','D',2,0),

(@co,'11','Menkul Kıymetler',             1,'asset','D',1,1),
(@co,'110','Hisse Senetleri',             1,'asset','D',2,0),
(@co,'111','Özel Kesim Tahvil Senet ve Bonoları',1,'asset','D',2,0),
(@co,'112','Kamu Kesimi Tahvil Senet ve Bonoları',1,'asset','D',2,0),
(@co,'118','Diğer Menkul Kıymetler',      1,'asset','D',2,0),
(@co,'119','Menkul Kıymetler Değer Düşüklüğü Karşılığı',1,'asset','A',2,0),

(@co,'12','Ticari Alacaklar',             1,'asset','D',1,1),
(@co,'120','Alıcılar',                    1,'asset','D',2,0),
(@co,'121','Alacak Senetleri',            1,'asset','D',2,0),
(@co,'122','Alacak Senetleri Reeskontu',  1,'asset','A',2,0),
(@co,'126','Verilen Depozito ve Teminatlar',1,'asset','D',2,0),
(@co,'127','Diğer Ticari Alacaklar',      1,'asset','D',2,0),
(@co,'128','Şüpheli Ticari Alacaklar',    1,'asset','D',2,0),
(@co,'129','Şüpheli Ticari Alacaklar Karşılığı',1,'asset','A',2,0),

(@co,'13','Diğer Alacaklar',              1,'asset','D',1,1),
(@co,'131','Ortaklardan Alacaklar',       1,'asset','D',2,0),
(@co,'132','İştiraklerden Alacaklar',     1,'asset','D',2,0),
(@co,'133','Bağlı Ortaklıklardan Alacaklar',1,'asset','D',2,0),
(@co,'135','Personelden Alacaklar',       1,'asset','D',2,0),
(@co,'136','Diğer Çeşitli Alacaklar',     1,'asset','D',2,0),
(@co,'137','Diğer Alacak Senetleri Reeskontu',1,'asset','A',2,0),
(@co,'138','Şüpheli Diğer Alacaklar',     1,'asset','D',2,0),
(@co,'139','Şüpheli Diğer Alacaklar Karşılığı',1,'asset','A',2,0),

(@co,'15','Stoklar',                      1,'asset','D',1,1),
(@co,'150','İlk Madde ve Malzeme',        1,'asset','D',2,0),
(@co,'151','Yarı Mamul-Üretim',           1,'asset','D',2,0),
(@co,'152','Mamuller',                    1,'asset','D',2,0),
(@co,'153','Ticari Mallar',               1,'asset','D',2,0),
(@co,'157','Diğer Stoklar',               1,'asset','D',2,0),
(@co,'158','Stok Değer Düşüklüğü Karşılığı',1,'asset','A',2,0),
(@co,'159','Verilen Sipariş Avansları',   1,'asset','D',2,0),

(@co,'18','Gelecek Aylara Ait Giderler ve Gelir Tahakkukları',1,'asset','D',1,1),
(@co,'180','Gelecek Aylara Ait Giderler', 1,'asset','D',2,0),
(@co,'181','Gelir Tahakkukları',          1,'asset','D',2,0),

(@co,'19','Diğer Dönen Varlıklar',        1,'asset','D',1,1),
(@co,'190','Devreden KDV',                1,'asset','D',2,0),
(@co,'191','İndirilecek KDV',             1,'asset','D',2,0),
(@co,'192','Diğer KDV',                   1,'asset','D',2,0),
(@co,'193','Peşin Ödenen Vergiler ve Fonlar',1,'asset','D',2,0),
(@co,'194','Tek Düzen Hesap Çerçevesi Dışı',1,'asset','D',2,0),
(@co,'195','İş Avansları',                1,'asset','D',2,0),
(@co,'196','Personel Avansları',          1,'asset','D',2,0),
(@co,'197','Sayım ve Tesellüm Noksanları',1,'asset','D',2,0),
(@co,'198','Diğer Çeşitli Dönen Varlıklar',1,'asset','D',2,0),
(@co,'199','Diğer Dönen Varlıklar Karşılığı',1,'asset','A',2,0),

-- 2. SINIF - DURAN VARLIKLAR
(@co,'22','Ticari Alacaklar (Duran)',     2,'asset','D',1,1),
(@co,'220','Alıcılar',                    2,'asset','D',2,0),
(@co,'221','Alacak Senetleri',            2,'asset','D',2,0),
(@co,'222','Alacak Senetleri Reeskontu',  2,'asset','A',2,0),
(@co,'226','Verilen Depozito ve Teminatlar',2,'asset','D',2,0),
(@co,'229','Şüpheli Ticari Alacaklar Karşılığı',2,'asset','A',2,0),

(@co,'25','Mali Duran Varlıklar',         2,'asset','D',1,1),
(@co,'250','Bağlı Menkul Kıymetler',      2,'asset','D',2,0),
(@co,'251','Bağlı Menkul Kıymetler Değer Düşüklüğü Karşılığı',2,'asset','A',2,0),
(@co,'252','İştirakler',                  2,'asset','D',2,0),
(@co,'253','İştirakler Sermaye Taahhütleri',2,'asset','A',2,0),
(@co,'254','Bağlı Ortaklıklar',           2,'asset','D',2,0),
(@co,'255','Bağlı Ortaklıklar Sermaye Taahhütleri',2,'asset','A',2,0),
(@co,'258','Yapılmakta Olan Yatırımlar',  2,'asset','D',2,0),
(@co,'259','Verilen Avanslar',            2,'asset','D',2,0),

(@co,'26','Maddi Duran Varlıklar',        2,'asset','D',1,1),
(@co,'260','Arazi ve Arsalar',            2,'asset','D',2,0),
(@co,'261','Yeraltı ve Yerüstü Düzenleri',2,'asset','D',2,0),
(@co,'262','Binalar',                     2,'asset','D',2,0),
(@co,'263','Tesis Makine ve Cihazlar',    2,'asset','D',2,0),
(@co,'264','Taşıtlar',                    2,'asset','D',2,0),
(@co,'265','Demirbaşlar',                 2,'asset','D',2,0),
(@co,'266','Diğer Maddi Duran Varlıklar', 2,'asset','D',2,0),
(@co,'267','Birikmiş Amortismanlar',      2,'asset','A',2,0),
(@co,'268','Yapılmakta Olan Yatırımlar',  2,'asset','D',2,0),
(@co,'269','Verilen Avanslar',            2,'asset','D',2,0),

(@co,'27','Maddi Olmayan Duran Varlıklar',2,'asset','D',1,1),
(@co,'270','Haklar',                      2,'asset','D',2,0),
(@co,'271','Şerefiye',                    2,'asset','D',2,0),
(@co,'272','Kuruluş ve Örgütlenme Giderleri',2,'asset','D',2,0),
(@co,'273','Araştırma ve Geliştirme Giderleri',2,'asset','D',2,0),
(@co,'274','Özel Maliyetler',             2,'asset','D',2,0),
(@co,'277','Diğer Maddi Olmayan Duran Varlıklar',2,'asset','D',2,0),
(@co,'278','Birikmiş Amortismanlar',      2,'asset','A',2,0),
(@co,'279','Verilen Avanslar',            2,'asset','D',2,0),

(@co,'29','Diğer Duran Varlıklar',        2,'asset','D',1,1),
(@co,'290','Gelecek Yıllara Ait Giderler',2,'asset','D',2,0),
(@co,'291','Gelir Tahakkukları',          2,'asset','D',2,0),
(@co,'295','Peşin Ödenen Vergiler ve Fonlar',2,'asset','D',2,0),
(@co,'297','Diğer Çeşitli Duran Varlıklar',2,'asset','D',2,0),
(@co,'298','Stok Değer Düşüklüğü Karşılığı',2,'asset','A',2,0),
(@co,'299','Birikmiş Amortismanlar',      2,'asset','A',2,0),

-- 3. SINIF - KISA VADELİ YABANCI KAYNAKLAR
(@co,'30','Mali Borçlar',                 3,'liability','A',1,1),
(@co,'300','Banka Kredileri',             3,'liability','A',2,0),
(@co,'301','Finansal Kiralama İşlemlerinden Borçlar',3,'liability','A',2,0),
(@co,'302','Ertelenmiş Finansal Kiralama Borçlanma Maliyetleri',3,'liability','D',2,0),
(@co,'303','Uzun Vadeli Kredilerin Anapara Taksitleri ve Faizleri',3,'liability','A',2,0),
(@co,'304','Tahvil Anapara Borç Taksit ve Faizleri',3,'liability','A',2,0),
(@co,'305','Çıkarılmış Bonolar ve Senetler',3,'liability','A',2,0),
(@co,'306','Çıkarılmış Diğer Menkul Kıymetler',3,'liability','A',2,0),
(@co,'308','Menkul Kıymetler İhraç Farkı',3,'liability','D',2,0),
(@co,'309','Diğer Mali Borçlar',          3,'liability','A',2,0),

(@co,'32','Ticari Borçlar',               3,'liability','A',1,1),
(@co,'320','Satıcılar',                   3,'liability','A',2,0),
(@co,'321','Borç Senetleri',              3,'liability','A',2,0),
(@co,'322','Borç Senetleri Reeskontu',    3,'liability','D',2,0),
(@co,'326','Alınan Depozito ve Teminatlar',3,'liability','A',2,0),
(@co,'329','Diğer Ticari Borçlar',        3,'liability','A',2,0),

(@co,'33','Diğer Borçlar',                3,'liability','A',1,1),
(@co,'331','Ortaklara Borçlar',           3,'liability','A',2,0),
(@co,'332','İştiraklere Borçlar',         3,'liability','A',2,0),
(@co,'333','Bağlı Ortaklıklara Borçlar',  3,'liability','A',2,0),
(@co,'335','Personele Borçlar',           3,'liability','A',2,0),
(@co,'336','Diğer Çeşitli Borçlar',       3,'liability','A',2,0),
(@co,'337','Diğer Borç Senetleri Reeskontu',3,'liability','D',2,0),

(@co,'34','Alınan Avanslar',              3,'liability','A',1,1),
(@co,'340','Alınan Sipariş Avansları',    3,'liability','A',2,0),
(@co,'349','Alınan Diğer Avanslar',       3,'liability','A',2,0),

(@co,'36','Ödenecek Vergi ve Yükümlülükler',3,'liability','A',1,1),
(@co,'360','Ödenecek Vergi ve Fonlar',    3,'liability','A',2,0),
(@co,'361','Ödenecek Sosyal Güvenlik Kesintileri',3,'liability','A',2,0),
(@co,'368','Vadesi Geçmiş Ertelenmiş veya Taksitlendirilmiş Vergi',3,'liability','A',2,0),
(@co,'369','Ödenecek Diğer Yükümlülükler',3,'liability','A',2,0),

(@co,'37','Borç ve Gider Karşılıkları',   3,'liability','A',1,1),
(@co,'370','Dönem Karı Vergi ve Diğer Yasal Yükümlülük Karşılıkları',3,'liability','A',2,0),
(@co,'371','Dönem Karının Peşin Ödenen Vergi ve Diğer Yükümlülükleri',3,'liability','D',2,0),
(@co,'372','Kıdem Tazminatı Karşılığı',   3,'liability','A',2,0),
(@co,'373','Maliyet Giderleri Karşılığı', 3,'liability','A',2,0),
(@co,'379','Diğer Borç ve Gider Karşılıkları',3,'liability','A',2,0),

(@co,'38','Gelecek Aylara Ait Gelirler ve Gider Tahakkukları',3,'liability','A',1,1),
(@co,'380','Gelecek Aylara Ait Gelirler', 3,'liability','A',2,0),
(@co,'381','Gider Tahakkukları',          3,'liability','A',2,0),

(@co,'39','Diğer Kısa Vadeli Yabancı Kaynaklar',3,'liability','A',1,1),
(@co,'391','Hesaplanan KDV',              3,'liability','A',2,0),
(@co,'392','Diğer KDV',                   3,'liability','A',2,0),
(@co,'393','Merkez ve Şubeler Cari Hesabı',3,'liability','A',2,0),
(@co,'397','Sayım ve Tesellüm Fazlaları', 3,'liability','A',2,0),
(@co,'399','Diğer Çeşitli Kısa Vadeli Yabancı Kaynaklar',3,'liability','A',2,0),

-- 4. SINIF - UZUN VADELİ YABANCI KAYNAKLAR
(@co,'40','Mali Borçlar (Uzun Vadeli)',   4,'liability','A',1,1),
(@co,'400','Banka Kredileri',             4,'liability','A',2,0),
(@co,'401','Finansal Kiralama İşlemlerinden Borçlar',4,'liability','A',2,0),
(@co,'405','Çıkarılmış Tahviller',        4,'liability','A',2,0),
(@co,'407','Çıkarılmış Diğer Menkul Kıymetler',4,'liability','A',2,0),
(@co,'409','Diğer Mali Borçlar',          4,'liability','A',2,0),

(@co,'42','Ticari Borçlar (Uzun Vadeli)', 4,'liability','A',1,1),
(@co,'420','Satıcılar',                   4,'liability','A',2,0),
(@co,'421','Borç Senetleri',              4,'liability','A',2,0),
(@co,'422','Borç Senetleri Reeskontu',    4,'liability','D',2,0),
(@co,'426','Alınan Depozito ve Teminatlar',4,'liability','A',2,0),
(@co,'429','Diğer Ticari Borçlar',        4,'liability','A',2,0),

(@co,'44','Alınan Avanslar (Uzun Vadeli)',4,'liability','A',1,1),
(@co,'440','Alınan Sipariş Avansları',    4,'liability','A',2,0),
(@co,'449','Alınan Diğer Avanslar',       4,'liability','A',2,0),

(@co,'47','Borç ve Gider Karşılıkları (Uzun Vadeli)',4,'liability','A',1,1),
(@co,'472','Kıdem Tazminatı Karşılığı',   4,'liability','A',2,0),
(@co,'479','Diğer Borç ve Gider Karşılıkları',4,'liability','A',2,0),

(@co,'48','Gelecek Yıllara Ait Gelir ve Gider Tahakkukları (Uzun Vadeli)',4,'liability','A',1,1),
(@co,'480','Gelecek Yıllara Ait Gelirler',4,'liability','A',2,0),
(@co,'481','Gider Tahakkukları',          4,'liability','A',2,0),

(@co,'49','Diğer Uzun Vadeli Yabancı Kaynaklar',4,'liability','A',1,1),
(@co,'492','Kıdem Tazminatı Karşılığı',   4,'liability','A',2,0),
(@co,'499','Diğer Çeşitli Uzun Vadeli Yabancı Kaynaklar',4,'liability','A',2,0),

-- 5. SINIF - ÖZ KAYNAKLAR
(@co,'50','Ödenmiş Sermaye',              5,'equity','A',1,1),
(@co,'500','Sermaye',                     5,'equity','A',2,0),
(@co,'501','Ödenmemiş Sermaye',           5,'equity','D',2,0),

(@co,'52','Sermaye Yedekleri',            5,'equity','A',1,1),
(@co,'520','Hisse Senedi İhraç Primleri', 5,'equity','A',2,0),
(@co,'521','Hisse Senedi İptal Kârları',  5,'equity','A',2,0),
(@co,'524','Maddi Duran Varlık Yeniden Değerleme Artışları',5,'equity','A',2,0),
(@co,'529','Diğer Sermaye Yedekleri',     5,'equity','A',2,0),

(@co,'54','Kâr Yedekleri',                5,'equity','A',1,1),
(@co,'540','Yasal Yedekler',              5,'equity','A',2,0),
(@co,'541','Statü Yedekleri',             5,'equity','A',2,0),
(@co,'542','Olağanüstü Yedekler',         5,'equity','A',2,0),
(@co,'548','Diğer Kâr Yedekleri',         5,'equity','A',2,0),
(@co,'549','Özel Fonlar',                 5,'equity','A',2,0),

(@co,'57','Geçmiş Yıllar Kârları',        5,'equity','A',1,1),
(@co,'570','Geçmiş Yıllar Kârları',       5,'equity','A',2,0),

(@co,'58','Geçmiş Yıllar Zararları',      5,'equity','D',1,1),
(@co,'580','Geçmiş Yıllar Zararları',     5,'equity','D',2,0),

(@co,'59','Dönem Net Kârı/Zararı',        5,'equity','B',1,1),
(@co,'590','Dönem Net Kârı',              5,'equity','A',2,0),
(@co,'591','Dönem Net Zararı',            5,'equity','D',2,0),

-- 6. SINIF - GELİR TABLOSU HESAPLARI
(@co,'60','Brüt Satışlar',                6,'revenue','A',1,1),
(@co,'600','Yurt İçi Satışlar',           6,'revenue','A',2,0),
(@co,'601','Yurt Dışı Satışlar',          6,'revenue','A',2,0),
(@co,'602','Diğer Gelirler',              6,'revenue','A',2,0),

(@co,'61','Satış İndirimleri(-)',         6,'revenue','D',1,1),
(@co,'610','Satıştan İadeler',            6,'revenue','D',2,0),
(@co,'611','Satış İskontoları',           6,'revenue','D',2,0),
(@co,'612','Diğer İndirimler',            6,'revenue','D',2,0),

(@co,'62','Satışların Maliyeti(-)',       6,'expense','D',1,1),
(@co,'620','Satılan Mamüller Maliyeti',   6,'expense','D',2,0),
(@co,'621','Satılan Ticari Mallar Maliyeti',6,'expense','D',2,0),
(@co,'622','Satılan Hizmet Maliyeti',     6,'expense','D',2,0),
(@co,'623','Diğer Satışların Maliyeti',   6,'expense','D',2,0),

(@co,'63','Faaliyet Giderleri',           6,'expense','D',1,1),
(@co,'630','Araştırma ve Geliştirme Giderleri',6,'expense','D',2,0),
(@co,'631','Pazarlama Satış ve Dağıtım Giderleri',6,'expense','D',2,0),
(@co,'632','Genel Yönetim Giderleri',     6,'expense','D',2,0),

(@co,'64','Diğer Faaliyetlerden Olağan Gelir ve Kârlar',6,'revenue','A',1,1),
(@co,'640','İştiraklerden Temettü Gelirleri',6,'revenue','A',2,0),
(@co,'641','Bağlı Ortaklıklardan Temettü Gelirleri',6,'revenue','A',2,0),
(@co,'642','Faiz Gelirleri',              6,'revenue','A',2,0),
(@co,'643','Komisyon Gelirleri',          6,'revenue','A',2,0),
(@co,'644','Konusu Kalmayan Karşılıklar', 6,'revenue','A',2,0),
(@co,'645','Menkul Kıymet Satış Kârları', 6,'revenue','A',2,0),
(@co,'646','Kambiyo Kârları',             6,'revenue','A',2,0),
(@co,'647','Reeskont Faiz Gelirleri',     6,'revenue','A',2,0),
(@co,'648','Enflasyon Düzeltmesi Kârları',6,'revenue','A',2,0),
(@co,'649','Diğer Olağan Gelir ve Kârlar',6,'revenue','A',2,0),

(@co,'65','Diğer Faaliyetlerden Olağan Gider ve Zararlar',6,'expense','D',1,1),
(@co,'653','Komisyon Giderleri',          6,'expense','D',2,0),
(@co,'654','Karşılık Giderleri',          6,'expense','D',2,0),
(@co,'655','Menkul Kıymet Satış Zararları',6,'expense','D',2,0),
(@co,'656','Kambiyo Zararları',           6,'expense','D',2,0),
(@co,'657','Reeskont Faiz Giderleri',     6,'expense','D',2,0),
(@co,'658','Enflasyon Düzeltmesi Zararları',6,'expense','D',2,0),
(@co,'659','Diğer Olağan Gider ve Zararlar',6,'expense','D',2,0),

(@co,'67','Olağandışı Gelir ve Kârlar',   6,'revenue','A',1,1),
(@co,'671','Önceki Dönem Gelir ve Kârları',6,'revenue','A',2,0),
(@co,'679','Diğer Olağandışı Gelir ve Kârlar',6,'revenue','A',2,0),

(@co,'68','Olağandışı Gider ve Zararlar', 6,'expense','D',1,1),
(@co,'680','Çalışmayan Kısım Gider ve Zararları',6,'expense','D',2,0),
(@co,'681','Önceki Dönem Gider ve Zararları',6,'expense','D',2,0),
(@co,'689','Diğer Olağandışı Gider ve Zararlar',6,'expense','D',2,0),

(@co,'69','Dönem Net Kârı veya Zararı',   6,'expense','D',1,1),
(@co,'690','Dönem Kârı veya Zararı',      6,'expense','B',2,0),
(@co,'691','Dönem Kârı Vergi ve Diğer Yasal Yükümlülük Karşılıkları',6,'expense','D',2,0),
(@co,'692','Dönem Net Kârı veya Zararı',  6,'expense','B',2,0),

-- 7. SINIF - MALİYET HESAPLARI
(@co,'71','Direkt İlk Madde ve Malzeme Giderleri',7,'expense','D',1,1),
(@co,'710','Direkt İlk Madde ve Malzeme Giderleri',7,'expense','D',2,0),
(@co,'711','Direkt İlk Madde ve Malzeme Yansıtma Hesabı',7,'expense','A',2,0),
(@co,'712','Direkt İlk Madde ve Malzeme Fiyat Farkı',7,'expense','D',2,0),

(@co,'72','Direkt İşçilik Giderleri',     7,'expense','D',1,1),
(@co,'720','Direkt İşçilik Giderleri',    7,'expense','D',2,0),
(@co,'721','Direkt İşçilik Giderleri Yansıtma Hesabı',7,'expense','A',2,0),
(@co,'722','Direkt İşçilik Ücret Farkları',7,'expense','D',2,0),

(@co,'73','Genel Üretim Giderleri',       7,'expense','D',1,1),
(@co,'730','Genel Üretim Giderleri',      7,'expense','D',2,0),
(@co,'731','Genel Üretim Giderleri Yansıtma Hesabı',7,'expense','A',2,0),
(@co,'732','Genel Üretim Giderleri Bütçe Farkı',7,'expense','D',2,0),
(@co,'733','Genel Üretim Giderleri Verimlilik Farkı',7,'expense','D',2,0),
(@co,'734','Genel Üretim Giderleri Kapasite Farkı',7,'expense','D',2,0),

(@co,'74','Hizmet Üretim Maliyeti',       7,'expense','D',1,1),
(@co,'740','Hizmet Üretim Maliyeti',      7,'expense','D',2,0),
(@co,'741','Hizmet Üretim Maliyeti Yansıtma Hesabı',7,'expense','A',2,0),

(@co,'75','Araştırma ve Geliştirme Giderleri',7,'expense','D',1,1),
(@co,'750','Araştırma ve Geliştirme Giderleri',7,'expense','D',2,0),
(@co,'751','Araştırma ve Geliştirme Giderleri Yansıtma Hesabı',7,'expense','A',2,0),

(@co,'76','Pazarlama Satış ve Dağıtım Giderleri',7,'expense','D',1,1),
(@co,'760','Pazarlama Satış ve Dağıtım Giderleri',7,'expense','D',2,0),
(@co,'761','Pazarlama Satış ve Dağıtım Giderleri Yansıtma Hesabı',7,'expense','A',2,0),

(@co,'77','Genel Yönetim Giderleri',      7,'expense','D',1,1),
(@co,'770','Genel Yönetim Giderleri',     7,'expense','D',2,0),
(@co,'771','Genel Yönetim Giderleri Yansıtma Hesabı',7,'expense','A',2,0),

(@co,'78','Finansman Giderleri',          7,'expense','D',1,1),
(@co,'780','Finansman Giderleri',         7,'expense','D',2,0),
(@co,'781','Finansman Giderleri Yansıtma Hesabı',7,'expense','A',2,0),

(@co,'79','Gider Çeşitlerinden Fonksiyonlara Yansıtılan Giderler',7,'expense','A',1,1),
(@co,'790','İlk Madde ve Malzeme Giderleri Yansıtma',7,'expense','A',2,0),
(@co,'791','İşçilik Giderleri Yansıtma', 7,'expense','A',2,0),
(@co,'792','Memur Maaşları Yansıtma',     7,'expense','A',2,0),
(@co,'793','Dışarıdan Sağlanan Fayda Hizmetler Yansıtma',7,'expense','A',2,0),
(@co,'794','Çeşitli Giderler Yansıtma',  7,'expense','A',2,0),
(@co,'795','Vergi Resim Harçlar Yansıtma',7,'expense','A',2,0),
(@co,'796','Amortisman ve Tükenme Payları Yansıtma',7,'expense','A',2,0),
(@co,'797','Finansman Giderleri Yansıtma',7,'expense','A',2,0),

-- 9. SINIF - NAZIM HESAPLAR
(@co,'90','Taahhütler',                   9,'off_balance','D',1,1),
(@co,'900','Verilen Taahhütler',          9,'off_balance','D',2,0),
(@co,'901','Verilen Taahhütler Karşıtı', 9,'off_balance','A',2,0),
(@co,'91','Kefalet ve Garantiler',        9,'off_balance','D',1,1),
(@co,'910','Bankadan Alınan Teminat Mektupları',9,'off_balance','D',2,0),
(@co,'911','Bankadan Alınan Teminat Mektupları Karşıtı',9,'off_balance','A',2,0);
GO
