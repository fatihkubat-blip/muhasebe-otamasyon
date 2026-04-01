-- ============================================================
-- 002_constraints_and_triggers.sql
-- Kapalı dönem koruması + borç=alacak dengesi kontrolleri
-- ============================================================

-- ------------------------------------------------------------
-- 1. Kapalı dönem guard — journal_entry
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_period_closed_entry()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_closed BOOLEAN;
BEGIN
    -- DELETE için OLD, INSERT/UPDATE için NEW kullan
    SELECT is_closed INTO v_closed
      FROM fiscal_period
     WHERE id = COALESCE(NEW.period_id, OLD.period_id);

    IF v_closed THEN
        RAISE EXCEPTION
            'Mali dönem kapalıdır (period_id=%). Yevmiye fişi eklenemez/güncellenemez/silinemez.',
            COALESCE(NEW.period_id, OLD.period_id);
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE OR REPLACE TRIGGER trg_period_closed_entry_ins_upd
    BEFORE INSERT OR UPDATE ON journal_entry
    FOR EACH ROW EXECUTE FUNCTION fn_check_period_closed_entry();

CREATE OR REPLACE TRIGGER trg_period_closed_entry_del
    BEFORE DELETE ON journal_entry
    FOR EACH ROW EXECUTE FUNCTION fn_check_period_closed_entry();

-- ------------------------------------------------------------
-- 2. Kapalı dönem guard — journal_line (entry üzerinden)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_period_closed_line()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_closed   BOOLEAN;
    v_entry_id INT;
BEGIN
    v_entry_id := COALESCE(NEW.entry_id, OLD.entry_id);

    SELECT fp.is_closed INTO v_closed
      FROM fiscal_period fp
      JOIN journal_entry je ON je.period_id = fp.id
     WHERE je.id = v_entry_id;

    IF v_closed THEN
        RAISE EXCEPTION
            'Mali dönem kapalıdır. Fiş satırı eklenemez/güncellenemez/silinemez (entry_id=%).',
            v_entry_id;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE OR REPLACE TRIGGER trg_period_closed_line_ins_upd
    BEFORE INSERT OR UPDATE ON journal_line
    FOR EACH ROW EXECUTE FUNCTION fn_check_period_closed_line();

CREATE OR REPLACE TRIGGER trg_period_closed_line_del
    BEFORE DELETE ON journal_line
    FOR EACH ROW EXECUTE FUNCTION fn_check_period_closed_line();

-- ------------------------------------------------------------
-- 3. Borç = Alacak dengesi kontrolü — yevmiye fişi
--    Her INSERT/UPDATE/DELETE'ten sonra ilgili fişin dengesi
--    bozulmuşsa hata fırlatır (AFTER trigger).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_entry_balance()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_entry_id  INT;
    v_borclu    NUMERIC(18,2);
    v_alacakli  NUMERIC(18,2);
BEGIN
    -- Hangi fiş etkilendi?
    v_entry_id := COALESCE(NEW.entry_id, OLD.entry_id);

    SELECT COALESCE(SUM(borclu), 0),
           COALESCE(SUM(alacakli), 0)
      INTO v_borclu, v_alacakli
      FROM journal_line
     WHERE entry_id = v_entry_id;

    -- Satırlar varsa ve denge bozuksa hata ver.
    -- (Tüm satırlar silinmişse 0=0 => geçer)
    IF v_borclu <> v_alacakli THEN
        RAISE EXCEPTION
            'Yevmiye fişi dengeli değil (entry_id=%). Toplam borç=%, toplam alacak=%.',
            v_entry_id, v_borclu, v_alacakli;
    END IF;

    RETURN NULL;  -- AFTER trigger; dönüş değeri önemsiz
END;
$$;

CREATE OR REPLACE TRIGGER trg_entry_balance
    AFTER INSERT OR UPDATE OR DELETE ON journal_line
    FOR EACH ROW EXECUTE FUNCTION fn_check_entry_balance();

-- ------------------------------------------------------------
-- 4. Otomatik guncelleme_ts güncelleme
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_guncelleme_ts()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.guncelleme_ts := NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_guncelleme_company
    BEFORE UPDATE ON company
    FOR EACH ROW EXECUTE FUNCTION fn_set_guncelleme_ts();

CREATE OR REPLACE TRIGGER trg_guncelleme_fiscal_period
    BEFORE UPDATE ON fiscal_period
    FOR EACH ROW EXECUTE FUNCTION fn_set_guncelleme_ts();

CREATE OR REPLACE TRIGGER trg_guncelleme_account
    BEFORE UPDATE ON account
    FOR EACH ROW EXECUTE FUNCTION fn_set_guncelleme_ts();

CREATE OR REPLACE TRIGGER trg_guncelleme_journal_entry
    BEFORE UPDATE ON journal_entry
    FOR EACH ROW EXECUTE FUNCTION fn_set_guncelleme_ts();

CREATE OR REPLACE TRIGGER trg_guncelleme_journal_line
    BEFORE UPDATE ON journal_line
    FOR EACH ROW EXECUTE FUNCTION fn_set_guncelleme_ts();
