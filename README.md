# Muhasebe Otomasyonu — VUK Defter + Mizan Çekirdeği

PostgreSQL tabanlı, Docker ile çalıştırılabilir, VUK (Vergi Usul Kanunu) mantığına uygun muhasebe altyapısı.

---

## İçerik

```
.
├── docker-compose.yml          # PostgreSQL servisi
├── db/
│   ├── migrations/
│   │   ├── 001_create_schema.sql          # Temel tablolar
│   │   ├── 002_constraints_and_triggers.sql  # Trigger'lar ve kısıtlar
│   │   └── 003_views.sql                  # Yardımcı view'lar
│   └── seed/
│       └── 001_sample_data.sql            # Örnek veri
└── reports/
    ├── mizan.sql                # Hesap bazında borç/alacak + bakiye
    ├── buyuk_defter.sql         # Hesap hareket dökümü + koşan bakiye
    └── yevmiye.sql              # Fiş sırasıyla satır dökümü
```

---

## Şema Özeti

| Tablo | Açıklama |
|---|---|
| `company` | Firmalar |
| `fiscal_period` | Mali dönemler (`is_closed=true` iken işlem yapılamaz) |
| `account` | Hesap planı (THP kodlarıyla) |
| `journal_entry` | Yevmiye fişleri |
| `journal_line` | Fiş satırları (borç / alacak) |

### Kısıtlar ve Trigger'lar

- `journal_line.borclu` ve `alacakli` negatif olamaz (`CHECK`).
- Aynı satırda hem borç hem alacak `> 0` olamaz (`CHECK`).
- Her fişin **toplam borç = toplam alacak** olması zorunludur (AFTER trigger).
- `fiscal_period.is_closed = true` iken o döneme ait fiş / satır **eklenemez, güncellenemez, silinemez** (BEFORE trigger).

---

## Yerel Geliştirme

### Gereksinimler

- [Docker](https://docs.docker.com/get-docker/) ve Docker Compose

### 1) Veritabanını Ayağa Kaldırma

```bash
docker compose up -d
```

Sağlıklı olup olmadığını kontrol et:

```bash
docker compose ps
```

### 2) Migration'ları Uygulama

```bash
docker exec -i muhasebe_db psql -U muhasebe_usr -d muhasebe \
  < db/migrations/001_create_schema.sql

docker exec -i muhasebe_db psql -U muhasebe_usr -d muhasebe \
  < db/migrations/002_constraints_and_triggers.sql

docker exec -i muhasebe_db psql -U muhasebe_usr -d muhasebe \
  < db/migrations/003_views.sql
```

### 3) Seed Verilerini Yükleme

```bash
docker exec -i muhasebe_db psql -U muhasebe_usr -d muhasebe \
  < db/seed/001_sample_data.sql
```

### 4) Örnek INSERT

```sql
-- psql bağlantısı
docker exec -it muhasebe_db psql -U muhasebe_usr -d muhasebe

-- Yeni bir yevmiye fişi (önce journal_entry, sonra journal_line)
INSERT INTO journal_entry (company_id, period_id, fis_no, fis_tarihi, aciklama, kaynak)
VALUES (1, 1, 'YF-2024-004', '2024-02-01', 'Test fişi', 'MANUEL');

-- Dengeli satırlar (borç = alacak = 500)
INSERT INTO journal_line (entry_id, account_id, borclu, alacakli, sira_no)
VALUES
  (currval('journal_entry_id_seq'),
   (SELECT id FROM account WHERE hesap_kodu='100' AND company_id=1), 500, 0, 1),
  (currval('journal_entry_id_seq'),
   (SELECT id FROM account WHERE hesap_kodu='102' AND company_id=1), 0, 500, 2);
```

---

## Raporları Çalıştırma

Raporlardaki `:p_company_id`, `:p_baslangic`, `:p_bitis` ve `:p_hesap_kodu` parametrelerini psql `\set` komutuyla tanımlayın:

```bash
docker exec -it muhasebe_db psql -U muhasebe_usr -d muhasebe
```

### Mizan

```sql
\set p_company_id 1
\set p_baslangic '''2024-01-01'''
\set p_bitis     '''2024-12-31'''
\i /reports/mizan.sql
```

Veya tek satırda:

```bash
docker exec -i muhasebe_db psql -U muhasebe_usr -d muhasebe \
  -v p_company_id=1 \
  -v "p_baslangic='2024-01-01'" \
  -v "p_bitis='2024-12-31'" \
  < reports/mizan.sql
```

### Büyük Defter

```bash
docker exec -i muhasebe_db psql -U muhasebe_usr -d muhasebe \
  -v p_company_id=1 \
  -v "p_hesap_kodu='102'" \
  -v "p_baslangic='2024-01-01'" \
  -v "p_bitis='2024-12-31'" \
  < reports/buyuk_defter.sql
```

### Yevmiye

```bash
docker exec -i muhasebe_db psql -U muhasebe_usr -d muhasebe \
  -v p_company_id=1 \
  -v "p_baslangic='2024-01-01'" \
  -v "p_bitis='2024-12-31'" \
  < reports/yevmiye.sql
```

---

## Bağlantı Bilgileri (Varsayılan)

| Parametre | Değer |
|---|---|
| Host | `localhost` |
| Port | `5432` |
| Veritabanı | `muhasebe` |
| Kullanıcı | `muhasebe_usr` |
| Şifre | `muhasebe_pass` |

> **Not:** GİB e-belge entegrasyonları bu PR kapsamı dışındadır.