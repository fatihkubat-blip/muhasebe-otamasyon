-- ============================================================
-- V005: Banka, Kasa, Çek/Senet
-- Şartname Bölüm 15
-- ============================================================

SET NOCOUNT ON;
GO

-- --------------------------------------------------------
-- Banka Hesap Kartı (bank_accounts)
-- --------------------------------------------------------
CREATE TABLE dbo.bank_accounts (
    id                  INT           IDENTITY(1,1)  NOT NULL,
    company_id          INT                          NOT NULL,
    branch_id           INT                          NULL,
    code                NVARCHAR(20)                 NOT NULL,
    bank_name           NVARCHAR(100)                NOT NULL,
    branch_name         NVARCHAR(100)                NULL,
    account_number      NVARCHAR(50)                 NULL,
    iban                NVARCHAR(34)                 NULL,     -- §25.4 masking uygulanır
    currency_code       NVARCHAR(3)                  NOT NULL  DEFAULT 'TRY',
    account_id          INT                          NULL,     -- bağlı muhasebe hesabı (102)
    is_active           BIT                          NOT NULL  DEFAULT 1,
    created_at          DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by          INT                          NULL,
    updated_at          DATETIME2(3)                 NULL,
    updated_by          INT                          NULL,
    row_version         ROWVERSION                   NOT NULL,
    CONSTRAINT pk_bank_accounts         PRIMARY KEY (id),
    CONSTRAINT fk_ba_company            FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT fk_ba_branch             FOREIGN KEY (branch_id)  REFERENCES dbo.branches(id),
    CONSTRAINT fk_ba_account            FOREIGN KEY (account_id) REFERENCES dbo.accounts(id),
    CONSTRAINT uq_bank_accounts         UNIQUE (company_id, code)
);
GO

-- --------------------------------------------------------
-- Banka Hareketi (bank_transactions)
-- --------------------------------------------------------
CREATE TABLE dbo.bank_transactions (
    id                  INT           IDENTITY(1,1)  NOT NULL,
    bank_account_id     INT                          NOT NULL,
    company_id          INT                          NOT NULL,
    transaction_date    DATE                         NOT NULL,
    value_date          DATE                         NULL,
    -- GELIR / GIDER / VIRMAN
    direction           NVARCHAR(10)                 NOT NULL
                            CONSTRAINT chk_bt_direction CHECK (direction IN ('GELIR','GIDER','VIRMAN')),
    amount_kurus        BIGINT                       NOT NULL,
    currency_code       NVARCHAR(3)                  NOT NULL  DEFAULT 'TRY',
    exchange_rate       DECIMAL(18,6)                NOT NULL  DEFAULT 1,
    description         NVARCHAR(500)                NULL,
    reference_no        NVARCHAR(100)                NULL,
    current_account_id  INT                          NULL,
    voucher_id          INT                          NULL,
    -- Mutabakat §15.2
    is_reconciled       BIT                          NOT NULL  DEFAULT 0,
    reconciled_at       DATETIME2(3)                 NULL,
    reconciled_by       INT                          NULL,
    created_at          DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by          INT                          NULL,
    row_version         ROWVERSION                   NOT NULL,
    CONSTRAINT pk_bank_transactions         PRIMARY KEY (id),
    CONSTRAINT fk_bt_bank_account           FOREIGN KEY (bank_account_id)    REFERENCES dbo.bank_accounts(id),
    CONSTRAINT fk_bt_company                FOREIGN KEY (company_id)         REFERENCES dbo.companies(id),
    CONSTRAINT fk_bt_current_account        FOREIGN KEY (current_account_id) REFERENCES dbo.current_accounts(id),
    CONSTRAINT fk_bt_voucher                FOREIGN KEY (voucher_id)         REFERENCES dbo.vouchers(id)
);
GO

-- --------------------------------------------------------
-- Kasa Kartı (cash_registers)
-- --------------------------------------------------------
CREATE TABLE dbo.cash_registers (
    id                  INT           IDENTITY(1,1)  NOT NULL,
    company_id          INT                          NOT NULL,
    branch_id           INT                          NULL,
    code                NVARCHAR(20)                 NOT NULL,
    name                NVARCHAR(100)                NOT NULL,
    currency_code       NVARCHAR(3)                  NOT NULL  DEFAULT 'TRY',
    account_id          INT                          NULL,     -- bağlı muhasebe hesabı (100)
    is_active           BIT                          NOT NULL  DEFAULT 1,
    created_at          DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by          INT                          NULL,
    updated_at          DATETIME2(3)                 NULL,
    updated_by          INT                          NULL,
    row_version         ROWVERSION                   NOT NULL,
    CONSTRAINT pk_cash_registers         PRIMARY KEY (id),
    CONSTRAINT fk_cr_company             FOREIGN KEY (company_id) REFERENCES dbo.companies(id),
    CONSTRAINT fk_cr_branch              FOREIGN KEY (branch_id)  REFERENCES dbo.branches(id),
    CONSTRAINT fk_cr_account             FOREIGN KEY (account_id) REFERENCES dbo.accounts(id),
    CONSTRAINT uq_cash_registers         UNIQUE (company_id, code)
);
GO

-- --------------------------------------------------------
-- Kasa Hareketi (cash_transactions)
-- --------------------------------------------------------
CREATE TABLE dbo.cash_transactions (
    id                  INT           IDENTITY(1,1)  NOT NULL,
    cash_register_id    INT                          NOT NULL,
    company_id          INT                          NOT NULL,
    transaction_date    DATE                         NOT NULL,
    direction           NVARCHAR(10)                 NOT NULL
                            CONSTRAINT chk_ct_direction CHECK (direction IN ('TAHSIL','TEDIYE','VIRMAN','SAYIM')),
    amount_kurus        BIGINT                       NOT NULL,
    currency_code       NVARCHAR(3)                  NOT NULL  DEFAULT 'TRY',
    description         NVARCHAR(500)                NULL,
    current_account_id  INT                          NULL,
    voucher_id          INT                          NULL,
    created_at          DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by          INT                          NULL,
    row_version         ROWVERSION                   NOT NULL,
    CONSTRAINT pk_cash_transactions         PRIMARY KEY (id),
    CONSTRAINT fk_ct_cash_register          FOREIGN KEY (cash_register_id)   REFERENCES dbo.cash_registers(id),
    CONSTRAINT fk_ct_company                FOREIGN KEY (company_id)         REFERENCES dbo.companies(id),
    CONSTRAINT fk_ct_current_account        FOREIGN KEY (current_account_id) REFERENCES dbo.current_accounts(id),
    CONSTRAINT fk_ct_voucher                FOREIGN KEY (voucher_id)         REFERENCES dbo.vouchers(id)
);
GO

-- --------------------------------------------------------
-- Çek / Senet Portföy (negotiable_instruments)  — §15.3
-- --------------------------------------------------------
CREATE TABLE dbo.negotiable_instruments (
    id                   INT           IDENTITY(1,1)  NOT NULL,
    company_id           INT                          NOT NULL,
    instrument_type      NVARCHAR(10)                 NOT NULL
                             CONSTRAINT chk_ni_type CHECK (instrument_type IN ('CEK','SENET')),
    direction            NVARCHAR(10)                 NOT NULL
                             CONSTRAINT chk_ni_direction CHECK (direction IN ('ALACAKLI','BORC')),
    serial_no            NVARCHAR(50)                 NOT NULL,
    bank_name            NVARCHAR(100)                NULL,
    bank_branch          NVARCHAR(100)                NULL,
    account_number       NVARCHAR(50)                 NULL,
    current_account_id   INT                          NULL,
    issue_date           DATE                         NOT NULL,
    due_date             DATE                         NOT NULL,
    amount_kurus         BIGINT                       NOT NULL,
    currency_code        NVARCHAR(3)                  NOT NULL  DEFAULT 'TRY',
    -- Durum
    status               NVARCHAR(20)                 NOT NULL  DEFAULT 'PORTFOY'
                             CONSTRAINT chk_ni_status CHECK (
                                 status IN ('PORTFOY','CIROLANDI','TAHSIL_VERILDI',
                                            'TEMINAT','TAHSIL_EDILDI','PROTESTO','IADE','IPTAL')
                             ),
    -- Muhasebe bağı
    receipt_voucher_id   INT                          NULL,
    transfer_voucher_id  INT                          NULL,
    collection_voucher_id INT                         NULL,
    -- Bağlı hesap
    portfolio_account_id INT                          NULL,
    created_at           DATETIME2(3)                 NOT NULL  DEFAULT SYSUTCDATETIME(),
    created_by           INT                          NULL,
    updated_at           DATETIME2(3)                 NULL,
    updated_by           INT                          NULL,
    row_version          ROWVERSION                   NOT NULL,
    CONSTRAINT pk_negotiable_instruments     PRIMARY KEY (id),
    CONSTRAINT fk_ni_company                 FOREIGN KEY (company_id)        REFERENCES dbo.companies(id),
    CONSTRAINT fk_ni_current_account         FOREIGN KEY (current_account_id) REFERENCES dbo.current_accounts(id)
);
GO
