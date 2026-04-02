-- ============================================================
-- V004: Belge Başlık / Satır, Cari Hesap, Stok, Sabit Kıymet
-- Şartname Bölüm 10, 11, 16, 17
-- ============================================================

SET NOCOUNT ON;
GO

-- --------------------------------------------------------
-- Belge Tipi (document_types)  — §11
-- --------------------------------------------------------
CREATE TABLE dbo.document_types (
    id                       INT           IDENTITY(1,1)  NOT NULL,
    code                     NVARCHAR(20)                 NOT NULL,
    name                     NVARCHAR(100)                NOT NULL,
    direction                NVARCHAR(10)                 NOT NULL   -- SATIS / ALIS / DIGER
                                 CONSTRAINT chk_dt_direction CHECK (direction IN ('SATIS','ALIS','DIGER')),
    e_document_type          NVARCHAR(30)                 NULL,      -- EFATURA/EARSIV/EIRSALIYE...
    generates_voucher        BIT                          NOT NULL  DEFAULT 1,
    accounting_rule_template NVARCHAR(100)                NULL,
    sequence_prefix          NVARCHAR(10)                 NULL,
    is_active                BIT                          NOT NULL  DEFAULT 1,
    created_at               DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_document_types  PRIMARY KEY (id),
    CONSTRAINT uq_document_types  UNIQUE (code)
);
GO

-- --------------------------------------------------------
-- Stok Kategorisi (inventory_categories)
-- --------------------------------------------------------
CREATE TABLE dbo.inventory_categories (
    id          INT           IDENTITY(1,1)  NOT NULL,
    company_id  INT                          NOT NULL,
    code        NVARCHAR(20)                 NOT NULL,
    name        NVARCHAR(100)                NOT NULL,
    parent_id   INT                          NULL,
    is_active   BIT                          NOT NULL  DEFAULT 1,
    created_at  DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_inventory_categories        PRIMARY KEY (id),
    CONSTRAINT fk_invc_company                FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT fk_invc_parent                 FOREIGN KEY (parent_id)  REFERENCES dbo.inventory_categories(id),
    CONSTRAINT uq_inventory_categories        UNIQUE (company_id, code)
);
GO

-- --------------------------------------------------------
-- Depo (warehouses)
-- --------------------------------------------------------
CREATE TABLE dbo.warehouses (
    id          INT           IDENTITY(1,1)  NOT NULL,
    company_id  INT                          NOT NULL,
    branch_id   INT                          NULL,
    code        NVARCHAR(20)                 NOT NULL,
    name        NVARCHAR(100)                NOT NULL,
    is_active   BIT                          NOT NULL  DEFAULT 1,
    created_at  DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_warehouses         PRIMARY KEY (id),
    CONSTRAINT fk_warehouses_company FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT fk_warehouses_branch  FOREIGN KEY (branch_id)  REFERENCES dbo.branches(id),
    CONSTRAINT uq_warehouses         UNIQUE (company_id, code)
);
GO

-- --------------------------------------------------------
-- Stok Kartı (inventory_items)  — §16.2
-- --------------------------------------------------------
CREATE TABLE dbo.inventory_items (
    id                  INT           IDENTITY(1,1)  NOT NULL,
    company_id          INT                          NOT NULL,
    category_id         INT                          NULL,
    code                NVARCHAR(30)                 NOT NULL,
    name                NVARCHAR(200)                NOT NULL,
    barcode             NVARCHAR(50)                 NULL,
    item_type           NVARCHAR(10)                 NOT NULL  DEFAULT 'MAMUL'
                            CONSTRAINT chk_inv_type CHECK (
                                item_type IN ('MAMUL','HAMMADDE','YARIMAMUL',
                                              'TICARI_MAL','SARF','DIGER')
                            ),
    unit_code           NVARCHAR(10)                 NOT NULL,
    vat_code_id         INT                          NULL,
    -- Maliyet yöntemi §16.3
    costing_method      NVARCHAR(20)                 NOT NULL  DEFAULT 'HAREKETLI_ORT'
                            CONSTRAINT chk_inv_cost_method CHECK (
                                costing_method IN ('HAREKETLI_ORT','AGIRLIKLI_ORT','FIFO')
                            ),
    -- Muhasebe hesap eşlemesi
    purchase_account    NVARCHAR(20)                 NULL,
    sales_account       NVARCHAR(20)                 NULL,
    cogs_account        NVARCHAR(20)                 NULL,
    inventory_account   NVARCHAR(20)                 NULL,
    is_active           BIT                          NOT NULL  DEFAULT 1,
    created_at          DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by          INT                          NULL,
    updated_at          DATETIME2(3)                 NULL,
    updated_by          INT                          NULL,
    row_version         ROWVERSION                   NOT NULL,
    CONSTRAINT pk_inventory_items         PRIMARY KEY (id),
    CONSTRAINT fk_inv_company             FOREIGN KEY (company_id)  REFERENCES dbo.companies(id),
    CONSTRAINT fk_inv_category            FOREIGN KEY (category_id) REFERENCES dbo.inventory_categories(id),
    CONSTRAINT uq_inventory_items         UNIQUE (company_id, code)
);
GO

-- --------------------------------------------------------
-- Hizmet Kartı (service_items)  — §16.5
-- --------------------------------------------------------
CREATE TABLE dbo.service_items (
    id                INT           IDENTITY(1,1)  NOT NULL,
    company_id        INT                          NOT NULL,
    code              NVARCHAR(30)                 NOT NULL,
    name              NVARCHAR(200)                NOT NULL,
    unit_code         NVARCHAR(10)                 NULL,
    vat_code_id       INT                          NULL,
    revenue_account   NVARCHAR(20)                 NULL,
    expense_account   NVARCHAR(20)                 NULL,
    is_active         BIT                          NOT NULL  DEFAULT 1,
    created_at        DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by        INT                          NULL,
    updated_at        DATETIME2(3)                 NULL,
    updated_by        INT                          NULL,
    row_version       ROWVERSION                   NOT NULL,
    CONSTRAINT pk_service_items         PRIMARY KEY (id),
    CONSTRAINT fk_svc_company           FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT uq_service_items         UNIQUE (company_id, code)
);
GO

-- --------------------------------------------------------
-- Cari Hesap Kategorisi (current_account_types)
-- --------------------------------------------------------
CREATE TABLE dbo.current_account_types (
    id    INT           IDENTITY(1,1)  NOT NULL,
    code  NVARCHAR(20)                 NOT NULL,
    name  NVARCHAR(100)                NOT NULL,
    CONSTRAINT pk_current_account_types  PRIMARY KEY (id),
    CONSTRAINT uq_current_account_types  UNIQUE (code)
);
GO

-- --------------------------------------------------------
-- Cari Hesap Kartı (current_accounts)  — §10
-- --------------------------------------------------------
CREATE TABLE dbo.current_accounts (
    id                     INT           IDENTITY(1,1)  NOT NULL,
    company_id             INT                          NOT NULL,
    type_id                INT                          NOT NULL,
    code                   NVARCHAR(30)                 NOT NULL,
    title                  NVARCHAR(200)                NOT NULL,
    -- Kimlik bilgileri
    tax_number             NVARCHAR(11)                 NULL,   -- VKN/TCKN
    tax_office             NVARCHAR(100)                NULL,
    mersis_no              NVARCHAR(20)                 NULL,
    trade_register_no      NVARCHAR(50)                 NULL,
    -- İletişim
    address                NVARCHAR(500)                NULL,
    city                   NVARCHAR(100)                NULL,
    district               NVARCHAR(100)                NULL,
    country_code           NVARCHAR(2)                  NULL  DEFAULT 'TR',
    email                  NVARCHAR(200)                NULL,
    phone                  NVARCHAR(20)                 NULL,
    -- Finansal
    iban                   NVARCHAR(34)                 NULL,   -- şifreli tutulacak §25.4
    currency_code          NVARCHAR(3)                  NOT NULL  DEFAULT 'TRY',
    payment_days           SMALLINT                     NULL  DEFAULT 0,
    credit_limit           DECIMAL(18,2)                NULL,
    -- Muhasebe eşleme
    account_id             INT                          NULL,   -- bağlı genel hesap
    -- e-Belge durumu §13.3
    e_invoice_registered   BIT                          NOT NULL  DEFAULT 0,
    e_invoice_alias        NVARCHAR(200)                NULL,
    e_archive_applicable   BIT                          NOT NULL  DEFAULT 0,
    -- Stopaj/tevkifat statüsü
    withholding_applicable BIT                          NOT NULL  DEFAULT 0,
    stopaj_applicable      BIT                          NOT NULL  DEFAULT 0,
    -- Mutabakat tipi
    reconciliation_type    NVARCHAR(20)                 NULL
                               CONSTRAINT chk_ca_recon CHECK (
                                   reconciliation_type IS NULL
                                   OR reconciliation_type IN ('OTOMATIK','MANUEL','YOK')
                               ),
    is_active              BIT                          NOT NULL  DEFAULT 1,
    created_at             DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by             INT                          NULL,
    updated_at             DATETIME2(3)                 NULL,
    updated_by             INT                          NULL,
    row_version            ROWVERSION                   NOT NULL,
    CONSTRAINT pk_current_accounts         PRIMARY KEY (id),
    CONSTRAINT fk_ca_company               FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT fk_ca_type                  FOREIGN KEY (type_id)    REFERENCES dbo.current_account_types(id),
    CONSTRAINT fk_ca_account               FOREIGN KEY (account_id) REFERENCES dbo.accounts(id),
    CONSTRAINT uq_current_accounts         UNIQUE (company_id, code)
);
GO

-- --------------------------------------------------------
-- Belge Başlığı (document_headers)  — §11
-- --------------------------------------------------------
CREATE TABLE dbo.document_headers (
    id                      INT           IDENTITY(1,1)  NOT NULL,
    company_id              INT                          NOT NULL,
    branch_id               INT                          NULL,
    document_type_id        INT                          NOT NULL,
    fiscal_year_id          INT                          NOT NULL,
    fiscal_period_id        INT                          NOT NULL,
    document_no             NVARCHAR(50)                 NOT NULL,
    document_date           DATE                         NOT NULL,
    due_date                DATE                         NULL,
    current_account_id      INT                          NULL,
    description             NVARCHAR(500)                NULL,
    currency_code           NVARCHAR(3)                  NOT NULL  DEFAULT 'TRY',
    exchange_rate           DECIMAL(18,6)                NOT NULL  DEFAULT 1,
    -- Tutarlar
    subtotal_kurus          BIGINT                       NOT NULL  DEFAULT 0,
    discount_kurus          BIGINT                       NOT NULL  DEFAULT 0,
    vat_base_kurus          BIGINT                       NOT NULL  DEFAULT 0,
    vat_amount_kurus        BIGINT                       NOT NULL  DEFAULT 0,
    tevkifat_kurus          BIGINT                       NOT NULL  DEFAULT 0,
    total_kurus             BIGINT                       NOT NULL  DEFAULT 0,
    -- Referans bağlar
    related_document_id     INT                          NULL,     -- iade/fiyat farkı kaynağı
    -- e-Belge durumu
    e_document_uuid         NVARCHAR(36)                 NULL,
    e_document_status       NVARCHAR(20)                 NULL
                                CONSTRAINT chk_dh_edoc_status CHECK (
                                    e_document_status IS NULL
                                    OR e_document_status IN (
                                        'TASLAK','HAZIR','IMZAYA_HAZIR','GONDERILDI',
                                        'KABUL','RED','IPTAL','HATA','ARSIVLENDI'
                                    )
                                ),
    -- Muhasebeleştirme §11.4
    is_accounted            BIT                          NOT NULL  DEFAULT 0,
    accounted_voucher_id    INT                          NULL,
    accounted_at            DATETIME2(3)                 NULL,
    accounted_by            INT                          NULL,
    -- İptal
    is_cancelled            BIT                          NOT NULL  DEFAULT 0,
    cancelled_at            DATETIME2(3)                 NULL,
    cancelled_by            INT                          NULL,
    -- Onay
    status                  NVARCHAR(20)                 NOT NULL  DEFAULT 'TASLAK',
    created_at              DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by              INT                          NULL,
    updated_at              DATETIME2(3)                 NULL,
    updated_by              INT                          NULL,
    row_version             ROWVERSION                   NOT NULL,
    CONSTRAINT pk_document_headers          PRIMARY KEY (id),
    CONSTRAINT fk_dh_company                FOREIGN KEY (company_id)       REFERENCES dbo.companies(id),
    CONSTRAINT fk_dh_branch                 FOREIGN KEY (branch_id)        REFERENCES dbo.branches(id),
    CONSTRAINT fk_dh_doc_type               FOREIGN KEY (document_type_id) REFERENCES dbo.document_types(id),
    CONSTRAINT fk_dh_fiscal_year            FOREIGN KEY (fiscal_year_id)   REFERENCES dbo.fiscal_years(id),
    CONSTRAINT fk_dh_fiscal_period          FOREIGN KEY (fiscal_period_id) REFERENCES dbo.fiscal_periods(id),
    CONSTRAINT fk_dh_current_account        FOREIGN KEY (current_account_id) REFERENCES dbo.current_accounts(id),
    CONSTRAINT fk_dh_related_doc            FOREIGN KEY (related_document_id) REFERENCES dbo.document_headers(id),
    CONSTRAINT uq_document_headers          UNIQUE (company_id, fiscal_year_id, document_type_id, document_no)
);
GO

-- --------------------------------------------------------
-- Belge Satırı (document_lines)  — §11.2
-- --------------------------------------------------------
CREATE TABLE dbo.document_lines (
    id                  INT           IDENTITY(1,1)  NOT NULL,
    document_id         INT                          NOT NULL,
    line_no             SMALLINT                     NOT NULL,
    -- Mal / Hizmet ayrımı
    line_type           NVARCHAR(10)                 NOT NULL  DEFAULT 'MAL'
                            CONSTRAINT chk_dl_type CHECK (line_type IN ('MAL','HIZMET')),
    inventory_item_id   INT                          NULL,
    service_item_id     INT                          NULL,
    warehouse_id        INT                          NULL,
    description         NVARCHAR(300)                NULL,
    quantity            DECIMAL(18,4)                NOT NULL  DEFAULT 1,
    unit_code           NVARCHAR(10)                 NULL,
    unit_price          DECIMAL(18,6)                NOT NULL  DEFAULT 0,
    discount_rate       DECIMAL(6,4)                 NOT NULL  DEFAULT 0,
    discount_amount_kurus BIGINT                     NOT NULL  DEFAULT 0,
    line_total_kurus    BIGINT                       NOT NULL  DEFAULT 0,
    vat_code_id         INT                          NULL,
    vat_base_kurus      BIGINT                       NOT NULL  DEFAULT 0,
    vat_amount_kurus    BIGINT                       NOT NULL  DEFAULT 0,
    withholding_code_id INT                          NULL,
    tevkifat_kurus      BIGINT                       NOT NULL  DEFAULT 0,
    stopaj_code_id      INT                          NULL,
    stopaj_kurus        BIGINT                       NOT NULL  DEFAULT 0,
    cost_center_id      INT                          NULL,
    project_id          INT                          NULL,
    delivery_date       DATE                         NULL,
    shipment_order_ref  NVARCHAR(50)                 NULL,
    created_at          DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by          INT                          NULL,
    CONSTRAINT pk_document_lines             PRIMARY KEY (id),
    CONSTRAINT fk_dl_document                FOREIGN KEY (document_id)     REFERENCES dbo.document_headers(id) ON DELETE CASCADE,
    CONSTRAINT fk_dl_inventory               FOREIGN KEY (inventory_item_id) REFERENCES dbo.inventory_items(id),
    CONSTRAINT fk_dl_service                 FOREIGN KEY (service_item_id)   REFERENCES dbo.service_items(id),
    CONSTRAINT fk_dl_warehouse               FOREIGN KEY (warehouse_id)    REFERENCES dbo.warehouses(id),
    CONSTRAINT fk_dl_vat                     FOREIGN KEY (vat_code_id)     REFERENCES dbo.vat_codes(id),
    CONSTRAINT fk_dl_cost_center             FOREIGN KEY (cost_center_id)  REFERENCES dbo.cost_centers(id),
    CONSTRAINT fk_dl_project                 FOREIGN KEY (project_id)      REFERENCES dbo.projects(id),
    CONSTRAINT uq_document_lines             UNIQUE (document_id, line_no)
);
GO

-- --------------------------------------------------------
-- Sabit Kıymet Kategorisi (fixed_asset_categories)
-- --------------------------------------------------------
CREATE TABLE dbo.fixed_asset_categories (
    id                 INT           IDENTITY(1,1)  NOT NULL,
    company_id         INT                          NOT NULL,
    code               NVARCHAR(20)                 NOT NULL,
    name               NVARCHAR(100)                NOT NULL,
    default_useful_life SMALLINT                    NULL,    -- ay
    default_method     NVARCHAR(20)                 NULL,
    asset_account      NVARCHAR(20)                 NULL,
    acc_dep_account    NVARCHAR(20)                 NULL,
    dep_expense_account NVARCHAR(20)                NULL,
    is_active          BIT                          NOT NULL  DEFAULT 1,
    created_at         DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_fixed_asset_categories  PRIMARY KEY (id),
    CONSTRAINT fk_fac_company             FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT uq_fixed_asset_categories  UNIQUE (company_id, code)
);
GO

-- --------------------------------------------------------
-- Sabit Kıymet Kartı (fixed_assets)  — §17.1
-- --------------------------------------------------------
CREATE TABLE dbo.fixed_assets (
    id                    INT           IDENTITY(1,1)  NOT NULL,
    company_id            INT                          NOT NULL,
    branch_id             INT                          NULL,
    category_id           INT                          NOT NULL,
    code                  NVARCHAR(30)                 NOT NULL,
    name                  NVARCHAR(200)                NOT NULL,
    serial_no             NVARCHAR(100)                NULL,
    location              NVARCHAR(200)                NULL,
    acquisition_date      DATE                         NOT NULL,
    acquisition_cost      DECIMAL(18,2)                NOT NULL,
    -- Amortisman bilgisi
    useful_life_months    SMALLINT                     NOT NULL,
    depreciation_method   NVARCHAR(30)                 NOT NULL  DEFAULT 'NORMAL'
                              CONSTRAINT chk_fa_dep_method CHECK (
                                  depreciation_method IN ('NORMAL','HIZLANDIRILMIS','AZALAN_BAKIYE')
                              ),
    residual_value        DECIMAL(18,2)                NOT NULL  DEFAULT 0,
    -- Muhasebe hesapları
    asset_account_id      INT                          NULL,
    acc_dep_account_id    INT                          NULL,
    dep_expense_account_id INT                         NULL,
    cost_center_id        INT                          NULL,
    project_id            INT                          NULL,
    -- Enflasyon düzeltme §20.2
    inflation_adj_applied BIT                          NOT NULL  DEFAULT 0,
    -- Satış/elden çıkarma
    disposal_date         DATE                         NULL,
    disposal_voucher_id   INT                          NULL,
    -- Akıf
    status                NVARCHAR(20)                 NOT NULL  DEFAULT 'AKTIF'
                              CONSTRAINT chk_fa_status CHECK (
                                  status IN ('AKTIF','SATILDI','HURDA','DEVIR','KAYIP')
                              ),
    created_at            DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by            INT                          NULL,
    updated_at            DATETIME2(3)                 NULL,
    updated_by            INT                          NULL,
    row_version           ROWVERSION                   NOT NULL,
    CONSTRAINT pk_fixed_assets         PRIMARY KEY (id),
    CONSTRAINT fk_fa_company           FOREIGN KEY (company_id)   REFERENCES dbo.companies(id),
    CONSTRAINT fk_fa_branch            FOREIGN KEY (branch_id)    REFERENCES dbo.branches(id),
    CONSTRAINT fk_fa_category          FOREIGN KEY (category_id)  REFERENCES dbo.fixed_asset_categories(id),
    CONSTRAINT fk_fa_cost_center       FOREIGN KEY (cost_center_id) REFERENCES dbo.cost_centers(id),
    CONSTRAINT uq_fixed_assets         UNIQUE (company_id, code)
);
GO

-- --------------------------------------------------------
-- Amortisman Planı Satırları (depreciation_lines)  — §17.2
-- --------------------------------------------------------
CREATE TABLE dbo.depreciation_lines (
    id                  INT           IDENTITY(1,1)  NOT NULL,
    fixed_asset_id      INT                          NOT NULL,
    period_no           SMALLINT                     NOT NULL,
    depreciation_date   DATE                         NOT NULL,
    depreciation_month  TINYINT                      NOT NULL,
    depreciation_year   SMALLINT                     NOT NULL,
    opening_book_value  DECIMAL(18,2)                NOT NULL,
    depreciation_amount DECIMAL(18,2)                NOT NULL,
    closing_book_value  DECIMAL(18,2)                NOT NULL,
    voucher_id          INT                          NULL,
    is_posted           BIT                          NOT NULL  DEFAULT 0,
    posted_at           DATETIME2(3)                 NULL,
    created_at          DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_depreciation_lines         PRIMARY KEY (id),
    CONSTRAINT fk_dep_fixed_asset            FOREIGN KEY (fixed_asset_id) REFERENCES dbo.fixed_assets(id),
    CONSTRAINT fk_dep_voucher                FOREIGN KEY (voucher_id)     REFERENCES dbo.vouchers(id)
);
GO
