-- ============================================================
-- V008: Tüm Kritik İndeksler
-- Şartname §27.2 (Doğru indeksleme, OLTP/Rapor ayrımı)
-- ============================================================

SET NOCOUNT ON;
GO

-- companies
CREATE UNIQUE INDEX uix_companies_tax_no ON dbo.companies(tax_number);
GO

-- accounts
CREATE INDEX ix_accounts_company_type ON dbo.accounts(company_id, account_type, is_active);
CREATE INDEX ix_accounts_company_class ON dbo.accounts(company_id, account_class) INCLUDE (code, name);
CREATE INDEX ix_accounts_parent ON dbo.accounts(parent_id) WHERE parent_id IS NOT NULL;
GO

-- fiscal_periods
CREATE INDEX ix_fiscal_periods_dates ON dbo.fiscal_periods(company_id, start_date, end_date) INCLUDE (is_closed);
GO

-- vouchers
CREATE INDEX ix_vouchers_posting_date ON dbo.vouchers(company_id, fiscal_year_id, posting_date)
    INCLUDE (voucher_no, voucher_type_id, status);
CREATE INDEX ix_vouchers_document_date ON dbo.vouchers(company_id, document_date);
CREATE INDEX ix_vouchers_module_source ON dbo.vouchers(company_id, module_source);
CREATE INDEX ix_vouchers_status ON dbo.vouchers(company_id, status) WHERE status <> 'ONAYLANDI';
GO

-- voucher_lines  — en kritik tablo; raporların kalbi
CREATE INDEX ix_vl_account_date ON dbo.voucher_lines(account_id)
    INCLUDE (voucher_id, debit_kurus, credit_kurus);
CREATE INDEX ix_vl_voucher ON dbo.voucher_lines(voucher_id);
CREATE INDEX ix_vl_current_account ON dbo.voucher_lines(current_account_id)
    WHERE current_account_id IS NOT NULL;
CREATE INDEX ix_vl_cost_center ON dbo.voucher_lines(cost_center_id) WHERE cost_center_id IS NOT NULL;
CREATE INDEX ix_vl_project ON dbo.voucher_lines(project_id) WHERE project_id IS NOT NULL;
CREATE INDEX ix_vl_vat_code ON dbo.voucher_lines(vat_code_id) WHERE vat_code_id IS NOT NULL;
GO

-- document_headers
CREATE INDEX ix_dh_company_date ON dbo.document_headers(company_id, document_date);
CREATE INDEX ix_dh_current_account ON dbo.document_headers(current_account_id)
    WHERE current_account_id IS NOT NULL;
CREATE INDEX ix_dh_e_document ON dbo.document_headers(e_document_uuid)
    WHERE e_document_uuid IS NOT NULL;
CREATE INDEX ix_dh_status ON dbo.document_headers(company_id, status);
GO

-- current_accounts
CREATE INDEX ix_ca_company_taxno ON dbo.current_accounts(company_id, tax_number)
    WHERE tax_number IS NOT NULL;
CREATE INDEX ix_ca_company_type ON dbo.current_accounts(company_id, type_id, is_active);
GO

-- bank_transactions
CREATE INDEX ix_bt_bank_account_date ON dbo.bank_transactions(bank_account_id, transaction_date);
CREATE INDEX ix_bt_reconciled ON dbo.bank_transactions(bank_account_id, is_reconciled)
    WHERE is_reconciled = 0;
GO

-- cash_transactions
CREATE INDEX ix_ct_cash_register_date ON dbo.cash_transactions(cash_register_id, transaction_date);
GO

-- negotiable_instruments
CREATE INDEX ix_ni_company_due ON dbo.negotiable_instruments(company_id, due_date) INCLUDE (status);
CREATE INDEX ix_ni_status ON dbo.negotiable_instruments(company_id, status);
GO

-- inventory_movements
CREATE INDEX ix_im_item_date ON dbo.inventory_movements(inventory_item_id, movement_date);
GO

-- exchange_rates
CREATE INDEX ix_er_lookup ON dbo.exchange_rates(rate_type_id, from_currency_code, to_currency_code, rate_date DESC);
GO

-- e_document_tracking
CREATE INDEX ix_edt_company_date ON dbo.e_document_tracking(company_id, issue_date);
CREATE INDEX ix_edt_status ON dbo.e_document_tracking(company_id, status);
CREATE INDEX ix_edt_uuid ON dbo.e_document_tracking(uuid) WHERE uuid IS NOT NULL;
GO

-- audit_logs  — yalnızca zaman bazlı erişim
CREATE INDEX ix_audit_company_date ON dbo.audit_logs(company_id, logged_at);
CREATE INDEX ix_audit_user_date ON dbo.audit_logs(user_id, logged_at);
CREATE INDEX ix_audit_table ON dbo.audit_logs(table_name, record_id);
GO

-- integration_queue
CREATE INDEX ix_iq_status_retry ON dbo.integration_queue(status, next_retry_at)
    WHERE status IN ('BEKLIYOR','TEKRAR_BEKLIYOR');
GO

-- depreciation_lines
CREATE INDEX ix_dep_fixed_asset ON dbo.depreciation_lines(fixed_asset_id, depreciation_date);
GO
