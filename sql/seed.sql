INSERT OR IGNORE INTO companies (id, code, legal_name, tax_number, tax_office, is_active)
VALUES (1, 'DEFAULT', 'Ornek Ticaret A.S.', '1234567890', 'Kadikoy', 1);

INSERT OR IGNORE INTO fiscal_years (id, company_id, fiscal_year, year_code, start_date, end_date, is_closed)
VALUES (1, 1, 2026, '2026', '2026-01-01', '2026-12-31', 0);

INSERT OR IGNORE INTO fiscal_periods (id, company_id, fiscal_year_id, period_no, period_name, start_date, end_date, is_closed, is_locked)
VALUES
(1,1,1,1,'2026-01','2026-01-01','2026-01-31',0,0),
(2,1,1,2,'2026-02','2026-02-01','2026-02-28',0,0),
(3,1,1,3,'2026-03','2026-03-01','2026-03-31',0,0),
(4,1,1,4,'2026-04','2026-04-01','2026-04-30',0,0);

INSERT OR IGNORE INTO voucher_types (id, code, name) VALUES
(1, 'MAHSUP', 'Mahsup Fisi'),
(2, 'TAHSIL', 'Tahsil Fisi'),
(3, 'TEDIYE', 'Tediye Fisi');

INSERT OR IGNORE INTO current_account_types (id, code, name) VALUES
(1, 'ALICI', 'Alici'),
(2, 'SATICI', 'Satici');

INSERT OR IGNORE INTO accounts (id, company_id, code, name, account_class, account_type, normal_balance, is_detail, is_active) VALUES
(1,1,'100','Kasa','1','asset','B',1,1),
(2,1,'102','Bankalar','1','asset','B',1,1),
(3,1,'120','Alicilar','1','asset','B',1,1),
(4,1,'320','Saticilar','3','liability','A',1,1),
(5,1,'391','Hesaplanan KDV','3','liability','A',1,1),
(6,1,'191','Indirilecek KDV','1','asset','B',1,1),
(7,1,'600','Yurtici Satislar','6','revenue','A',1,1),
(8,1,'621','Satilan Ticari Mallar Maliyeti','6','expense','B',1,1);

INSERT OR IGNORE INTO vat_codes (id, code, name, vat_rate, vat_direction, is_active) VALUES
(1,'KDV20_SAT','Satis KDV %20',0.20,'SATIS',1),
(2,'KDV20_ALIS','Alis KDV %20',0.20,'ALIS',1);

INSERT OR IGNORE INTO withholding_vat_codes (id, code, name, withholding_rate, is_active) VALUES
(1,'TEV_49','Tevkifat 4/9',0.4444,1);

INSERT OR IGNORE INTO stopaj_codes (id, code, name, stopaj_rate, is_active) VALUES
(1,'STP_10','Stopaj %10',0.10,1);

INSERT OR IGNORE INTO document_types (id, code, name, direction) VALUES
(1, 'SATIS_FAT', 'Satis Faturasi', 'SATIS'),
(2, 'ALIS_FAT', 'Alis Faturasi', 'ALIS');

INSERT OR IGNORE INTO system_parameters (company_id, parameter_key, parameter_value, description)
VALUES
(1, 'DEFAULT_CURRENCY', 'TRY', 'Varsayilan para birimi'),
(1, 'ALLOW_RETROACTIVE', 'false', 'Geriye donuk kayit izin parametresi');

INSERT OR IGNORE INTO regulatory_parameters (parameter_key, parameter_value, effective_date, description)
VALUES
('BA_BS_ESIK_AYLIK', '5000', '2026-01-01', 'Ba/Bs aylik esik TL');
