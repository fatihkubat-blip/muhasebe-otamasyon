-- ============================================================
-- V002: Hesap Planı ve Hesap Kartları
-- Şartname Bölüm 7 (Tek Düzen Hesap Planı): tüm zorunlu alanlar
-- ============================================================

SET NOCOUNT ON;
GO

-- --------------------------------------------------------
-- Hesap Planı Şablonu (chart_of_accounts_templates)
-- Şirketler bu şablonu kopyalayarak kendi planlarını oluşturur.
-- --------------------------------------------------------
CREATE TABLE dbo.chart_of_accounts_templates (
    id           INT           IDENTITY(1,1)  NOT NULL,
    code         NVARCHAR(20)                 NOT NULL,
    name         NVARCHAR(200)                NOT NULL,
    description  NVARCHAR(500)                NULL,
    version      NVARCHAR(20)                 NOT NULL  DEFAULT '1.0',
    valid_from   DATE                         NOT NULL,
    valid_to     DATE                         NULL,
    is_default   BIT                          NOT NULL  DEFAULT 0,
    created_at   DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_coa_templates  PRIMARY KEY (id),
    CONSTRAINT uq_coa_templates  UNIQUE (code, version)
);
GO

-- --------------------------------------------------------
-- Hesap Kartı (accounts)
-- Şartname 7.3 zorunlu alanları + TFRS/BOBİ/KÜMİ eşleme
-- --------------------------------------------------------
CREATE TABLE dbo.accounts (
    id                       INT            IDENTITY(1,1)  NOT NULL,
    company_id               INT                           NOT NULL,
    code                     NVARCHAR(20)                  NOT NULL,
    name                     NVARCHAR(200)                 NOT NULL,
    short_name               NVARCHAR(50)                  NULL,
    -- 1=Dönen Varlık, 2=Duran Varlık, 3=KVYK, 4=UVYK,
    -- 5=Öz Kaynak, 6=Gelir, 7=Maliyet, 8=Serbest, 9=Nazım
    account_class            TINYINT                       NOT NULL
                                 CONSTRAINT chk_accounts_class CHECK (account_class BETWEEN 1 AND 9),
    -- asset / liability / equity / revenue / expense / off_balance
    account_type             NVARCHAR(20)                  NOT NULL
                                 CONSTRAINT chk_accounts_type CHECK (
                                     account_type IN ('asset','liability','equity',
                                                      'revenue','expense','off_balance')
                                 ),
    -- Çalışma yönü: D=Borç, A=Alacak, B=İkisi de
    normal_balance           NCHAR(1)                      NOT NULL  DEFAULT 'D'
                                 CONSTRAINT chk_accounts_normal_balance CHECK (normal_balance IN ('D','A','B')),
    parent_id                INT                           NULL,
    level                    TINYINT                       NOT NULL  DEFAULT 1
                                 CONSTRAINT chk_accounts_level CHECK (level BETWEEN 1 AND 6),
    -- Yansıtma hesabı kodu (7'li hesaplar için gider yansıtma)
    reflection_account_code  NVARCHAR(20)                  NULL,
    -- Dövizli çalışma zorunluluğu
    currency_mandatory       BIT                           NOT NULL  DEFAULT 0,
    force_currency_code      NVARCHAR(3)                   NULL,
    -- Alt hesap açılabilir mi?
    allow_sub_accounts       BIT                           NOT NULL  DEFAULT 1,
    -- Fiş satırında zorunlu kırılımlar
    cost_center_mandatory    BIT                           NOT NULL  DEFAULT 0,
    project_mandatory        BIT                           NOT NULL  DEFAULT 0,
    branch_mandatory         BIT                           NOT NULL  DEFAULT 0,
    current_account_mandatory BIT                          NOT NULL  DEFAULT 0,
    -- Vergi ilişki türü
    tax_relation_type        NVARCHAR(30)                  NULL,
    vat_code_id              INT                           NULL,
    -- Raporlama eşlemeleri
    reporting_group          NVARCHAR(50)                  NULL,
    legal_report_group       NVARCHAR(50)                  NULL,
    consolidation_group      NVARCHAR(50)                  NULL,
    -- TFRS/BOBİ/KÜMİ eşleme kodları
    tfrs_mapping_code        NVARCHAR(50)                  NULL,
    bobi_mapping_code        NVARCHAR(50)                  NULL,
    kumi_mapping_code        NVARCHAR(50)                  NULL,
    -- Bilanço / Gelir Tablosu kalemi
    financial_statement_line NVARCHAR(100)                 NULL,
    -- Hareket sınırı
    max_single_entry_amount  DECIMAL(18,2)                 NULL,   -- NULL = sınırsız
    -- Durum
    is_summary_account       BIT                           NOT NULL  DEFAULT 0,   -- özet: alt hesap açılmalı
    is_active                BIT                           NOT NULL  DEFAULT 1,
    deactivated_at           DATETIME2(3)                  NULL,
    deactivated_by           INT                           NULL,
    -- Bütünlük
    has_transactions         BIT                           NOT NULL  DEFAULT 0,   -- hareket görmüş
    created_at               DATETIME2(3)                  NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by               INT                           NULL,
    updated_at               DATETIME2(3)                  NULL,
    updated_by               INT                           NULL,
    row_version              ROWVERSION                    NOT NULL,
    CONSTRAINT pk_accounts             PRIMARY KEY (id),
    CONSTRAINT fk_accounts_company     FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT fk_accounts_parent      FOREIGN KEY (parent_id)  REFERENCES dbo.accounts(id),
    CONSTRAINT uq_accounts_code        UNIQUE (company_id, code)
);
GO

-- --------------------------------------------------------
-- Hesap Sürüm Geçmişi (accounts_history)
-- Yasal kayıt – üzerine yazma yasak, geçmiş izlenir.
-- --------------------------------------------------------
CREATE TABLE dbo.accounts_history (
    id             INT           IDENTITY(1,1)  NOT NULL,
    account_id     INT                          NOT NULL,
    changed_at     DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    changed_by     INT                          NULL,
    change_type    NVARCHAR(10)                 NOT NULL
                       CONSTRAINT chk_ah_change_type CHECK (change_type IN ('INSERT','UPDATE','DEACTIVATE')),
    field_name     NVARCHAR(100)                NULL,
    old_value      NVARCHAR(MAX)                NULL,
    new_value      NVARCHAR(MAX)                NULL,
    CONSTRAINT pk_accounts_history     PRIMARY KEY (id),
    CONSTRAINT fk_accounts_history     FOREIGN KEY (account_id) REFERENCES dbo.accounts(id)
);
GO

-- --------------------------------------------------------
-- Masraf Merkezi (cost_centers)
-- --------------------------------------------------------
CREATE TABLE dbo.cost_centers (
    id           INT           IDENTITY(1,1)  NOT NULL,
    company_id   INT                          NOT NULL,
    code         NVARCHAR(20)                 NOT NULL,
    name         NVARCHAR(200)                NOT NULL,
    parent_id    INT                          NULL,
    level        TINYINT                      NOT NULL  DEFAULT 1,
    manager_user_id INT                       NULL,
    is_active    BIT                          NOT NULL  DEFAULT 1,
    created_at   DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by   INT                          NULL,
    updated_at   DATETIME2(3)                 NULL,
    updated_by   INT                          NULL,
    row_version  ROWVERSION                   NOT NULL,
    CONSTRAINT pk_cost_centers         PRIMARY KEY (id),
    CONSTRAINT fk_cc_company           FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT fk_cc_parent            FOREIGN KEY (parent_id)  REFERENCES dbo.cost_centers(id),
    CONSTRAINT uq_cost_centers         UNIQUE (company_id, code)
);
GO

-- --------------------------------------------------------
-- Proje (projects)
-- --------------------------------------------------------
CREATE TABLE dbo.projects (
    id            INT           IDENTITY(1,1)  NOT NULL,
    company_id    INT                          NOT NULL,
    code          NVARCHAR(20)                 NOT NULL,
    name          NVARCHAR(200)                NOT NULL,
    project_type  NVARCHAR(50)                 NULL,
    start_date    DATE                         NULL,
    end_date      DATE                         NULL,
    budget_amount DECIMAL(18,2)                NULL,
    cost_center_id INT                         NULL,
    is_active     BIT                          NOT NULL  DEFAULT 1,
    created_at    DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by    INT                          NULL,
    updated_at    DATETIME2(3)                 NULL,
    updated_by    INT                          NULL,
    row_version   ROWVERSION                   NOT NULL,
    CONSTRAINT pk_projects          PRIMARY KEY (id),
    CONSTRAINT fk_projects_company  FOREIGN KEY (company_id)    REFERENCES dbo.companies(id),
    CONSTRAINT fk_projects_cc       FOREIGN KEY (cost_center_id) REFERENCES dbo.cost_centers(id),
    CONSTRAINT uq_projects          UNIQUE (company_id, code)
);
GO

-- --------------------------------------------------------
-- Vergi Kodları (tax_codes)  — genel çerçeve
-- --------------------------------------------------------
CREATE TABLE dbo.tax_codes (
    id            INT           IDENTITY(1,1)  NOT NULL,
    code          NVARCHAR(20)                 NOT NULL,
    name          NVARCHAR(100)                NOT NULL,
    tax_type      NVARCHAR(30)                 NOT NULL
                      CONSTRAINT chk_tax_codes_type CHECK (
                          tax_type IN ('KDV','TEVKIFAT','STOPAJ','DAMGA',
                                       'OTV','KV','GV','DIGER')
                      ),
    rate          DECIMAL(6,4)                 NOT NULL  DEFAULT 0,
    valid_from    DATE                         NOT NULL,
    valid_to      DATE                         NULL,
    account_code_debit   NVARCHAR(20)          NULL,
    account_code_credit  NVARCHAR(20)          NULL,
    is_active     BIT                          NOT NULL  DEFAULT 1,
    created_at    DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by    INT                          NULL,
    updated_at    DATETIME2(3)                 NULL,
    updated_by    INT                          NULL,
    CONSTRAINT pk_tax_codes    PRIMARY KEY (id),
    CONSTRAINT uq_tax_codes    UNIQUE (code, valid_from)
);
GO

-- --------------------------------------------------------
-- KDV Kodları (vat_codes)  — KDV motoru §12
-- --------------------------------------------------------
CREATE TABLE dbo.vat_codes (
    id                   INT           IDENTITY(1,1)  NOT NULL,
    code                 NVARCHAR(20)                 NOT NULL,
    name                 NVARCHAR(100)                NOT NULL,
    vat_rate             DECIMAL(6,4)                 NOT NULL,
    -- ALIS / SATIS / IHRACAT / ISTISNA / TEVKIFATLI / OIB ...
    vat_direction        NVARCHAR(20)                 NOT NULL
                             CONSTRAINT chk_vat_direction CHECK (
                                 vat_direction IN ('ALIS','SATIS','IHRACAT',
                                                   'ISTISNA','TEVKIFATLI','OZELMATRAH')
                             ),
    exemption_code       NVARCHAR(20)                 NULL,   -- GİB istisna kodu
    tevkifat_rate        DECIMAL(6,4)                 NOT NULL  DEFAULT 0,
    is_refundable        BIT                          NOT NULL  DEFAULT 0,
    valid_from           DATE                         NOT NULL,
    valid_to             DATE                         NULL,
    deducted_vat_account NVARCHAR(20)                 NULL,   -- 191 İndirilecek KDV
    calculated_vat_account NVARCHAR(20)               NULL,   -- 391 Hesaplanan KDV
    is_active            BIT                          NOT NULL  DEFAULT 1,
    created_at           DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by           INT                          NULL,
    updated_at           DATETIME2(3)                 NULL,
    updated_by           INT                          NULL,
    CONSTRAINT pk_vat_codes  PRIMARY KEY (id),
    CONSTRAINT uq_vat_codes  UNIQUE (code, valid_from)
);
GO

-- --------------------------------------------------------
-- Tevkifat Kodları (withholding_vat_codes)
-- --------------------------------------------------------
CREATE TABLE dbo.withholding_vat_codes (
    id               INT           IDENTITY(1,1)  NOT NULL,
    code             NVARCHAR(20)                 NOT NULL,
    name             NVARCHAR(200)                NOT NULL,
    withholding_rate DECIMAL(6,4)                 NOT NULL,
    valid_from       DATE                         NOT NULL,
    valid_to         DATE                         NULL,
    is_active        BIT                          NOT NULL  DEFAULT 1,
    created_at       DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_withholding_vat  PRIMARY KEY (id),
    CONSTRAINT uq_withholding_vat  UNIQUE (code, valid_from)
);
GO

-- --------------------------------------------------------
-- Stopaj Kodları (stopaj_codes)
-- --------------------------------------------------------
CREATE TABLE dbo.stopaj_codes (
    id            INT           IDENTITY(1,1)  NOT NULL,
    code          NVARCHAR(20)                 NOT NULL,
    name          NVARCHAR(200)                NOT NULL,
    stopaj_rate   DECIMAL(6,4)                 NOT NULL,
    income_type   NVARCHAR(100)                NULL,   -- kazanç türü açıklaması
    valid_from    DATE                         NOT NULL,
    valid_to      DATE                         NULL,
    is_active     BIT                          NOT NULL  DEFAULT 1,
    created_at    DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_stopaj_codes  PRIMARY KEY (id),
    CONSTRAINT uq_stopaj_codes  UNIQUE (code, valid_from)
);
GO
