-- ============================================================
-- V010: Temel Stored Procedure'lar
-- §8 (Fiş oluşturma / ters kayıt), §20 (Dönem kapanış),
-- §24 (Audit trigger), §8.7 (Sıralı yevmiye numarası)
-- ============================================================

SET NOCOUNT ON;
GO

-- --------------------------------------------------------
-- SP: Sıralı Yevmiye Numarası Üret  — §8.7
-- --------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_next_journal_sequence
    @company_id      INT,
    @fiscal_year     SMALLINT,
    @voucher_type_id INT,
    @next_number     BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    UPDATE dbo.voucher_sequences
    SET    last_number = last_number + 1
    WHERE  company_id      = @company_id
      AND  fiscal_year     = @fiscal_year
      AND  voucher_type_id = @voucher_type_id;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.voucher_sequences (company_id, fiscal_year, voucher_type_id, last_number)
        VALUES (@company_id, @fiscal_year, @voucher_type_id, 1);
        SET @next_number = 1;
    END
    ELSE
    BEGIN
        SELECT @next_number = last_number
        FROM   dbo.voucher_sequences
        WHERE  company_id      = @company_id
          AND  fiscal_year     = @fiscal_year
          AND  voucher_type_id = @voucher_type_id;
    END

    COMMIT TRANSACTION;
END;
GO

-- --------------------------------------------------------
-- SP: Ters Fiş Üret  — §8.6
-- --------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_create_reverse_voucher
    @original_voucher_id INT,
    @reverse_date        DATE,
    @created_by          INT,
    @new_voucher_id      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @company_id      INT,
        @fiscal_year_id  INT,
        @fiscal_period_id INT,
        @voucher_type_id INT,
        @fiscal_year     SMALLINT,
        @next_seq        BIGINT,
        @voucher_no      NVARCHAR(50),
        @description     NVARCHAR(500);

    -- Orijinal fişi kontrol et
    SELECT
        @company_id       = company_id,
        @fiscal_year_id   = fiscal_year_id,
        @voucher_type_id  = voucher_type_id,
        @description      = N'TERS KAYIT: ' + voucher_no
    FROM dbo.vouchers
    WHERE id = @original_voucher_id AND status = N'ONAYLANDI';

    IF @company_id IS NULL
    BEGIN
        RAISERROR(N'Orijinal fiş bulunamadı veya onaylı değil.', 16, 1);
        RETURN -1;
    END

    -- Ters kaydın dönemini bul
    SELECT @fiscal_period_id = id, @fiscal_year = fy.fiscal_year
    FROM   dbo.fiscal_periods fp
    INNER JOIN dbo.fiscal_years fy ON fy.id = fp.fiscal_year_id
    WHERE  fp.company_id = @company_id
      AND  @reverse_date BETWEEN fp.start_date AND fp.end_date
      AND  fp.is_closed  = 0;

    IF @fiscal_period_id IS NULL
    BEGIN
        RAISERROR(N'Ters kayıt tarihi için açık bir dönem bulunamadı.', 16, 1);
        RETURN -1;
    END

    EXEC dbo.sp_next_journal_sequence
        @company_id      = @company_id,
        @fiscal_year     = @fiscal_year,
        @voucher_type_id = @voucher_type_id,
        @next_number     = @next_seq OUTPUT;

    SELECT @fiscal_year_id = id
    FROM   dbo.fiscal_years
    WHERE  company_id = @company_id AND fiscal_year = @fiscal_year;

    SET @voucher_no = N'TERS-' + CAST(@next_seq AS NVARCHAR(20));

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Ters fişi ekle
        INSERT INTO dbo.vouchers (
            company_id, fiscal_year_id, fiscal_period_id, voucher_type_id,
            journal_sequence_no, voucher_no,
            document_date, posting_date,
            description, module_source,
            total_debit_kurus, total_credit_kurus,
            status, reverse_of_id, created_by
        )
        SELECT
            company_id, @fiscal_year_id, @fiscal_period_id, voucher_type_id,
            @next_seq, @voucher_no,
            @reverse_date, @reverse_date,
            @description, N'TERS_KAYIT',
            total_debit_kurus, total_credit_kurus,
            N'ONAYLANDI', @original_voucher_id, @created_by
        FROM dbo.vouchers
        WHERE id = @original_voucher_id;

        SET @new_voucher_id = SCOPE_IDENTITY();

        -- Orijinal satırları borç/alacak yer değiştirerek kopyala
        INSERT INTO dbo.voucher_lines (
            voucher_id, line_no, company_id, branch_id,
            account_id, current_account_id,
            description,
            debit_kurus, credit_kurus,
            currency_code, exchange_rate, foreign_amount,
            vat_code_id, vat_base_kurus, vat_amount_kurus,
            cost_center_id, project_id,
            created_by
        )
        SELECT
            @new_voucher_id, line_no, company_id, branch_id,
            account_id, current_account_id,
            description,
            credit_kurus,   -- BORÇ/ALACAK yer değiştirildi
            debit_kurus,
            currency_code, exchange_rate, foreign_amount,
            vat_code_id, vat_base_kurus, vat_amount_kurus,
            cost_center_id, project_id,
            @created_by
        FROM dbo.voucher_lines
        WHERE voucher_id = @original_voucher_id;

        -- Orijinal fişi ters kayıt ile işaretle
        UPDATE dbo.vouchers
        SET    is_reversed     = 1,
               reversed_by_id = @new_voucher_id,
               updated_at     = SYSUTCDATETIME(),
               updated_by     = @created_by
        WHERE  id = @original_voucher_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- --------------------------------------------------------
-- SP: Dönem Kontrol & Kapanış Checklist  — §20
-- --------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_period_close_checklist
    @company_id       INT,
    @fiscal_period_id INT,
    @user_id          INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Dönem var mı?
    IF NOT EXISTS (
        SELECT 1 FROM dbo.fiscal_periods
        WHERE id = @fiscal_period_id AND company_id = @company_id AND is_closed = 0
    )
    BEGIN
        RAISERROR(N'Dönem bulunamadı veya zaten kapalı.', 16, 1);
        RETURN;
    END

    -- Dengesi bozuk fiş var mı? §8.3
    IF EXISTS (
        SELECT 1 FROM dbo.vouchers
        WHERE company_id       = @company_id
          AND fiscal_period_id = @fiscal_period_id
          AND total_debit_kurus <> total_credit_kurus
    )
    BEGIN
        RAISERROR(N'Dengesi bozuk fiş var - dönem kapatılamaz.', 16, 1);
        RETURN;
    END

    -- Taslak fiş var mı?
    IF EXISTS (
        SELECT 1 FROM dbo.vouchers
        WHERE company_id       = @company_id
          AND fiscal_period_id = @fiscal_period_id
          AND status IN (N'TASLAK', N'ONAY_BEKLIYOR')
    )
    BEGIN
        RAISERROR(N'Onaylanmamış taslak fiş var - dönem kapatılamaz.', 16, 1);
        RETURN;
    END

    -- Muhasebeleştirilmemiş belge var mı?
    IF EXISTS (
        SELECT 1 FROM dbo.document_headers
        WHERE company_id       = @company_id
          AND fiscal_period_id = @fiscal_period_id
          AND is_accounted      = 0
          AND is_cancelled      = 0
    )
    BEGIN
        RAISERROR(N'Muhasebeleştirilmemiş belge var - dönem kapatılamaz.', 16, 1);
        RETURN;
    END

    -- Dönem kapat
    UPDATE dbo.fiscal_periods
    SET    is_closed   = 1,
           closed_at   = SYSUTCDATETIME(),
           closed_by   = @user_id
    WHERE  id = @fiscal_period_id;

    -- Audit log
    INSERT INTO dbo.audit_logs (
        company_id, user_id, action, table_name, record_id,
        description, logged_at
    )
    VALUES (
        @company_id, @user_id, N'PERIOD_CLOSE', N'fiscal_periods',
        CAST(@fiscal_period_id AS NVARCHAR),
        N'Dönem kapatıldı.', SYSUTCDATETIME()
    );
END;
GO

-- --------------------------------------------------------
-- TRIGGER: Audit - Fiş değişikliği  — §24
-- --------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_vouchers_audit
ON dbo.vouchers
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Onaylanmış fişe doğrudan satır üstü yazma yasak §8.5
    IF EXISTS (
        SELECT 1
        FROM deleted d
        INNER JOIN inserted i ON i.id = d.id
        WHERE d.status = N'ONAYLANDI'
          AND (   i.total_debit_kurus  <> d.total_debit_kurus
               OR i.total_credit_kurus <> d.total_credit_kurus
               OR i.posting_date       <> d.posting_date
              )
    )
    BEGIN
        RAISERROR(N'Onaylanmış fişte doğrudan değişiklik yapılamaz. Ters kayıt kullanın.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Değişiklikleri logla
    INSERT INTO dbo.audit_logs (
        company_id, action, table_name, record_id,
        old_value_json, new_value_json, logged_at
    )
    SELECT
        COALESCE(i.company_id, d.company_id),
        CASE WHEN i.id IS NULL THEN N'DELETE' ELSE N'UPDATE' END,
        N'vouchers',
        CAST(COALESCE(i.id, d.id) AS NVARCHAR),
        (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        CASE WHEN i.id IS NOT NULL
             THEN (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
             ELSE NULL
        END,
        SYSUTCDATETIME()
    FROM deleted d
    FULL OUTER JOIN inserted i ON i.id = d.id;
END;
GO

-- --------------------------------------------------------
-- TRIGGER: Audit — audit_logs silinmesini engelle  — §24.2
-- --------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_audit_logs_prevent_delete
ON dbo.audit_logs
INSTEAD OF DELETE, UPDATE
AS
BEGIN
    RAISERROR(N'Denetim izi kayıtları değiştirilemez veya silinemez.', 16, 1);
    ROLLBACK TRANSACTION;
END;
GO
