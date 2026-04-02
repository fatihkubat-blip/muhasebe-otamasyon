-- ============================================================
-- V006: e-Belge, e-Defter, KDV Beyanı, Stok Hareketi,
--        Cari Kapatma, Kur Farkı Tabloları
-- Şartname Bölüm 13, 14, 12, 16.4, 10.4
-- ============================================================

SET NOCOUNT ON;
GO

-- --------------------------------------------------------
-- e-Belge Takip (e_document_tracking)  — §13
-- --------------------------------------------------------
CREATE TABLE dbo.e_document_tracking (
    id                  INT           IDENTITY(1,1)  NOT NULL,
    company_id          INT                          NOT NULL,
    document_header_id  INT                          NULL,
    -- GİB belge tipi §13.2
    e_doc_type          NVARCHAR(20)                 NOT NULL
                            CONSTRAINT chk_edt_type CHECK (
                                e_doc_type IN ('EFATURA','EARSIV','EIRSALIYE',
                                               'ESMM','EMM','EGIDER_PUSULASI','DIGER')
                            ),
    -- GİB UUID
    uuid                NVARCHAR(36)                 NULL,
    -- Doküman numarası (GİB formatı)
    document_no         NVARCHAR(20)                 NULL,
    current_account_id  INT                          NULL,
    direction           NVARCHAR(10)                 NOT NULL
                            CONSTRAINT chk_edt_dir CHECK (direction IN ('GIDEN','GELEN')),
    issue_date          DATETIME2(3)                 NULL,
    -- Durum §13.2
    status              NVARCHAR(25)                 NOT NULL  DEFAULT 'TASLAK'
                            CONSTRAINT chk_edt_status CHECK (
                                status IN ('TASLAK','HAZIR','IMZAYA_HAZIR','GONDERILDI',
                                           'KABUL','RED','IPTAL','HATA',
                                           'TEKRAR_GONDERIM_BEKLIYOR','ARSIVLENDI')
                            ),
    -- XML içerik (şifreli veya referans)
    xml_content         NVARCHAR(MAX)                NULL,
    xml_storage_ref     NVARCHAR(500)                NULL,
    -- Gönderim/yanıt
    sent_at             DATETIME2(3)                 NULL,
    response_date       DATETIME2(3)                 NULL,
    response_code       NVARCHAR(10)                 NULL,
    response_description NVARCHAR(500)               NULL,
    -- İptal
    cancel_reason       NVARCHAR(300)                NULL,
    cancelled_at        DATETIME2(3)                 NULL,
    cancelled_by        INT                          NULL,
    -- Hata logu
    error_description   NVARCHAR(1000)               NULL,
    retry_count         TINYINT                      NOT NULL  DEFAULT 0,
    -- Kağıt yedek §13.7
    paper_backup_ref    NVARCHAR(100)                NULL,
    created_at          DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by          INT                          NULL,
    updated_at          DATETIME2(3)                 NULL,
    updated_by          INT                          NULL,
    row_version         ROWVERSION                   NOT NULL,
    CONSTRAINT pk_e_document_tracking         PRIMARY KEY (id),
    CONSTRAINT fk_edt_company                 FOREIGN KEY (company_id)       REFERENCES dbo.companies(id),
    CONSTRAINT fk_edt_document_header         FOREIGN KEY (document_header_id) REFERENCES dbo.document_headers(id),
    CONSTRAINT fk_edt_current_account         FOREIGN KEY (current_account_id) REFERENCES dbo.current_accounts(id)
);
GO

-- --------------------------------------------------------
-- e-Defter Dönemi (e_ledger_periods)  — §14
-- --------------------------------------------------------
CREATE TABLE dbo.e_ledger_periods (
    id                   INT           IDENTITY(1,1)  NOT NULL,
    company_id           INT                          NOT NULL,
    fiscal_period_id     INT                          NOT NULL,
    ledger_type          NVARCHAR(20)                 NOT NULL
                             CONSTRAINT chk_elp_type CHECK (
                                 ledger_type IN ('YEVMIYE','BUYUK_DEFTER')
                             ),
    status               NVARCHAR(20)                 NOT NULL  DEFAULT 'BEKLIYOR'
                             CONSTRAINT chk_elp_status CHECK (
                                 status IN ('BEKLIYOR','KAYIT_DOGRULANDI',
                                            'SIRA_KONTROL_OK','DOSYA_URETILDI',
                                            'BERAT_URETILDI','IMZALANDI',
                                            'GIB_YUKLENDI','GIB_KABUL','GIB_RED','HATA')
                             ),
    xml_file_path        NVARCHAR(500)                NULL,
    berat_file_path      NVARCHAR(500)                NULL,
    gib_upload_date      DATETIME2(3)                 NULL,
    gib_response_code    NVARCHAR(20)                 NULL,
    gib_response_message NVARCHAR(500)                NULL,
    voucher_count        INT                          NULL,
    line_count           INT                          NULL,
    first_journal_seq    BIGINT                       NULL,
    last_journal_seq     BIGINT                       NULL,
    -- Yükleme son tarihi §14.3
    deadline_date        DATE                         NULL,
    created_at           DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by           INT                          NULL,
    updated_at           DATETIME2(3)                 NULL,
    updated_by           INT                          NULL,
    row_version          ROWVERSION                   NOT NULL,
    CONSTRAINT pk_e_ledger_periods         PRIMARY KEY (id),
    CONSTRAINT fk_elp_company              FOREIGN KEY (company_id)      REFERENCES dbo.companies(id),
    CONSTRAINT fk_elp_fiscal_period        FOREIGN KEY (fiscal_period_id) REFERENCES dbo.fiscal_periods(id),
    CONSTRAINT uq_e_ledger_periods         UNIQUE (company_id, fiscal_period_id, ledger_type)
);
GO

-- --------------------------------------------------------
-- KDV Dönem Özeti (vat_periods)  — §12
-- --------------------------------------------------------
CREATE TABLE dbo.vat_periods (
    id                 INT           IDENTITY(1,1)  NOT NULL,
    company_id         INT                          NOT NULL,
    fiscal_period_id   INT                          NOT NULL,
    vat_type           NVARCHAR(20)                 NOT NULL  DEFAULT 'STANDART'
                           CONSTRAINT chk_vp_type CHECK (
                               vat_type IN ('STANDART','OZELMATRAH','TEVKIFATLI')
                           ),
    total_vat_base     DECIMAL(18,2)                NOT NULL  DEFAULT 0,
    total_vat_amount   DECIMAL(18,2)                NOT NULL  DEFAULT 0,
    deducted_vat       DECIMAL(18,2)                NOT NULL  DEFAULT 0,
    calculated_vat     DECIMAL(18,2)                NOT NULL  DEFAULT 0,
    payable_vat        DECIMAL(18,2)                NOT NULL  DEFAULT 0,
    refundable_vat     DECIMAL(18,2)                NOT NULL  DEFAULT 0,
    status             NVARCHAR(20)                 NOT NULL  DEFAULT 'TASLAK'
                           CONSTRAINT chk_vp_status CHECK (
                               status IN ('TASLAK','ONAYLANDI','BEYAN_EDILDI')
                           ),
    created_at         DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by         INT                          NULL,
    updated_at         DATETIME2(3)                 NULL,
    updated_by         INT                          NULL,
    CONSTRAINT pk_vat_periods          PRIMARY KEY (id),
    CONSTRAINT fk_vp_company           FOREIGN KEY (company_id)      REFERENCES dbo.companies(id),
    CONSTRAINT fk_vp_fiscal_period     FOREIGN KEY (fiscal_period_id) REFERENCES dbo.fiscal_periods(id),
    CONSTRAINT uq_vat_periods          UNIQUE (company_id, fiscal_period_id, vat_type)
);
GO

-- --------------------------------------------------------
-- Stok Hareketi (inventory_movements)  — §16.4
-- --------------------------------------------------------
CREATE TABLE dbo.inventory_movements (
    id                  INT           IDENTITY(1,1)  NOT NULL,
    company_id          INT                          NOT NULL,
    inventory_item_id   INT                          NOT NULL,
    warehouse_id        INT                          NULL,
    movement_type       NVARCHAR(20)                 NOT NULL
                            CONSTRAINT chk_im_type CHECK (
                                movement_type IN ('ALIS','SATIS','ALIS_IADE','SATIS_IADE',
                                                  'SAYIM','FIRE','SARF','URETIM_CIKIS',
                                                  'TRANSFER_CIKIS','TRANSFER_GIRIS',
                                                  'MALIYET_KAPANIS')
                            ),
    movement_date       DATE                         NOT NULL,
    quantity            DECIMAL(18,4)                NOT NULL,
    unit_cost           DECIMAL(18,6)                NULL,
    total_cost_kurus    BIGINT                       NULL,
    document_id         INT                          NULL,
    voucher_id          INT                          NULL,
    notes               NVARCHAR(300)                NULL,
    created_at          DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by          INT                          NULL,
    CONSTRAINT pk_inventory_movements              PRIMARY KEY (id),
    CONSTRAINT fk_im_company                       FOREIGN KEY (company_id)        REFERENCES dbo.companies(id),
    CONSTRAINT fk_im_inventory_item                FOREIGN KEY (inventory_item_id) REFERENCES dbo.inventory_items(id),
    CONSTRAINT fk_im_warehouse                     FOREIGN KEY (warehouse_id)      REFERENCES dbo.warehouses(id),
    CONSTRAINT fk_im_document                      FOREIGN KEY (document_id)       REFERENCES dbo.document_headers(id),
    CONSTRAINT fk_im_voucher                       FOREIGN KEY (voucher_id)        REFERENCES dbo.vouchers(id)
);
GO

-- --------------------------------------------------------
-- Cari Kapatma / Eşleştirme (current_account_closings) — §10.4
-- --------------------------------------------------------
CREATE TABLE dbo.current_account_closings (
    id                  INT           IDENTITY(1,1)  NOT NULL,
    company_id          INT                          NOT NULL,
    current_account_id  INT                          NOT NULL,
    closing_date        DATE                         NOT NULL,
    closing_type        NVARCHAR(20)                 NOT NULL  DEFAULT 'MANUEL'
                            CONSTRAINT chk_cac_type CHECK (
                                closing_type IN ('OTOMATIK','MANUEL','KISMI')
                            ),
    debit_voucher_line_id  INT                       NOT NULL,   -- borç satırı
    credit_voucher_line_id INT                       NOT NULL,   -- alacak satırı
    matched_amount_kurus   BIGINT                    NOT NULL,
    currency_code          NVARCHAR(3)               NOT NULL  DEFAULT 'TRY',
    -- Kur farkı fişi §18.4
    exchange_diff_voucher_id INT                     NULL,
    notes               NVARCHAR(300)                NULL,
    created_at          DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by          INT                          NULL,
    CONSTRAINT pk_ca_closings              PRIMARY KEY (id),
    CONSTRAINT fk_cac_company              FOREIGN KEY (company_id)          REFERENCES dbo.companies(id),
    CONSTRAINT fk_cac_current_account      FOREIGN KEY (current_account_id)  REFERENCES dbo.current_accounts(id),
    CONSTRAINT fk_cac_debit_line           FOREIGN KEY (debit_voucher_line_id)  REFERENCES dbo.voucher_lines(id),
    CONSTRAINT fk_cac_credit_line          FOREIGN KEY (credit_voucher_line_id) REFERENCES dbo.voucher_lines(id),
    CONSTRAINT fk_cac_diff_voucher         FOREIGN KEY (exchange_diff_voucher_id) REFERENCES dbo.vouchers(id)
);
GO
