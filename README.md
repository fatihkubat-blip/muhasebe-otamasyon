# Muhasebe Otomasyon

Bu repo artik ERP icine gomulu calisan finance extension kaynagidir. Ana calisma modeli ayri servis degil, `Leyla Unified Platform` icinde yuklenen embedded SQLite finance katmanidir.

## GitHub Kaynak Tasarimi

- Kaynak gercek: `backend/`
- Sozlesme gercek: `contracts/`
- UI ve pencere davranisi gercek: `contracts/ui-contract.json`
- Kesif ve surum gercek: `module-manifest.json`
- ERP tarafi yalniz adaptor ve loader katmanidir

Bu nedenle finansla ilgili yeni alanlar once bu repoda tanimlanir, sonra ERP bunlari `extensions/muhasebe-otamasyon` uzerinden yukler.

## Aktif Dizinler

- `backend/muhasebe_otamasyon_erp`: ERP'ye gomulu finance servis fabrikasi ve contract baglantisi
- `contracts/`: voucher, chart of accounts, current account, e-document ve reporting contract dosyalari
- `module-manifest.json`: extension discovery, surum, contract ve ERP surface tanimi

## Runtime Modeli

- Veritabani: SQLite
- Mod: embedded
- API yuzeyi: `/api/erp/finance/*`
- ERP panelleri: `/modules/finance-gl`, `/modules/accounting-hub`
- Storage tablolar: `journal_entries`, `journal_entry_lines`, `journal_entry_contexts`, `payments`, `account_movements`, `current_account_cards`, `current_account_entries`, `ledger_account_cards`, `treasury_accounts`, `compliance_documents`

## ERP Entegrasyon Akisi

1. ERP startup sirasinda manifest okunur.
2. `backend/muhasebe_otamasyon_erp` paketi import edilir.
3. Finance servis fabrikanin dondurdugu embedded servis ile yuklenir.
4. Public route'lar degismez, ERP yalniz bu repo contract'larina delege eder.

## SQLite Varsayimi

Bu repo icin operasyonel varsayim SQLite'tir. Yeni kurulumlarda hedef:

- local gelistirme: dosya tabanli SQLite
- ERP runtime: ortak SQLite session
- migration davranisi: SQLite ile uyumlu batch mod

## Legacy Alanlar

Repoda bulunan asagidaki klasorler eski standalone denemelerden kalmis olabilir:

- `app/`
- `scripts/`
- `sql/`

Bu alanlar yeni embedded ERP akisinda kaynak gercek degildir. Yeni finans davranisi `backend/`, `contracts/` ve `module-manifest.json` uzerinden yonetilir.

## Canli Durum

Guncel entegrasyon ve panel durumu icin:

- `docs/erp-integration-status.md`
