-- ============================================================
-- V003: Fiş Tipleri, Yevmiye Fişleri, Fiş Satırları
-- Şartname Bölüm 8 (Fiş Mantığı): tüm zorunlu alanlar + §5.4
-- ============================================================

SET NOCOUNT ON;
GO

-- --------------------------------------------------------
-- Fiş Tipi (voucher_types)
-- --------------------------------------------------------
CREATE TABLE dbo.voucher_types (
    id                INT           IDENTITY(1,1)  NOT NULL,
    code              NVARCHAR(20)                 NOT NULL,
    name              NVARCHAR(100)                NOT NULL,
    -- Gruplama: MUHASEBE / BANKA / KASA / ENTEGRASYON ...
    category          NVARCHAR(30)                 NOT NULL  DEFAULT 'MUHASEBE',
    numbering_prefix  NVARCHAR(10)                 NULL,
    auto_reverse      BIT                          NOT NULL  DEFAULT 0,
    requires_approval BIT                          NOT NULL  DEFAULT 0,
    is_active         BIT                          NOT NULL  DEFAULT 1,
    created_at        DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_voucher_types  PRIMARY KEY (id),
    CONSTRAINT uq_voucher_types  UNIQUE (code)
);
GO

-- --------------------------------------------------------
-- Yevmiye Numarası Üretici (voucher_sequences)
-- Tekil, sıralı, denetlenebilir (§8.7)
-- --------------------------------------------------------
CREATE TABLE dbo.voucher_sequences (
    id               INT           IDENTITY(1,1)  NOT NULL,
    company_id       INT                          NOT NULL,
    fiscal_year      SMALLINT                     NOT NULL,
    voucher_type_id  INT                          NOT NULL,
    last_number      BIGINT                       NOT NULL  DEFAULT 0,
    prefix           NVARCHAR(10)                 NULL,
    row_version      ROWVERSION                   NOT NULL,
    CONSTRAINT pk_voucher_sequences        PRIMARY KEY (id),
    CONSTRAINT fk_vs_company               FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT fk_vs_voucher_type          FOREIGN KEY (voucher_type_id) REFERENCES dbo.voucher_types(id),
    CONSTRAINT uq_voucher_sequences        UNIQUE (company_id, fiscal_year, voucher_type_id)
);
GO

-- --------------------------------------------------------
-- Yevmiye Fişi (vouchers)  — §8 + §5.4
-- --------------------------------------------------------
CREATE TABLE dbo.vouchers (
    id                     INT            IDENTITY(1,1)  NOT NULL,
    company_id             INT                           NOT NULL,
    branch_id              INT                           NULL,
    fiscal_year_id         INT                           NOT NULL,
    fiscal_period_id       INT                           NOT NULL,
    voucher_type_id        INT                           NOT NULL,
    -- Yevmiye sıra numarası (benzersiz, sıralı) §8.7
    journal_sequence_no    BIGINT                        NOT NULL,
    -- Kullanıcıya gösterilen fiş numarası
    voucher_no             NVARCHAR(50)                  NOT NULL,
    -- VUK 219: belge tarihi ile sistem kayıt zamanı ayrı
    document_date          DATE                          NOT NULL,
    posting_date           DATE                          NOT NULL,
    recorded_at            DATETIME2(3)                  NOT NULL  DEFAULT SYSUTCDATETIME(),
    description            NVARCHAR(500)                 NOT NULL,
    source_document_no     NVARCHAR(100)                 NULL,
    -- Modül kaynağı: MANUEL / SATIS / ALIS / BANKA / KASA / MAAS / ...
    module_source          NVARCHAR(30)                  NOT NULL  DEFAULT 'MANUEL',
    -- Toplam borç/alacak kuruş cinsinden (tutarsızlık imkânsız)
    total_debit_kurus      BIGINT                        NOT NULL  DEFAULT 0
                               CONSTRAINT chk_vouchers_debit CHECK (total_debit_kurus >= 0),
    total_credit_kurus     BIGINT                        NOT NULL  DEFAULT 0
                               CONSTRAINT chk_vouchers_credit CHECK (total_credit_kurus >= 0),
    -- DB kısıtı: borç = alacak  §8.3
    CONSTRAINT chk_vouchers_balance CHECK (total_debit_kurus = total_credit_kurus),
    -- Onay akışı §23.2
    status                 NVARCHAR(20)                  NOT NULL  DEFAULT 'TASLAK'
                               CONSTRAINT chk_vouchers_status CHECK (
                                   status IN ('TASLAK','KONTROL','ONAY_BEKLIYOR',
                                              'ONAYLANDI','IPTAL','TERS_KAYIT')
                               ),
    approved_at            DATETIME2(3)                  NULL,
    approved_by            INT                           NULL,
    cancelled_at           DATETIME2(3)                  NULL,
    cancelled_by           INT                           NULL,
    -- Ters kayıt bağlantısı §8.6
    reverse_of_id          INT                           NULL,
    reversed_by_id         INT                           NULL,
    is_reversed            BIT                           NOT NULL  DEFAULT 0,
    -- e-Defter bağı §14.5
    e_ledger_period_id     INT                           NULL,
    e_ledger_export_status NVARCHAR(20)                  NULL
                               CONSTRAINT chk_v_edl_status CHECK (
                                   e_ledger_export_status IS NULL
                                   OR e_ledger_export_status IN ('BEKLIYOR','HAZIR','YUKLENDI','HATA')
                               ),
    -- VUK 253/256 belge saklama
    document_storage_ref   NVARCHAR(500)                 NULL,
    -- Denetim
    created_at             DATETIME2(3)                  NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by             INT                           NULL,
    updated_at             DATETIME2(3)                  NULL,
    updated_by             INT                           NULL,
    row_version            ROWVERSION                    NOT NULL,
    CONSTRAINT pk_vouchers                 PRIMARY KEY (id),
    CONSTRAINT fk_vouchers_company         FOREIGN KEY (company_id)       REFERENCES dbo.companies(id),
    CONSTRAINT fk_vouchers_branch          FOREIGN KEY (branch_id)        REFERENCES dbo.branches(id),
    CONSTRAINT fk_vouchers_fiscal_year     FOREIGN KEY (fiscal_year_id)   REFERENCES dbo.fiscal_years(id),
    CONSTRAINT fk_vouchers_fiscal_period   FOREIGN KEY (fiscal_period_id) REFERENCES dbo.fiscal_periods(id),
    CONSTRAINT fk_vouchers_type            FOREIGN KEY (voucher_type_id)  REFERENCES dbo.voucher_types(id),
    CONSTRAINT fk_vouchers_reverse_of      FOREIGN KEY (reverse_of_id)   REFERENCES dbo.vouchers(id),
    CONSTRAINT fk_vouchers_reversed_by     FOREIGN KEY (reversed_by_id)  REFERENCES dbo.vouchers(id),
    CONSTRAINT uq_vouchers_no              UNIQUE (company_id, fiscal_year_id, voucher_no),
    CONSTRAINT uq_vouchers_journal_seq     UNIQUE (company_id, fiscal_year_id, journal_sequence_no)
);
GO

-- --------------------------------------------------------
-- Fiş Satırı (voucher_lines)  — §5.4 + §8.4
-- --------------------------------------------------------
CREATE TABLE dbo.voucher_lines (
    id                  INT            IDENTITY(1,1)  NOT NULL,
    voucher_id          INT                           NOT NULL,
    line_no             SMALLINT                      NOT NULL,
    -- §5.4 zorunlu alanlar
    company_id          INT                           NOT NULL,
    branch_id           INT                           NULL,
    account_id          INT                           NOT NULL,
    current_account_id  INT                           NULL,
    description         NVARCHAR(500)                 NULL,
    -- Borç / Alacak kuruş cinsinden
    debit_kurus         BIGINT                        NOT NULL  DEFAULT 0
                            CONSTRAINT chk_vl_debit CHECK (debit_kurus >= 0),
    credit_kurus        BIGINT                        NOT NULL  DEFAULT 0
                            CONSTRAINT chk_vl_credit CHECK (credit_kurus >= 0),
    -- Her satır yalnızca borç VEYA alacak içerebilir
    CONSTRAINT chk_vl_single_side CHECK (
        (debit_kurus > 0 AND credit_kurus = 0)
        OR (debit_kurus = 0 AND credit_kurus > 0)
    ),
    -- Döviz
    currency_code       NVARCHAR(3)                   NULL,
    exchange_rate       DECIMAL(18,6)                 NULL,
    foreign_amount      DECIMAL(18,4)                 NULL,
    -- Raporlama para birimi
    reporting_amount    DECIMAL(18,4)                 NULL,
    -- Vade
    due_date            DATE                          NULL,
    -- Belge referansı
    document_no         NVARCHAR(100)                 NULL,
    document_date       DATE                          NULL,
    -- Vergi
    vat_code_id         INT                           NULL,
    withholding_code_id INT                           NULL,
    stopaj_code_id      INT                           NULL,
    vat_base_kurus      BIGINT                        NULL,
    vat_amount_kurus    BIGINT                        NULL,
    -- Analitik kırılım §19
    cost_center_id      INT                           NULL,
    project_id          INT                           NULL,
    -- Miktar (analitik dağıtım için)
    quantity            DECIMAL(18,4)                 NULL,
    unit_code           NVARCHAR(10)                  NULL,
    -- Kaynak belge bağı §5.4
    source_module       NVARCHAR(30)                  NULL,
    source_document_id  INT                           NULL,
    source_line_id      INT                           NULL,
    -- Denetim §24
    created_at          DATETIME2(3)                  NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by          INT                           NULL,
    row_version         ROWVERSION                    NOT NULL,
    CONSTRAINT pk_voucher_lines          PRIMARY KEY (id),
    CONSTRAINT fk_vl_voucher             FOREIGN KEY (voucher_id)         REFERENCES dbo.vouchers(id) ON DELETE CASCADE,
    CONSTRAINT fk_vl_company             FOREIGN KEY (company_id)         REFERENCES dbo.companies(id),
    CONSTRAINT fk_vl_branch              FOREIGN KEY (branch_id)          REFERENCES dbo.branches(id),
    CONSTRAINT fk_vl_account             FOREIGN KEY (account_id)         REFERENCES dbo.accounts(id),
    CONSTRAINT fk_vl_vat_code            FOREIGN KEY (vat_code_id)        REFERENCES dbo.vat_codes(id),
    CONSTRAINT fk_vl_cost_center         FOREIGN KEY (cost_center_id)     REFERENCES dbo.cost_centers(id),
    CONSTRAINT fk_vl_project             FOREIGN KEY (project_id)         REFERENCES dbo.projects(id),
    CONSTRAINT uq_voucher_lines          UNIQUE (voucher_id, line_no)
);
GO

-- --------------------------------------------------------
-- Dönem Sonu Kapanış Kaydı (period_closing_records)  — §20
-- --------------------------------------------------------
CREATE TABLE dbo.period_closing_records (
    id                  INT           IDENTITY(1,1)  NOT NULL,
    company_id          INT                          NOT NULL,
    fiscal_period_id    INT                          NOT NULL,
    step_code           NVARCHAR(50)                 NOT NULL,
    step_name           NVARCHAR(200)                NOT NULL,
    status              NVARCHAR(20)                 NOT NULL  DEFAULT 'BEKLIYOR'
                            CONSTRAINT chk_pcr_status CHECK (
                                status IN ('BEKLIYOR','DEVAM_EDIYOR','TAMAMLANDI','HATA','ATILDI')
                            ),
    completed_at        DATETIME2(3)                 NULL,
    completed_by        INT                          NULL,
    note                NVARCHAR(1000)               NULL,
    created_at          DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by          INT                          NULL,
    CONSTRAINT pk_pcr          PRIMARY KEY (id),
    CONSTRAINT fk_pcr_company  FOREIGN KEY (company_id)      REFERENCES dbo.companies(id),
    CONSTRAINT fk_pcr_period   FOREIGN KEY (fiscal_period_id) REFERENCES dbo.fiscal_periods(id)
);
GO
