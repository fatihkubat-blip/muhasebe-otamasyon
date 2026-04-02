-- ============================================================
-- V001: Şirket, Şube, Mali Yıl, Dönem, Kullanıcı, Rol, Yetki
-- SQL Server 2016+ uyumlu T-SQL
-- Şartname Bölüm 5 gereksinimlerini karşılar.
-- ============================================================

SET NOCOUNT ON;
GO

-- --------------------------------------------------------
-- Şirket (companies)
-- --------------------------------------------------------
CREATE TABLE dbo.companies (
    id                       INT            IDENTITY(1,1)  NOT NULL,
    code                     NVARCHAR(20)                  NOT NULL,
    legal_name               NVARCHAR(200)                 NOT NULL,
    trade_name               NVARCHAR(200)                 NULL,
    tax_number               NVARCHAR(11)                  NOT NULL,   -- VKN (10) veya TCKN (11)
    tax_office               NVARCHAR(100)                 NULL,
    mersis_no                NVARCHAR(20)                  NULL,
    trade_register_no        NVARCHAR(50)                  NULL,
    address                  NVARCHAR(500)                 NULL,
    city                     NVARCHAR(100)                 NULL,
    district                 NVARCHAR(100)                 NULL,
    country_code             NVARCHAR(2)                   NOT NULL  DEFAULT 'TR',
    phone                    NVARCHAR(20)                  NULL,
    email                    NVARCHAR(200)                 NULL,
    web_site                 NVARCHAR(200)                 NULL,
    local_currency_code      NVARCHAR(3)                   NOT NULL  DEFAULT 'TRY',
    reporting_currency_code  NVARCHAR(3)                   NULL,
    fiscal_year_start_month  TINYINT                       NOT NULL  DEFAULT 1
                                 CONSTRAINT chk_companies_fy_month CHECK (fiscal_year_start_month BETWEEN 1 AND 12),
    -- VUK / TFRS / BOBİ FRS / KÜMİ FRS
    accounting_standard      NVARCHAR(20)                  NOT NULL  DEFAULT 'VUK'
                                 CONSTRAINT chk_companies_std CHECK (
                                     accounting_standard IN ('VUK','TFRS','BOBI_FRS','KUMI_FRS')
                                 ),
    is_vat_liable            BIT                           NOT NULL  DEFAULT 1,
    e_invoice_active         BIT                           NOT NULL  DEFAULT 0,
    e_archive_active         BIT                           NOT NULL  DEFAULT 0,
    e_dispatch_active        BIT                           NOT NULL  DEFAULT 0,
    e_ledger_active          BIT                           NOT NULL  DEFAULT 0,
    e_invoice_start_date     DATE                          NULL,
    e_archive_start_date     DATE                          NULL,
    e_ledger_start_date      DATE                          NULL,
    is_active                BIT                           NOT NULL  DEFAULT 1,
    created_at               DATETIME2(3)                  NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by               INT                           NULL,
    updated_at               DATETIME2(3)                  NULL,
    updated_by               INT                           NULL,
    row_version              ROWVERSION                    NOT NULL,
    CONSTRAINT pk_companies PRIMARY KEY (id),
    CONSTRAINT uq_companies_code     UNIQUE (code),
    CONSTRAINT uq_companies_tax_no   UNIQUE (tax_number)
);
GO

-- --------------------------------------------------------
-- Şube (branches)
-- --------------------------------------------------------
CREATE TABLE dbo.branches (
    id          INT            IDENTITY(1,1)  NOT NULL,
    company_id  INT                           NOT NULL,
    code        NVARCHAR(20)                  NOT NULL,
    name        NVARCHAR(200)                 NOT NULL,
    address     NVARCHAR(500)                 NULL,
    city        NVARCHAR(100)                 NULL,
    is_head_office  BIT                       NOT NULL  DEFAULT 0,
    is_active   BIT                           NOT NULL  DEFAULT 1,
    created_at  DATETIME2(3)                  NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by  INT                           NULL,
    updated_at  DATETIME2(3)                  NULL,
    updated_by  INT                           NULL,
    row_version ROWVERSION                    NOT NULL,
    CONSTRAINT pk_branches         PRIMARY KEY (id),
    CONSTRAINT fk_branches_company FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT uq_branches_code    UNIQUE (company_id, code)
);
GO

-- --------------------------------------------------------
-- Mali Yıl (fiscal_years)
-- --------------------------------------------------------
CREATE TABLE dbo.fiscal_years (
    id           INT           IDENTITY(1,1)  NOT NULL,
    company_id   INT                          NOT NULL,
    year_code    NVARCHAR(10)                 NOT NULL,
    fiscal_year  SMALLINT                     NOT NULL,
    start_date   DATE                         NOT NULL,
    end_date     DATE                         NOT NULL,
    is_closed    BIT                          NOT NULL  DEFAULT 0,
    closed_at    DATETIME2(3)                 NULL,
    closed_by    INT                          NULL,
    created_at   DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by   INT                          NULL,
    updated_at   DATETIME2(3)                 NULL,
    updated_by   INT                          NULL,
    row_version  ROWVERSION                   NOT NULL,
    CONSTRAINT pk_fiscal_years         PRIMARY KEY (id),
    CONSTRAINT fk_fiscal_years_company FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT uq_fiscal_years         UNIQUE (company_id, fiscal_year)
);
GO

-- --------------------------------------------------------
-- Dönem (fiscal_periods)
-- --------------------------------------------------------
CREATE TABLE dbo.fiscal_periods (
    id               INT           IDENTITY(1,1)  NOT NULL,
    company_id       INT                          NOT NULL,
    fiscal_year_id   INT                          NOT NULL,
    period_no        TINYINT                      NOT NULL
                         CONSTRAINT chk_fp_period_no CHECK (period_no BETWEEN 1 AND 13),
    period_name      NVARCHAR(50)                 NOT NULL,
    start_date       DATE                         NOT NULL,
    end_date         DATE                         NOT NULL,
    is_closed        BIT                          NOT NULL  DEFAULT 0,
    is_locked        BIT                          NOT NULL  DEFAULT 0,
    allow_retroactive_entry  BIT                  NOT NULL  DEFAULT 0,
    closed_at        DATETIME2(3)                 NULL,
    closed_by        INT                          NULL,
    created_at       DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by       INT                          NULL,
    row_version      ROWVERSION                   NOT NULL,
    CONSTRAINT pk_fiscal_periods         PRIMARY KEY (id),
    CONSTRAINT fk_fp_company             FOREIGN KEY (company_id)     REFERENCES dbo.companies(id),
    CONSTRAINT fk_fp_fiscal_year         FOREIGN KEY (fiscal_year_id) REFERENCES dbo.fiscal_years(id),
    CONSTRAINT uq_fiscal_periods         UNIQUE (company_id, fiscal_year_id, period_no)
);
GO

-- --------------------------------------------------------
-- Para Birimi (currencies)
-- --------------------------------------------------------
CREATE TABLE dbo.currencies (
    id           INT           IDENTITY(1,1)  NOT NULL,
    code         NVARCHAR(3)                  NOT NULL,
    name         NVARCHAR(100)                NOT NULL,
    symbol       NVARCHAR(5)                  NULL,
    decimal_places TINYINT                    NOT NULL  DEFAULT 2,
    is_active    BIT                          NOT NULL  DEFAULT 1,
    created_at   DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_currencies   PRIMARY KEY (id),
    CONSTRAINT uq_currencies   UNIQUE (code)
);
GO

-- --------------------------------------------------------
-- Kur Tipi (exchange_rate_types)
-- --------------------------------------------------------
CREATE TABLE dbo.exchange_rate_types (
    id          INT           IDENTITY(1,1)  NOT NULL,
    code        NVARCHAR(20)                 NOT NULL,
    name        NVARCHAR(100)                NOT NULL,
    description NVARCHAR(300)                NULL,
    CONSTRAINT pk_exchange_rate_types  PRIMARY KEY (id),
    CONSTRAINT uq_exchange_rate_types  UNIQUE (code)
);
GO

-- --------------------------------------------------------
-- Kurlar (exchange_rates)
-- --------------------------------------------------------
CREATE TABLE dbo.exchange_rates (
    id                   INT            IDENTITY(1,1)  NOT NULL,
    rate_type_id         INT                           NOT NULL,
    from_currency_code   NVARCHAR(3)                   NOT NULL,
    to_currency_code     NVARCHAR(3)                   NOT NULL,
    rate_date            DATE                          NOT NULL,
    rate                 DECIMAL(18,6)                 NOT NULL
                             CONSTRAINT chk_exchange_rates_rate CHECK (rate > 0),
    source               NVARCHAR(50)                  NULL,   -- TCMB, manuel, vb.
    created_at           DATETIME2(3)                  NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by           INT                           NULL,
    CONSTRAINT pk_exchange_rates        PRIMARY KEY (id),
    CONSTRAINT fk_exchange_rates_type   FOREIGN KEY (rate_type_id) REFERENCES dbo.exchange_rate_types(id),
    CONSTRAINT uq_exchange_rates        UNIQUE (rate_type_id, from_currency_code, to_currency_code, rate_date)
);
GO

-- --------------------------------------------------------
-- Kullanıcı (users)
-- --------------------------------------------------------
CREATE TABLE dbo.users (
    id                   INT            IDENTITY(1,1)  NOT NULL,
    username             NVARCHAR(50)                  NOT NULL,
    full_name            NVARCHAR(200)                 NOT NULL,
    email                NVARCHAR(200)                 NOT NULL,
    -- Uygulama şifre hash'i (bcrypt/argon2) veritabanına düz metin yazılmaz
    password_hash        NVARCHAR(250)                 NOT NULL,
    password_changed_at  DATETIME2(3)                  NULL,
    must_change_password BIT                           NOT NULL  DEFAULT 0,
    failed_login_count   SMALLINT                      NOT NULL  DEFAULT 0,
    locked_until         DATETIME2(3)                  NULL,
    last_login_at        DATETIME2(3)                  NULL,
    last_login_ip        NVARCHAR(45)                  NULL,
    is_system_admin      BIT                           NOT NULL  DEFAULT 0,
    is_active            BIT                           NOT NULL  DEFAULT 1,
    created_at           DATETIME2(3)                  NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by           INT                           NULL,
    updated_at           DATETIME2(3)                  NULL,
    updated_by           INT                           NULL,
    row_version          ROWVERSION                    NOT NULL,
    CONSTRAINT pk_users      PRIMARY KEY (id),
    CONSTRAINT uq_users_name UNIQUE (username),
    CONSTRAINT uq_users_mail UNIQUE (email)
);
GO

-- --------------------------------------------------------
-- Rol (roles)
-- --------------------------------------------------------
CREATE TABLE dbo.roles (
    id          INT           IDENTITY(1,1)  NOT NULL,
    code        NVARCHAR(50)                 NOT NULL,
    name        NVARCHAR(100)                NOT NULL,
    description NVARCHAR(500)                NULL,
    is_active   BIT                          NOT NULL  DEFAULT 1,
    created_at  DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_roles    PRIMARY KEY (id),
    CONSTRAINT uq_roles    UNIQUE (code)
);
GO

-- --------------------------------------------------------
-- Yetki (permissions)
-- --------------------------------------------------------
CREATE TABLE dbo.permissions (
    id          INT           IDENTITY(1,1)  NOT NULL,
    module      NVARCHAR(50)                 NOT NULL,
    action      NVARCHAR(50)                 NOT NULL,
    description NVARCHAR(300)                NULL,
    CONSTRAINT pk_permissions   PRIMARY KEY (id),
    CONSTRAINT uq_permissions   UNIQUE (module, action)
);
GO

-- --------------------------------------------------------
-- Kullanıcı-Rol (user_roles)
-- --------------------------------------------------------
CREATE TABLE dbo.user_roles (
    user_id    INT   NOT NULL,
    role_id    INT   NOT NULL,
    granted_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    granted_by INT   NULL,
    CONSTRAINT pk_user_roles           PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_user_roles_user      FOREIGN KEY (user_id)  REFERENCES dbo.users(id),
    CONSTRAINT fk_user_roles_role      FOREIGN KEY (role_id)  REFERENCES dbo.roles(id)
);
GO

-- --------------------------------------------------------
-- Rol-Yetki (role_permissions)
-- --------------------------------------------------------
CREATE TABLE dbo.role_permissions (
    role_id       INT   NOT NULL,
    permission_id INT   NOT NULL,
    CONSTRAINT pk_role_permissions            PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_role_permissions_role       FOREIGN KEY (role_id)       REFERENCES dbo.roles(id),
    CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES dbo.permissions(id)
);
GO

-- --------------------------------------------------------
-- Kullanıcı-Şirket Erişimi (user_company_access)
-- --------------------------------------------------------
CREATE TABLE dbo.user_company_access (
    user_id    INT   NOT NULL,
    company_id INT   NOT NULL,
    branch_id  INT   NULL,   -- NULL ise tüm şubeler
    granted_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    granted_by INT   NULL,
    CONSTRAINT pk_user_company_access          PRIMARY KEY (user_id, company_id),
    CONSTRAINT fk_uca_user                     FOREIGN KEY (user_id)    REFERENCES dbo.users(id),
    CONSTRAINT fk_uca_company                  FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT fk_uca_branch                   FOREIGN KEY (branch_id)  REFERENCES dbo.branches(id)
);
GO
