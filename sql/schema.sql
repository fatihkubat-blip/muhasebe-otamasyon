PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS companies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    legal_name TEXT NOT NULL,
    trade_name TEXT,
    tax_number TEXT NOT NULL UNIQUE,
    tax_office TEXT,
    mersis_no TEXT,
    trade_register_no TEXT,
    address TEXT,
    city TEXT,
    district TEXT,
    country_code TEXT DEFAULT 'TR',
    phone TEXT,
    email TEXT,
    web_site TEXT,
    local_currency_code TEXT DEFAULT 'TRY',
    reporting_currency_code TEXT,
    fiscal_year_start_month INTEGER DEFAULT 1,
    accounting_standard TEXT DEFAULT 'VUK',
    is_vat_liable INTEGER DEFAULT 1,
    e_invoice_active INTEGER DEFAULT 0,
    e_archive_active INTEGER DEFAULT 0,
    e_ledger_active INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT
);

CREATE TABLE IF NOT EXISTS branches (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    address TEXT,
    city TEXT,
    is_head_office INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    UNIQUE (company_id, code)
);

CREATE TABLE IF NOT EXISTS fiscal_years (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    fiscal_year INTEGER NOT NULL,
    year_code TEXT NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    is_closed INTEGER DEFAULT 0,
    closed_at TEXT,
    closed_by INTEGER,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    UNIQUE (company_id, fiscal_year)
);

CREATE TABLE IF NOT EXISTS fiscal_periods (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    fiscal_year_id INTEGER NOT NULL,
    period_no INTEGER NOT NULL,
    period_name TEXT NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    is_closed INTEGER DEFAULT 0,
    is_locked INTEGER DEFAULT 0,
    allow_retroactive_entry INTEGER DEFAULT 0,
    closed_at TEXT,
    closed_by INTEGER,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (fiscal_year_id) REFERENCES fiscal_years(id),
    UNIQUE (company_id, fiscal_year_id, period_no)
);

CREATE TABLE IF NOT EXISTS accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    short_name TEXT,
    account_class TEXT,
    account_type TEXT,
    normal_balance TEXT,
    parent_account_id INTEGER,
    is_detail INTEGER DEFAULT 1,
    currency_code TEXT,
    tfrs_mapping_code TEXT,
    bobi_mapping_code TEXT,
    kumi_mapping_code TEXT,
    balance_sheet_group TEXT,
    balance_sheet_line TEXT,
    income_stmt_group TEXT,
    income_stmt_line TEXT,
    reflection_account_code TEXT,
    tax_relation_type TEXT,
    default_vat_code_id INTEGER,
    auto_vat_account_code TEXT,
    notes TEXT,
    is_active INTEGER DEFAULT 1,
    created_by INTEGER,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    UNIQUE (company_id, code)
);

CREATE TABLE IF NOT EXISTS voucher_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS vouchers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    branch_id INTEGER,
    fiscal_year_id INTEGER NOT NULL,
    fiscal_period_id INTEGER NOT NULL,
    voucher_type_id INTEGER NOT NULL,
    journal_sequence_no INTEGER NOT NULL,
    voucher_no TEXT NOT NULL,
    document_date TEXT NOT NULL,
    posting_date TEXT NOT NULL,
    description TEXT NOT NULL,
    source_document_no TEXT,
    module_source TEXT DEFAULT 'MANUEL',
    total_debit_kurus INTEGER NOT NULL DEFAULT 0,
    total_credit_kurus INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'TASLAK',
    approved_at TEXT,
    approved_by INTEGER,
    reverse_of_id INTEGER,
    reversed_by_id INTEGER,
    is_reversed INTEGER DEFAULT 0,
    created_by INTEGER,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_by INTEGER,
    updated_at TEXT,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (fiscal_year_id) REFERENCES fiscal_years(id),
    FOREIGN KEY (fiscal_period_id) REFERENCES fiscal_periods(id),
    FOREIGN KEY (voucher_type_id) REFERENCES voucher_types(id),
    UNIQUE (company_id, fiscal_year_id, voucher_no),
    UNIQUE (company_id, fiscal_year_id, journal_sequence_no)
);

CREATE TABLE IF NOT EXISTS voucher_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    voucher_id INTEGER NOT NULL,
    line_no INTEGER NOT NULL,
    company_id INTEGER NOT NULL,
    branch_id INTEGER,
    account_id INTEGER NOT NULL,
    current_account_id INTEGER,
    description TEXT,
    debit_kurus INTEGER NOT NULL DEFAULT 0,
    credit_kurus INTEGER NOT NULL DEFAULT 0,
    currency_code TEXT,
    exchange_rate REAL,
    foreign_amount REAL,
    due_date TEXT,
    document_no TEXT,
    document_date TEXT,
    vat_code_id INTEGER,
    withholding_code_id INTEGER,
    stopaj_code_id INTEGER,
    vat_base_kurus INTEGER,
    vat_amount_kurus INTEGER,
    cost_center_id INTEGER,
    project_id INTEGER,
    source_module TEXT,
    source_document_id INTEGER,
    source_line_id INTEGER,
    created_by INTEGER,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (voucher_id) REFERENCES vouchers(id) ON DELETE CASCADE,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (account_id) REFERENCES accounts(id),
    UNIQUE (voucher_id, line_no)
);

CREATE TABLE IF NOT EXISTS current_account_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS current_accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    type_id INTEGER NOT NULL,
    code TEXT NOT NULL,
    title TEXT NOT NULL,
    tax_number TEXT,
    tax_office TEXT,
    mersis_no TEXT,
    trade_register_no TEXT,
    address TEXT,
    city TEXT,
    district TEXT,
    country_code TEXT DEFAULT 'TR',
    email TEXT,
    phone TEXT,
    iban TEXT,
    currency_code TEXT DEFAULT 'TRY',
    payment_days INTEGER DEFAULT 0,
    credit_limit REAL,
    account_id INTEGER,
    e_invoice_registered INTEGER DEFAULT 0,
    e_invoice_alias TEXT,
    e_archive_applicable INTEGER DEFAULT 0,
    withholding_applicable INTEGER DEFAULT 0,
    stopaj_applicable INTEGER DEFAULT 0,
    reconciliation_type TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (type_id) REFERENCES current_account_types(id),
    UNIQUE (company_id, code)
);

CREATE TABLE IF NOT EXISTS document_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    direction TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS document_headers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    branch_id INTEGER,
    document_type_id INTEGER NOT NULL,
    fiscal_year_id INTEGER NOT NULL,
    fiscal_period_id INTEGER NOT NULL,
    document_no TEXT NOT NULL,
    document_date TEXT NOT NULL,
    due_date TEXT,
    current_account_id INTEGER,
    description TEXT,
    currency_code TEXT DEFAULT 'TRY',
    exchange_rate REAL DEFAULT 1,
    subtotal_kurus INTEGER DEFAULT 0,
    discount_kurus INTEGER DEFAULT 0,
    vat_base_kurus INTEGER DEFAULT 0,
    vat_amount_kurus INTEGER DEFAULT 0,
    tevkifat_kurus INTEGER DEFAULT 0,
    total_kurus INTEGER DEFAULT 0,
    related_document_id INTEGER,
    e_document_uuid TEXT,
    e_document_status TEXT,
    is_accounted INTEGER DEFAULT 0,
    accounted_voucher_id INTEGER,
    is_cancelled INTEGER DEFAULT 0,
    status TEXT DEFAULT 'TASLAK',
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (document_type_id) REFERENCES document_types(id),
    FOREIGN KEY (fiscal_year_id) REFERENCES fiscal_years(id),
    FOREIGN KEY (fiscal_period_id) REFERENCES fiscal_periods(id)
);

CREATE TABLE IF NOT EXISTS document_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL,
    line_no INTEGER NOT NULL,
    inventory_item_id INTEGER,
    service_item_id INTEGER,
    warehouse_id INTEGER,
    description TEXT,
    quantity REAL NOT NULL DEFAULT 1,
    unit_code TEXT,
    unit_price REAL NOT NULL DEFAULT 0,
    discount_rate REAL NOT NULL DEFAULT 0,
    discount_amount_kurus INTEGER DEFAULT 0,
    line_total_kurus INTEGER DEFAULT 0,
    vat_code_id INTEGER,
    vat_base_kurus INTEGER DEFAULT 0,
    vat_amount_kurus INTEGER DEFAULT 0,
    withholding_code_id INTEGER,
    tevkifat_kurus INTEGER DEFAULT 0,
    stopaj_code_id INTEGER,
    stopaj_kurus INTEGER DEFAULT 0,
    cost_center_id INTEGER,
    project_id INTEGER,
    FOREIGN KEY (document_id) REFERENCES document_headers(id) ON DELETE CASCADE,
    UNIQUE (document_id, line_no)
);

CREATE TABLE IF NOT EXISTS vat_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    vat_rate REAL NOT NULL,
    vat_direction TEXT NOT NULL,
    is_active INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS withholding_vat_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    withholding_rate REAL NOT NULL,
    is_active INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS stopaj_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    stopaj_rate REAL NOT NULL,
    is_active INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS system_parameters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER,
    parameter_key TEXT NOT NULL,
    parameter_value TEXT NOT NULL,
    description TEXT,
    updated_at TEXT
);

CREATE TABLE IF NOT EXISTS regulatory_parameters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parameter_key TEXT NOT NULL,
    parameter_value TEXT NOT NULL,
    effective_date TEXT DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

CREATE TABLE IF NOT EXISTS vat_periods (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    fiscal_period_id INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'TASLAK'
);

CREATE TABLE IF NOT EXISTS bank_transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    transaction_date TEXT NOT NULL,
    is_reconciled INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS period_closing_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    fiscal_period_id INTEGER NOT NULL,
    step_code TEXT NOT NULL,
    step_name TEXT NOT NULL,
    status TEXT NOT NULL,
    completed_at TEXT,
    completed_by INTEGER,
    created_by INTEGER,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cost_centers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    code TEXT,
    name TEXT
);

CREATE TABLE IF NOT EXISTS projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    code TEXT,
    name TEXT
);
