# Muhasebe Otomasyon

Turkiye muhasebe mevzuatına uygun, SQL tabanlı muhasebe çekirdeği.

Bu sürümde:
- SQL Server odaklı migration yapısı (`sql/migrations/V001..V010`)
- Tek Düzen Hesap Planı tam seed verisi (`sql/seed/seed_full.sql`)
- Standart rapor SQL dosyaları (mizan, yevmiye, büyük defter, muavin, bilanço, gelir tablosu, vergi, yaşlandırma)
- FastAPI tabanlı modüler API (`app/routers`, `app/services`, `app/schemas`)

## Mimari

- Uygulama: FastAPI
- ORM/DB: SQLAlchemy 2.x
- Üretim DB: SQL Server (`mssql+pyodbc`)
- Geliştirme DB: SQLite (`sqlite:///./data/muhasebe.db`)
- Tutar saklama: BIGINT kuruş
- Denetim: `audit_logs` ve trigger yapısı

## Dizin Yapısı

- `app/config.py`: Ortam ve ayarlar
- `app/database.py`: Engine, session, health check
- `app/main.py`: Uygulama girişi ve router kayıtları
- `app/routers/`: API uçları
- `app/services/`: İş kuralları
- `app/schemas/`: Pydantic şemaları
- `sql/migrations/`: Versiyonlu T-SQL migration dosyaları
- `sql/seed/seed_full.sql`: Referans veriler ve hesap planı
- `sql/reports/`: Standart rapor SQL dosyaları

## Kurulum

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload
```

## SQL Server Bağlantısı

`.env` içinde:

```env
DATABASE_URL=mssql+pyodbc://sa:SIFRE@localhost:1433/muhasebe?driver=ODBC+Driver+18+for+SQL+Server&TrustServerCertificate=yes
```

Geliştirme için SQLite:

```env
DATABASE_URL=sqlite:///./data/muhasebe.db
```

## SQL Server Kurulum (Ayrı Program Gerekmez)

SSMS gibi ayrı bir program kullanmadan, sadece terminal ile migration ve seed calistirabilirsiniz:

```bash
export DATABASE_URL="mssql+pyodbc://sa:SIFRE@localhost:1433/muhasebe?driver=ODBC+Driver+18+for+SQL+Server&TrustServerCertificate=yes"
python3 scripts/sqlserver_bootstrap.py
```

Alternatif olarak URL'i argumanla verebilirsiniz:

```bash
python3 scripts/sqlserver_bootstrap.py \
	--database-url "mssql+pyodbc://sa:SIFRE@localhost:1433/muhasebe?driver=ODBC+Driver+18+for+SQL+Server&TrustServerCertificate=yes"
```

Sonrasinda API'yi SQL Server ile baslatmak icin:

```bash
uvicorn app.main:app --host 127.0.0.1 --port 8001
```

## Tamamen Ayrı SQL Server Profili

SQLite'dan tamamen ayri calismak icin bu profili kullanin:

```bash
cp .env.sqlserver.example .env.sqlserver
# .env.sqlserver icinde DATABASE_URL ve SECRET_KEY degerlerini duzenleyin
```

1) SQL Server schema + seed yukleme:

```bash
set -a; source .env.sqlserver; set +a
python3 scripts/sqlserver_bootstrap.py
```

2) API'yi sadece SQL Server profili ile baslatma:

```bash
./scripts/start_sqlserver.sh
```

3) SQL Server smoke test:

```bash
./scripts/smoke_sqlserver.sh
```

Bu akis SQLite dosyalarina bagimli degildir ve ek bir GUI araci gerektirmez.

## API Prefix

Tüm uçlar varsayılan olarak:

- `/api/v1`

## Ana Uçlar

- Şirket:
- `POST /api/v1/companies`
- `GET /api/v1/companies`
- `PATCH /api/v1/companies/{company_id}`

- Hesap Planı:
- `POST /api/v1/accounts`
- `GET /api/v1/accounts`
- `GET /api/v1/accounts/{account_id}/balance`

- Cari:
- `POST /api/v1/current-accounts`
- `GET /api/v1/current-accounts`

- Belge:
- `POST /api/v1/documents`
- `GET /api/v1/documents`

- Fiş:
- `POST /api/v1/vouchers`
- `GET /api/v1/vouchers`
- `POST /api/v1/vouchers/{voucher_id}/approve`
- `POST /api/v1/vouchers/{voucher_id}/reverse`

- Rapor:
- `POST /api/v1/reports/trial-balance`
- `POST /api/v1/reports/journal`
- `POST /api/v1/reports/general-ledger`
- `POST /api/v1/reports/sub-ledger`
- `POST /api/v1/reports/balance-sheet`
- `POST /api/v1/reports/income-statement`
- `POST /api/v1/reports/tax`
- `POST /api/v1/reports/aging`

- Dönem Sonu:
- `GET /api/v1/period-end/checklist`
- `POST /api/v1/period-end/close-period`
- `POST /api/v1/period-end/close-fiscal-year`

- Parametreler:
- `GET /api/v1/parameters/system`
- `GET /api/v1/parameters/regulatory`
- `GET /api/v1/parameters/vat-codes`

## SQL Raporları

`sql/reports/` altında:
- `trial_balance.sql`
- `journal.sql`
- `general_ledger.sql`
- `sub_ledger.sql`
- `balance_sheet.sql`
- `income_statement.sql`
- `tax_reports.sql`
- `aging_report.sql`

Bu dosyalar doğrudan SQL Server üzerinde çalıştırılabilir.

## Notlar

- Bu proje teknik çekirdek sağlar; nihai mevzuat uyumu için SMMM/YMM doğrulaması gerekir.
- Üretimde migration yönetimi için Flyway/Alembic süreçleri kullanılmalıdır.
