# ERP Integration Status

Tarih: 2026-04-02

Bu repo su an `Leyla Unified Platform` icinde embedded SQLite finance source-of-truth olarak kullaniliyor.

## Canli Dogrulanan Finance Akislari

- voucher create
- voucher post
- voucher reverse
- current account card create
- current account entry create
- treasury account create
- movement create
- payment create
- chart of accounts card create
- compliance document create
- finance workspace read
- trial balance read
- subledger read
- ledger read
- bank reconciliation read
- tax compliance read
- period close read
- e-document readiness read
- e-ledger read
- fiscal calendar read
- report snapshots read

## Runtime Sonucu

- database backend: `sqlite`
- database driver: `aiosqlite`
- finance extension status: `ready`
- finance extension version: `1.1.0`

## ERP Panel Durumu

Operasyonel:

- `core-platform`
- `finance-gl`
- `accounting-hub`
- `sales-pre`
- `order-fulfillment`
- `inventory`
- `warehouse-wms`
- `documents-workflow`
- `reporting-bi`
- `records-compliance`
- `ecommerce-2026`
- `omnichannel-pos`
- `customer-service`
- `integration-ipaas`
- `ai-automation`

Kismi:

- `dashboard`

GitHub uzerinden icerik gelistirilmesi gereken iskelet moduller:

- `procurement`
- `vendor-portal`
- `manufacturing-bom`
- `planning-mrp`
- `quality-qms`
- `maintenance-eam`
- `project-cost`
- `hr-workforce`
- `payroll-localization`
- `mobile-field`

## Tasarim Kurali

Yeni finance kapsamlarinda once bu repoda:

1. contract tanimi
2. backend servis davranisi
3. manifest surumu

guncellenir. ERP yalniz adaptor olarak kalir ve bu repodan yukleme yapar.
