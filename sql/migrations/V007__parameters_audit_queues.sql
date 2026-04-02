-- ============================================================
-- V007: Sistem Parametreleri, Mevzuat Parametreleri,
--        Muhasebe Entegrasyon Kuralları, Audit Log,
--        Entegrasyon Kuyruğu, Hata Kuyruğu, Rapor Snapshot
-- Şartname Bölüm 6, 24, 26, 27, 31
-- ============================================================

SET NOCOUNT ON;
GO

-- --------------------------------------------------------
-- Sistem Parametresi (system_parameters)  — §6
-- --------------------------------------------------------
CREATE TABLE dbo.system_parameters (
    id            INT           IDENTITY(1,1)  NOT NULL,
    company_id    INT                          NOT NULL,
    category      NVARCHAR(50)                 NOT NULL,   -- GENEL / KDV / TAKVIM / EDOC ...
    param_key     NVARCHAR(100)                NOT NULL,
    param_value   NVARCHAR(2000)               NULL,
    data_type     NVARCHAR(20)                 NOT NULL  DEFAULT 'STRING'
                      CONSTRAINT chk_sp_dtype CHECK (
                          data_type IN ('STRING','INTEGER','DECIMAL','BOOLEAN','DATE','JSON')
                      ),
    description   NVARCHAR(500)                NULL,
    is_editable   BIT                          NOT NULL  DEFAULT 1,
    valid_from    DATE                         NULL,
    valid_to      DATE                         NULL,
    created_at    DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by    INT                          NULL,
    updated_at    DATETIME2(3)                 NULL,
    updated_by    INT                          NULL,
    CONSTRAINT pk_system_parameters       PRIMARY KEY (id),
    CONSTRAINT fk_sp_company              FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT uq_system_parameters       UNIQUE (company_id, category, param_key)
);
GO

-- --------------------------------------------------------
-- Versiyonlu Mevzuat Parametresi (regulatory_parameters)
-- Yıla göre değişen had/oran/eşik §6.2, §13.4
-- --------------------------------------------------------
CREATE TABLE dbo.regulatory_parameters (
    id            INT           IDENTITY(1,1)  NOT NULL,
    param_key     NVARCHAR(100)                NOT NULL,
    param_value   NVARCHAR(2000)               NOT NULL,
    description   NVARCHAR(500)                NULL,
    legal_source  NVARCHAR(200)                NULL,    -- Tebliğ/Sirküler
    valid_from    DATE                         NOT NULL,
    valid_to      DATE                         NULL,
    created_at    DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by    INT                          NULL,
    CONSTRAINT pk_regulatory_parameters   PRIMARY KEY (id),
    CONSTRAINT uq_regulatory_parameters   UNIQUE (param_key, valid_from)
);
GO

-- --------------------------------------------------------
-- Fiş Numaralama Şablonu (voucher_numbering_templates)  — §6.1
-- --------------------------------------------------------
CREATE TABLE dbo.voucher_numbering_templates (
    id                  INT           IDENTITY(1,1)  NOT NULL,
    company_id          INT                          NOT NULL,
    voucher_type_id     INT                          NOT NULL,
    fiscal_year         SMALLINT                     NOT NULL,
    prefix              NVARCHAR(20)                 NULL,
    suffix              NVARCHAR(10)                 NULL,
    number_length       TINYINT                      NOT NULL  DEFAULT 6,
    current_number      BIGINT                       NOT NULL  DEFAULT 0,
    reset_each_year     BIT                          NOT NULL  DEFAULT 1,
    row_version         ROWVERSION                   NOT NULL,
    CONSTRAINT pk_vnt              PRIMARY KEY (id),
    CONSTRAINT fk_vnt_company      FOREIGN KEY (company_id)     REFERENCES dbo.companies(id),
    CONSTRAINT fk_vnt_vtype        FOREIGN KEY (voucher_type_id) REFERENCES dbo.voucher_types(id),
    CONSTRAINT uq_vnt              UNIQUE (company_id, voucher_type_id, fiscal_year)
);
GO

-- --------------------------------------------------------
-- Muhasebe Entegrasyon Kuralı (accounting_integration_rules) — §3.3, §11.3
-- --------------------------------------------------------
CREATE TABLE dbo.accounting_integration_rules (
    id                    INT           IDENTITY(1,1)  NOT NULL,
    company_id            INT                          NOT NULL,
    rule_code             NVARCHAR(50)                 NOT NULL,
    rule_name             NVARCHAR(200)                NOT NULL,
    source_module         NVARCHAR(30)                 NOT NULL,
    document_type_id      INT                          NULL,
    trigger_event         NVARCHAR(50)                 NOT NULL,
    -- Koşul ve aksiyon JSON
    condition_json        NVARCHAR(MAX)                NULL,
    debit_account_logic   NVARCHAR(MAX)                NULL,
    credit_account_logic  NVARCHAR(MAX)                NULL,
    voucher_type_id       INT                          NULL,
    description_template  NVARCHAR(500)                NULL,
    is_active             BIT                          NOT NULL  DEFAULT 1,
    valid_from            DATE                         NOT NULL,
    valid_to              DATE                         NULL,
    created_at            DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by            INT                          NULL,
    updated_at            DATETIME2(3)                 NULL,
    updated_by            INT                          NULL,
    CONSTRAINT pk_air          PRIMARY KEY (id),
    CONSTRAINT fk_air_company  FOREIGN KEY (company_id)     REFERENCES dbo.companies(id),
    CONSTRAINT fk_air_dt       FOREIGN KEY (document_type_id) REFERENCES dbo.document_types(id),
    CONSTRAINT fk_air_vt       FOREIGN KEY (voucher_type_id)  REFERENCES dbo.voucher_types(id),
    CONSTRAINT uq_air          UNIQUE (company_id, rule_code)
);
GO

-- --------------------------------------------------------
-- Denetim İzi (audit_logs)  — §24
-- Değiştirilemez, silinemez (INSERT only + RLS ile korunur)
-- --------------------------------------------------------
CREATE TABLE dbo.audit_logs (
    id                BIGINT         IDENTITY(1,1)  NOT NULL,
    company_id        INT                           NULL,
    user_id           INT                           NULL,
    username          NVARCHAR(50)                  NULL,
    action            NVARCHAR(50)                  NOT NULL,
    table_name        NVARCHAR(100)                 NULL,
    record_id         NVARCHAR(50)                  NULL,
    old_value_json    NVARCHAR(MAX)                 NULL,
    new_value_json    NVARCHAR(MAX)                 NULL,
    description       NVARCHAR(1000)                NULL,
    ip_address        NVARCHAR(45)                  NULL,
    client_info       NVARCHAR(300)                 NULL,
    source_module     NVARCHAR(50)                  NULL,
    logged_at         DATETIME2(3)                  NOT NULL  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_audit_logs  PRIMARY KEY (id)
    -- DELETE/UPDATE tetikleyicisi ile bu tabloya müdahale engellenir §24.2
);
GO

-- --------------------------------------------------------
-- Entegrasyon Kuyruğu (integration_queue)  — §26, §27.3
-- --------------------------------------------------------
CREATE TABLE dbo.integration_queue (
    id                INT           IDENTITY(1,1)  NOT NULL,
    company_id        INT                          NOT NULL,
    source_system     NVARCHAR(50)                 NOT NULL,
    -- EFATURA/BANKA/ERP/BORDRO/ETICARET...
    message_type      NVARCHAR(50)                 NOT NULL,
    -- İdempotency anahtarı §26.3
    idempotency_key   NVARCHAR(100)                NOT NULL,
    payload_json      NVARCHAR(MAX)                NOT NULL,
    status            NVARCHAR(20)                 NOT NULL  DEFAULT 'BEKLIYOR'
                          CONSTRAINT chk_iq_status CHECK (
                              status IN ('BEKLIYOR','ISLENIYOR','TAMAMLANDI','HATA','TEKRAR_BEKLIYOR')
                          ),
    retry_count       TINYINT                      NOT NULL  DEFAULT 0,
    next_retry_at     DATETIME2(3)                 NULL,
    processed_at      DATETIME2(3)                 NULL,
    result_message    NVARCHAR(500)                NULL,
    created_at        DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    row_version       ROWVERSION                   NOT NULL,
    CONSTRAINT pk_integration_queue       PRIMARY KEY (id),
    CONSTRAINT fk_iq_company              FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT uq_integration_queue       UNIQUE (source_system, idempotency_key)
);
GO

-- --------------------------------------------------------
-- Hata Kuyruğu (error_queue)  — §27.3
-- --------------------------------------------------------
CREATE TABLE dbo.error_queue (
    id                INT           IDENTITY(1,1)  NOT NULL,
    company_id        INT                          NULL,
    user_id           INT                          NULL,
    error_source      NVARCHAR(50)                 NOT NULL,
    error_code        NVARCHAR(50)                 NULL,
    error_message     NVARCHAR(2000)               NOT NULL,
    stack_trace       NVARCHAR(MAX)                NULL,
    context_data      NVARCHAR(MAX)                NULL,
    is_resolved       BIT                          NOT NULL  DEFAULT 0,
    resolved_at       DATETIME2(3)                 NULL,
    resolved_by       INT                          NULL,
    created_at        DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_error_queue  PRIMARY KEY (id)
);
GO

-- --------------------------------------------------------
-- Rapor Snapshot (report_snapshots)  — §21.2
-- --------------------------------------------------------
CREATE TABLE dbo.report_snapshots (
    id                INT           IDENTITY(1,1)  NOT NULL,
    company_id        INT                          NOT NULL,
    report_code       NVARCHAR(50)                 NOT NULL,
    report_name       NVARCHAR(200)                NOT NULL,
    parameters_json   NVARCHAR(MAX)                NULL,
    snapshot_date     DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    data_json         NVARCHAR(MAX)                NOT NULL,
    created_by        INT                          NULL,
    CONSTRAINT pk_report_snapshots   PRIMARY KEY (id),
    CONSTRAINT fk_rs_company         FOREIGN KEY (company_id) REFERENCES dbo.companies(id)
);
GO
