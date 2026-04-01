-- ============================================================
-- 001_create_schema.sql
-- VUK uyumlu muhasebe çekirdeği — temel tablolar
-- ============================================================

-- Uzantılar
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------
-- Firma (Company)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS company (
    id            SERIAL       PRIMARY KEY,
    kod           VARCHAR(20)  NOT NULL UNIQUE,          -- kısa kod, örn. "ABC01"
    unvan         VARCHAR(255) NOT NULL,                 -- tam ticaret unvanı
    vergi_no      VARCHAR(11),                           -- 10 veya 11 haneli TCKN/VKN
    vergi_dairesi VARCHAR(100),
    adres         TEXT,
    aktif         BOOLEAN      NOT NULL DEFAULT TRUE,
    olusturma_ts  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    guncelleme_ts TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  company              IS 'Firmalar';
COMMENT ON COLUMN company.kod          IS 'Kısa firma kodu';
COMMENT ON COLUMN company.vergi_no     IS 'Vergi Kimlik No (10 hane) veya TCKN (11 hane)';

-- ------------------------------------------------------------
-- Mali Dönem (Fiscal Period)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fiscal_period (
    id           SERIAL      PRIMARY KEY,
    company_id   INT         NOT NULL REFERENCES company(id) ON DELETE RESTRICT,
    tanim        VARCHAR(100) NOT NULL,                  -- örn. "2024 Yılı"
    baslangic    DATE        NOT NULL,
    bitis        DATE        NOT NULL,
    is_closed    BOOLEAN     NOT NULL DEFAULT FALSE,     -- kapalı dönemde işlem yapılamaz
    olusturma_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    guncelleme_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fp_tarih_sirasi CHECK (bitis > baslangic),
    CONSTRAINT fp_uniq UNIQUE (company_id, baslangic, bitis)
);

COMMENT ON TABLE  fiscal_period           IS 'Mali dönemler';
COMMENT ON COLUMN fiscal_period.is_closed IS 'TRUE ise bu döneme ait fiş ekleme/güncelleme/silme engellenir';

-- ------------------------------------------------------------
-- Hesap Planı (Chart of Accounts)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS account (
    id           SERIAL       PRIMARY KEY,
    company_id   INT          NOT NULL REFERENCES company(id) ON DELETE RESTRICT,
    hesap_kodu   VARCHAR(20)  NOT NULL,                 -- örn. "100", "102.01"
    hesap_adi    VARCHAR(255) NOT NULL,
    hesap_turu   VARCHAR(10)  NOT NULL                  -- 'AKTIF','PASIF','GELİR','GİDER','NAZIM'
                              CHECK (hesap_turu IN ('AKTİF','PASİF','GELİR','GİDER','NAZIM')),
    ust_hesap_id INT          REFERENCES account(id) ON DELETE RESTRICT,
    aktif        BOOLEAN      NOT NULL DEFAULT TRUE,
    olusturma_ts TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    guncelleme_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT acc_uniq UNIQUE (company_id, hesap_kodu)
);

COMMENT ON TABLE  account             IS 'Hesap planı';
COMMENT ON COLUMN account.hesap_kodu  IS 'Tekdüzen hesap kodu (THP)';
COMMENT ON COLUMN account.hesap_turu  IS 'AKTİF | PASİF | GELİR | GİDER | NAZIM';

-- ------------------------------------------------------------
-- Yevmiye Fişi (Journal Entry)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS journal_entry (
    id              SERIAL       PRIMARY KEY,
    company_id      INT          NOT NULL REFERENCES company(id)      ON DELETE RESTRICT,
    period_id       INT          NOT NULL REFERENCES fiscal_period(id) ON DELETE RESTRICT,
    fis_no          VARCHAR(30)  NOT NULL,               -- fiş numarası
    fis_tarihi      DATE         NOT NULL,
    aciklama        TEXT,
    kaynak          VARCHAR(50),                         -- 'MANUEL','OTOM' vb.
    olusturma_ts    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    guncelleme_ts   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT je_uniq UNIQUE (company_id, fis_no)
);

COMMENT ON TABLE  journal_entry          IS 'Yevmiye fişleri';
COMMENT ON COLUMN journal_entry.fis_no   IS 'Fiş numarası (şirket bazında benzersiz)';

-- ------------------------------------------------------------
-- Fiş Satırı (Journal Line)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS journal_line (
    id               SERIAL         PRIMARY KEY,
    entry_id         INT            NOT NULL REFERENCES journal_entry(id) ON DELETE CASCADE,
    account_id       INT            NOT NULL REFERENCES account(id)       ON DELETE RESTRICT,
    borclu           NUMERIC(18,2)  NOT NULL DEFAULT 0 CHECK (borclu  >= 0),
    alacakli         NUMERIC(18,2)  NOT NULL DEFAULT 0 CHECK (alacakli >= 0),
    aciklama         TEXT,
    sira_no          SMALLINT       NOT NULL DEFAULT 1,
    olusturma_ts     TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    guncelleme_ts    TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    -- Aynı satırda hem borç hem alacak > 0 olamaz
    CONSTRAINT jl_tek_taraf CHECK (NOT (borclu > 0 AND alacakli > 0))
);

COMMENT ON TABLE  journal_line           IS 'Yevmiye fişi satırları (borç/alacak)';
COMMENT ON COLUMN journal_line.borclu    IS 'Borç tutarı — negatif olamaz';
COMMENT ON COLUMN journal_line.alacakli  IS 'Alacak tutarı — negatif olamaz';
