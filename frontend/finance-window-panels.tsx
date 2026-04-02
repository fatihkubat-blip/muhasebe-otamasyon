"use client";

import { useEffect, useEffectEvent, useRef, useState, type KeyboardEvent as ReactKeyboardEvent } from "react";

import type {
  BankReconciliationWorkspace,
  ChartOfAccountsWorkspace,
  CurrentAccountWorkspace,
  EDocumentIntegrationReadiness,
  EDocumentWorkspace,
  ELedgerWorkspace,
  FinanceParametersWorkspace,
  FinanceWorkspace,
  FiscalCalendarWorkspace,
  LedgerWorkspace,
  PeriodCloseWorkspace,
  ReportSnapshotsWorkspace,
  SubledgerWorkspace,
  TaxComplianceWorkspace,
  TrialBalanceWorkspace,
  VoucherDetail,
  VoucherTemplate,
} from "@/lib/api";
import {
  createChartAccountCard,
  createCurrentAccountCard,
  createCurrentAccountEntry,
  createFinanceIntegratorProfile,
  createWindowSession,
  getTrialBalanceWorkspace,
  postFinanceVoucher,
  reverseFinanceVoucher,
} from "@/lib/api";
import {
  getFinanceUiPopupActions,
  getFinanceUiRules,
  getFinanceUiSourceAction,
  getFinanceUiStatusBadges,
  getFinanceUiSubtitle,
  getFinanceUiTitle,
} from "./finance-ui-contract";
import { openDeferredPopup, openModuleWindow } from "@/lib/window-actions";
import { useFinanceUiContract } from "./finance-ui-contract-provider";

import styles from "./finance-window-panels.module.css";

const API_BASE_URL = process.env.NEXT_PUBLIC_LEYLA_API_BASE_URL ?? "http://127.0.0.1:8000";
const VOUCHER_RULES = [
  "Borc ve alacak toplamlari esit olmadan fis kaydi tamamlanmaz.",
  "Sirket, sube, donem ve defter baglami ayri pencere oturumunda saklanir.",
  "Belge numarasi benzersiz olmadan kayit kabul edilmez.",
  "Kaydetme sonrasi detay, fis listesi ve buyuk defter pencereleri ayri acilir.",
];

const VOUCHER_TYPE_META: Record<string, { label: string; documentCode: string; defaultDescription: string }> = {
  mahsup: { label: "Mahsup Fisi", documentCode: "MAHSUP", defaultDescription: "Manuel mahsup fisi" },
  tahsil: { label: "Tahsil Fisi", documentCode: "TAHSIL", defaultDescription: "Cari tahsilat fisi" },
  tediye: { label: "Tediye Fisi", documentCode: "TEDIYE", defaultDescription: "Cari odeme fisi" },
  acilis: { label: "Acilis Fisi", documentCode: "ACILIS", defaultDescription: "Donem acilis fizi" },
  kapanis: { label: "Kapanis Fisi", documentCode: "KAPANIS", defaultDescription: "Donem kapanis fizi" },
  ters_kayit: { label: "Ters Kayit Fisi", documentCode: "TERS", defaultDescription: "Ters kayit duzeltme fizi" },
};

function money(value: number, currency = "TRY") {
  return `${currency} ${value.toLocaleString("tr-TR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function dateLabel(value: string) {
  return new Intl.DateTimeFormat("tr-TR", { year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(value));
}

function SourceBand() {
  const uiContract = useFinanceUiContract();
  const sourceBand = uiContract.source_band;
  return (
    <section className={styles.commandBar}>
      {sourceBand.map((item) => (
        <span key={item.label} className={item.tone === "critical" ? `${styles.commandChip} ${styles.commandChipCritical}` : styles.commandChip}>
          {item.label}
        </span>
      ))}
    </section>
  );
}

function FinanceContextBar({ title, subtitle, templateCode }: { title: string; subtitle: string; templateCode: string }) {
  const uiContract = useFinanceUiContract();
  const resolvedTitle = getFinanceUiTitle(uiContract, templateCode, title);
  const resolvedSubtitle = getFinanceUiSubtitle(uiContract, templateCode, subtitle);
  const badges = getFinanceUiStatusBadges(uiContract, templateCode);
  return (
    <div className={styles.windowIntro}>
      <div>
        <div className={styles.windowTitle}>{resolvedTitle}</div>
        <div className={styles.windowSubtitle}>{resolvedSubtitle}</div>
      </div>
      <div className={styles.statusGroup}>
        {badges.map((badge) => (
          <span key={badge} className={styles.statusBadge}>{badge}</span>
        ))}
      </div>
    </div>
  );
}

function ContextTable({ rows }: { rows: Array<{ label: string; value: string }> }) {
  return (
    <table className={styles.table}>
      <tbody>
        {rows.map((row) => (
          <tr key={row.label}>
            <td className={styles.labelCell}>{row.label}</td>
            <td>{row.value}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function RuleList({ items }: { items: string[] }) {
  return (
    <ul className={styles.ruleList}>
      {items.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ul>
  );
}

function FinancePopupActionBar({
  moduleSlug = "finance-gl",
  templateCode,
  sourceAction,
}: {
  moduleSlug?: string;
  templateCode?: string;
  sourceAction: string;
}) {
  const uiContract = useFinanceUiContract();
  const actions = getFinanceUiPopupActions(uiContract);
  const resolvedSourceAction = templateCode ? getFinanceUiSourceAction(uiContract, templateCode, sourceAction) : sourceAction;
  return (
    <div className={styles.actionRow}>
      {actions.map((item) => (
        <button
          key={`${resolvedSourceAction}-${item.template_code}`}
          type="button"
          className={styles.actionButton}
          onClick={() =>
            item.template_code &&
            void openModuleWindow({
              moduleSlug,
              templateCode: item.template_code,
              sourceRoute: `/modules/${moduleSlug}`,
              sourceAction: `${resolvedSourceAction}-${item.template_code}`,
            })
          }
        >
          {item.label} Penceresi
        </button>
      ))}
    </div>
  );
}

export function FinanceOverviewWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: FinanceWorkspace;
  moduleSlug?: string;
}) {
  const uiContract = useFinanceUiContract();
  const totalBalance = workspace.chart_of_accounts.reduce((sum, item) => sum + item.current_balance, 0);

  return (
    <div className={styles.desktopSurface}>
      <FinanceContextBar
        templateCode="overview"
        title="Muhasebe Operasyon Masasi"
        subtitle="ETA, Logo ve Mikro masaustu duzenine yakin pencere bazli calisma yuzeyi"
      />
      <SourceBand />
      <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="overview" sourceAction="finance-overview" />
      <section className={styles.metrics}>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Hesap</div>
          <div className={styles.metricValue}>{workspace.chart_of_accounts.length}</div>
          <div className={styles.metricFoot}>Canli hesap plani satirlari</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Fis</div>
          <div className={styles.metricValue}>{workspace.journal_entries.length}</div>
          <div className={styles.metricFoot}>Kayitli yevmiye ve mahsup fisleri</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Mizan Satiri</div>
          <div className={styles.metricValue}>{workspace.trial_balance.length}</div>
          <div className={styles.metricFoot}>Drill-down ile buyuk deftere iner</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Toplam Bakiye</div>
          <div className={styles.metricValueSmall}>{money(totalBalance)}</div>
          <div className={styles.metricFoot}>Yasal defter bakiyesi</div>
        </article>
      </section>

      <section className={styles.gridTwo}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Fis ve Yevmiye Akisi</div>
          <div className={styles.panelBody}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Fis No</th>
                  <th>Tarih</th>
                  <th>Durum</th>
                  <th>Satir</th>
                  <th>Kaynak</th>
                  <th>Pencere</th>
                </tr>
              </thead>
              <tbody>
                {workspace.journal_entries.slice(0, 10).map((entry) => (
                  <tr key={entry.id}>
                    <td>{entry.entry_number}</td>
                    <td>{dateLabel(entry.entry_date)}</td>
                    <td>{entry.status}</td>
                    <td>{entry.lines.length}</td>
                    <td>{entry.source_type ?? "manuel"}</td>
                    <td>
                      <button
                        type="button"
                        className={styles.actionButton}
                        onClick={() =>
                          void openModuleWindow({
                            moduleSlug,
                            templateCode: "voucher-detail",
                            recordId: entry.id,
                            sourceRoute: `/modules/${moduleSlug}`,
                            sourceAction: "finance-overview-entry-detail",
                          })
                        }
                      >
                        Detay Ac
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className={styles.panel}>
          <div className={styles.panelHeader}>Uyum Belgeleri</div>
          <div className={styles.panelBody}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Tur</th>
                  <th>Referans</th>
                  <th>Donem</th>
                  <th>Durum</th>
                  <th>Pencere</th>
                </tr>
              </thead>
              <tbody>
                {workspace.compliance_documents.slice(0, 10).map((item) => (
                  <tr key={item.id}>
                    <td>{item.document_type}</td>
                    <td>{item.reference_code ?? "-"}</td>
                    <td>{item.period_key ?? "-"}</td>
                    <td>{item.status}</td>
                    <td>
                      <button
                        type="button"
                        className={styles.actionButton}
                        onClick={() =>
                          void openModuleWindow({
                            moduleSlug,
                            templateCode: "e-documents",
                            sourceRoute: `/modules/${moduleSlug}`,
                            sourceAction: "finance-overview-e-document",
                          })
                        }
                      >
                        e-Belge Ac
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </section>

      <section className={styles.gridTwo}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Hesap Plani Ozet Tablosu</div>
          <div className={styles.panelBody}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Kod</th>
                  <th>Ad</th>
                  <th>Tur</th>
                  <th>Bakiye</th>
                </tr>
              </thead>
              <tbody>
                {workspace.chart_of_accounts.slice(0, 8).map((item) => (
                  <tr key={item.id}>
                    <td>{item.code}</td>
                    <td>{item.name}</td>
                    <td>{item.account_type}</td>
                    <td>{money(item.current_balance, item.currency)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className={styles.panel}>
          <div className={styles.panelHeader}>Pencere Kurallari ve Parametreler</div>
          <div className={styles.panelBody}>
            <ContextTable
              rows={[
                { label: "Donem Anahtari", value: workspace.fiscal_period.period_key },
                { label: "Donem Durumu", value: workspace.fiscal_period.status },
                { label: "Posting Modu", value: workspace.fiscal_period.posting_mode },
                { label: "Parametre Adedi", value: `${workspace.parameter_items.length}` },
              ]}
            />
            <RuleList items={getFinanceUiRules(uiContract, "voucher-new", VOUCHER_RULES)} />
          </div>
        </section>
      </section>
    </div>
  );
}

export function VoucherNewWindow({
  template,
  moduleSlug = "finance-gl",
}: {
  template: VoucherTemplate;
  moduleSlug?: string;
}) {
  const uiContract = useFinanceUiContract();
  type VoucherLineState = {
    accountCode: string;
    description: string;
    debit: string;
    credit: string;
  };

  const [entryNumber, setEntryNumber] = useState(template.next_entry_number);
  const [documentNumber, setDocumentNumber] = useState(template.next_document_number);
  const [entryDate, setEntryDate] = useState(template.entry_date);
  const [documentDate, setDocumentDate] = useState(template.entry_date);
  const [dueDate, setDueDate] = useState(template.entry_date);
  const [documentTypeCode, setDocumentTypeCode] = useState("MAHSUP");
  const [description, setDescription] = useState("Manuel mahsup fisi");
  const [voucherType, setVoucherType] = useState(template.voucher_types[0] ?? "mahsup");
  const accountOptions = [...template.debit_account_options, ...template.credit_account_options].filter(
    (item, index, list) => list.findIndex((entry) => entry.code === item.code) === index,
  );
  const [lines, setLines] = useState<VoucherLineState[]>([
    {
      accountCode: template.debit_account_options[0]?.code ?? "120.01",
      description: "Manuel mahsup fisi",
      debit: "1000",
      credit: "0",
    },
    {
      accountCode: template.credit_account_options[1]?.code ?? template.credit_account_options[0]?.code ?? "100.01",
      description: "Manuel mahsup fisi",
      debit: "0",
      credit: "1000",
    },
  ]);
  const [counterpartyCode, setCounterpartyCode] = useState("CARI-0001");
  const [counterpartyName, setCounterpartyName] = useState("Merkez Musteri");
  const [currency, setCurrency] = useState("TRY");
  const [exchangeRate, setExchangeRate] = useState("1");
  const [costCenterCode, setCostCenterCode] = useState("MGMR");
  const [profitCenterCode, setProfitCenterCode] = useState("PRF-01");
  const [projectCode, setProjectCode] = useState("ERP-TR-2026");
  const [departmentCode, setDepartmentCode] = useState("MUHASEBE");
  const [warehouseCode, setWarehouseCode] = useState("MERKEZ");
  const [taxCode, setTaxCode] = useState("KDV20");
  const [vatRate, setVatRate] = useState("20");
  const [withholdingRate, setWithholdingRate] = useState("0");
  const [eDocumentProfile, setEDocumentProfile] = useState("temel-fatura");
  const [integratorProfile, setIntegratorProfile] = useState(template.integration_profiles[1] ?? template.integration_profiles[0] ?? "ozel-entegrator-test");
  const [documentReference, setDocumentReference] = useState("REF-2026-0001");
  const [paymentReference, setPaymentReference] = useState("ODEME-PLANI-01");
  const [accountLookupLineIndex, setAccountLookupLineIndex] = useState<number | null>(0);
  const [accountLookupRows, setAccountLookupRows] = useState(accountOptions.slice(0, 12));
  const [message, setMessage] = useState("");
  const lookupPopupLockedRef = useRef(false);
  const popupSequenceRef = useRef(0);
  const saveButtonRef = useRef<HTMLButtonElement | null>(null);
  const voucherMeta = VOUCHER_TYPE_META[voucherType] ?? VOUCHER_TYPE_META.mahsup;
  const debitTotal = lines.reduce((sum, line) => sum + (Number(line.debit) || 0), 0);
  const creditTotal = lines.reduce((sum, line) => sum + (Number(line.credit) || 0), 0);

  function selectVoucherType(nextType: string) {
    const nextMeta = VOUCHER_TYPE_META[nextType] ?? VOUCHER_TYPE_META.mahsup;
    setVoucherType(nextType);
    setDocumentTypeCode(nextMeta.documentCode);
    if (!description || description === voucherMeta.defaultDescription) {
      setDescription(nextMeta.defaultDescription);
    }
    setLines((current) =>
      current.map((line) => ({
        ...line,
        description: nextMeta.defaultDescription,
      })),
    );
  }

  function setLineField(lineIndex: number, field: keyof VoucherLineState, value: string) {
    setLines((current) =>
      current.map((line, index) => (index === lineIndex ? { ...line, [field]: value } : line)),
    );
  }

  function applyDescriptionShortcut(shortcut: "*BD" | "*BD2" | "*BD3") {
    const nextDescription =
      shortcut === "*BD"
        ? `${counterpartyCode} ${counterpartyName} ${documentNumber}`.trim()
        : shortcut === "*BD2"
          ? `${voucherMeta.label} ${entryDate} ${documentReference}`.trim()
          : `${template.context.branch_name} ${projectCode} ${costCenterCode}`.trim();

    setLines((current) => current.map((line) => ({ ...line, description: nextDescription })));
    setMessage(`${shortcut} aciklama makrosu fis satirlarina uygulandi.`);
  }

  function openChartOfAccounts(sourceAction: string) {
    void openModuleWindow({
      moduleSlug,
      templateCode: "chart-of-accounts",
      sourceRoute: `/windows/${moduleSlug}/voucher-new`,
      sourceAction,
    });
  }

  function openVoucherList() {
    void openModuleWindow({
      moduleSlug,
      templateCode: "voucher-list",
      sourceRoute: `/windows/${moduleSlug}/voucher-new`,
      sourceAction: "voucher-shortcut-f7",
    });
  }

  function updateAccountLookup(lineIndex: number, rawValue: string) {
    const normalized = rawValue.toUpperCase();
    setLineField(lineIndex, "accountCode", normalized);
    setAccountLookupLineIndex(lineIndex);
    const matched = accountOptions.filter(
      (item) => item.code.startsWith(normalized) || item.name.toLowerCase().includes(normalized.toLowerCase()),
    );
    setAccountLookupRows((matched.length ? matched : accountOptions).slice(0, 12));

    if (/^\d/.test(normalized) && !lookupPopupLockedRef.current) {
      lookupPopupLockedRef.current = true;
      openChartOfAccounts(`voucher-account-lookup-line-${lineIndex + 1}`);
      window.setTimeout(() => {
        lookupPopupLockedRef.current = false;
      }, 1200);
    }
  }

  function applyAccountLookup(code: string) {
    if (accountLookupLineIndex === null) {
      return;
    }
    const matched = accountOptions.find((item) => item.code === code);
    setLineField(accountLookupLineIndex, "accountCode", code);
    if (matched) {
      setLineField(
        accountLookupLineIndex,
        "description",
        lines[accountLookupLineIndex]?.description || matched.name,
      );
      setMessage(`${matched.code} / ${matched.name} secilen fis satirina uygulandi.`);
    }
  }

  function focusVoucherCell(lineIndex: number, field: keyof VoucherLineState) {
    const nextTarget = document.querySelector<HTMLInputElement>(`[data-voucher-cell="${lineIndex}-${field}"]`);
    nextTarget?.focus();
    nextTarget?.select();
  }

  function handleVoucherCellKeyDown(
    event: ReactKeyboardEvent<HTMLInputElement>,
    lineIndex: number,
    field: keyof VoucherLineState,
  ) {
    if (event.key !== "Enter") {
      return;
    }
    event.preventDefault();
    const currentValue = event.currentTarget.value.trim();
    if (currentValue === "*" && lineIndex > 0) {
      setLines((current) =>
        current.map((line, index) => (index === lineIndex ? { ...current[lineIndex - 1] } : line)),
      );
      setMessage(`* + Enter ile ${lineIndex}. satir ${lineIndex + 1}. satira kopyalandi.`);
      window.setTimeout(() => focusVoucherCell(lineIndex, "accountCode"), 0);
      return;
    }

    const order: Array<keyof VoucherLineState> = ["accountCode", "description", "debit", "credit"];
    const fieldIndex = order.indexOf(field);
    if (fieldIndex < order.length - 1) {
      focusVoucherCell(lineIndex, order[fieldIndex + 1]);
      return;
    }
    if (lineIndex < lines.length - 1) {
      focusVoucherCell(lineIndex + 1, "accountCode");
      return;
    }
    saveButtonRef.current?.focus();
  }

  function handleMetaFieldKeyDown(event: ReactKeyboardEvent<HTMLInputElement | HTMLSelectElement>) {
    if (event.key !== "Enter") {
      return;
    }
    event.preventDefault();
    const targets = Array.from(document.querySelectorAll<HTMLElement>("[data-voucher-nav='true']"));
    const currentIndex = targets.findIndex((item) => item === event.currentTarget);
    if (currentIndex >= 0 && currentIndex < targets.length - 1) {
      targets[currentIndex + 1].focus();
      return;
    }
    focusVoucherCell(0, "accountCode");
  }

  async function createVoucherAndWindows() {
    if (Math.abs(debitTotal - creditTotal) > 0.005) {
      setMessage("Borc ve alacak toplami esit olmadan fis kaydi tamamlanamaz.");
      return;
    }

    popupSequenceRef.current += 1;
    const popupKey = popupSequenceRef.current;
    const detailPopup = openDeferredPopup(`voucher-detail-${popupKey}`);
    const listPopup = openDeferredPopup(`voucher-list-${popupKey}`);
    const ledgerPopup = openDeferredPopup(`voucher-ledger-${popupKey}`);

    const response = await fetch(`${API_BASE_URL}/api/erp/finance/vouchers`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-actor": "web-operator" },
      body: JSON.stringify({
        voucher_type: voucherType,
        entry_number: entryNumber,
        document_number: documentNumber,
        entry_date: entryDate,
        document_date: documentDate,
        due_date: dueDate,
        document_type_code: documentTypeCode,
        description,
        status: "draft",
        company_id: template.context.company_id,
        branch_id: template.context.branch_id,
        ledger_id: template.context.ledger_id,
        fiscal_year: template.context.fiscal_year,
        fiscal_period: template.context.fiscal_period,
        counterparty_code: counterpartyCode,
        counterparty_name: counterpartyName,
        currency: currency,
        exchange_rate: Number(exchangeRate),
        cost_center_code: costCenterCode,
        profit_center_code: profitCenterCode,
        project_code: projectCode,
        department_code: departmentCode,
        warehouse_code: warehouseCode,
        tax_code: taxCode,
        vat_rate: Number(vatRate),
        withholding_rate: Number(withholdingRate),
        e_document_profile: eDocumentProfile,
        integrator_profile: integratorProfile,
        approval_state: "taslak",
        document_reference: documentReference,
        payment_reference: paymentReference,
        note_text: null,
        source_type: "manual_window",
        lines: lines.map((line) => {
          const account = accountOptions.find((item) => item.code === line.accountCode);
          return {
            account_code: line.accountCode,
            account_name: account?.name ?? line.accountCode,
            description: line.description,
            debit: Number(line.debit) || 0,
            credit: Number(line.credit) || 0,
            currency,
          };
        }),
        auto_post: true,
      }),
    });

    if (!response.ok) {
      detailPopup.close();
      listPopup.close();
      ledgerPopup.close();
      const errorPayload = (await response.json().catch(() => null)) as { detail?: string } | null;
      setMessage(errorPayload?.detail ?? "Fis kaydi olusturulamadi");
      return;
    }

    const voucher = (await response.json()) as VoucherDetail;

    const [detailSession, listSession, ledgerSession] = await Promise.all([
      createWindowSession({
        moduleSlug: "finance-gl",
        templateCode: "voucher-detail",
        recordId: voucher.id,
        sourceRoute: "/modules/finance-gl",
        sourceAction: "yeni-fis-kaydet",
      }),
      createWindowSession({
        moduleSlug: "finance-gl",
        templateCode: "voucher-list",
        sourceRoute: "/modules/finance-gl",
        sourceAction: "yeni-fis-kaydet",
      }),
      createWindowSession({
        moduleSlug: "finance-gl",
        templateCode: "ledger",
        sourceRoute: "/modules/finance-gl",
        sourceAction: "yeni-fis-kaydet",
      }),
    ]);

    if (detailSession) {
      detailPopup.navigate(`${detailSession.route}&recordId=${voucher.id}`);
    } else {
      detailPopup.close();
    }
    if (listSession) {
      listPopup.navigate(listSession.route);
    } else {
      listPopup.close();
    }
    if (ledgerSession) {
      ledgerPopup.navigate(ledgerSession.route);
    } else {
      ledgerPopup.close();
    }

    setMessage(`${voucher.entry_number} kaydedildi ve ilgili pencereler acildi`);
  }

  const handleVoucherShortcut = useEffectEvent((event: KeyboardEvent) => {
    if (event.key === "F2") {
      event.preventDefault();
      void createVoucherAndWindows();
      return;
    }
    if (event.key === "F6") {
      event.preventDefault();
      openChartOfAccounts("voucher-shortcut-f6");
      return;
    }
    if (event.key === "F7" && !event.ctrlKey && !event.shiftKey) {
      event.preventDefault();
      openVoucherList();
      return;
    }
    if (event.key === "F8") {
      event.preventDefault();
      setMessage("F8 saha duzeni icin satir, baglam ve boyut alanlari ayni pencerede tutuluyor.");
      return;
    }
    if (event.key === "F1" && event.shiftKey) {
      event.preventDefault();
      setMessage("Shift+F1 yardim: F2 kaydet, F6 hesap plani, F7 fis listesi, Ctrl+7 sablon, Shift+Ctrl+F7 sablon fis, * + Enter ust satiri kopyalar.");
      return;
    }
    if (event.key === "7" && event.ctrlKey && event.shiftKey) {
      event.preventDefault();
      setMessage("Shift+Ctrl+F7 sablon fis olusturma davranisi profesyonel fis alan seti icin ayrildi.");
      return;
    }
    if (event.key === "7" && event.ctrlKey) {
      event.preventDefault();
      selectVoucherType(template.voucher_types[0] ?? "mahsup");
      setMessage("Ctrl+7 varsayilan sablon fis alanlarini geri yukledi.");
      return;
    }
    if (event.key === "1" && event.ctrlKey) {
      event.preventDefault();
      setMessage("Ctrl+1 hesap makinesi aktarim kancasini temsil eder; tutar alanlari korunuyor.");
    }
  });

  useEffect(() => {
    function handleShortcut(event: KeyboardEvent) {
      handleVoucherShortcut(event);
    }

    window.addEventListener("keydown", handleShortcut);
    return () => window.removeEventListener("keydown", handleShortcut);
  }, []);

  return (
    <div className={styles.desktopSurface}>
      <FinanceContextBar
        templateCode="voucher-new"
        title="Yeni Fis Girisi"
        subtitle="Tek Duzen hesap plani, VUK kurallari ve pencere bazli muhasebe akisi"
      />
      <SourceBand />
      <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="voucher-new" sourceAction="voucher-new" />

      <section className={styles.gridTwo}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Fis Baslik ve Satir Bilgileri</div>
          <div className={styles.panelBody}>
            <div className={styles.voucherTypeBar}>
              {template.voucher_types.map((type) => {
                const typeMeta = VOUCHER_TYPE_META[type] ?? { label: type, documentCode: type.toUpperCase(), defaultDescription: type };
                const active = type === voucherType;
                return (
                  <button
                    key={type}
                    type="button"
                    className={active ? `${styles.voucherTypeButton} ${styles.voucherTypeButtonActive}` : styles.voucherTypeButton}
                    onClick={() => selectVoucherType(type)}
                  >
                    {typeMeta.label}
                  </button>
                );
              })}
            </div>
            <div className={styles.etaVoucherBoard}>
              <div className={styles.etaVoucherHeader}>
                <div>
                  <div className={styles.etaVoucherTitle}>ETA benzeri fis giris tablasi</div>
                  <div className={styles.etaVoucherSubTitle}>Tek duzen, seri, baglam ve satir dengesi ayni pencerede izlenir.</div>
                </div>
                <div className={styles.statusGroup}>
                  <span className={styles.statusBadge}>{voucherMeta.label}</span>
                  <span className={styles.statusBadge}>{documentTypeCode}</span>
                  <span className={styles.statusBadge}>{template.context.ledger_name}</span>
                  <span className={styles.statusBadge}>F2 Kaydet</span>
                  <span className={styles.statusBadge}>F6 Hesap Plani</span>
                  <span className={styles.statusBadge}>F7 Fis Listesi</span>
                </div>
              </div>
              <div className={styles.etaVoucherMetaGrid}>
                <div><span>Seri</span><strong>{template.default_series}</strong></div>
                <div><span>Fis No</span><strong>{entryNumber}</strong></div>
                <div><span>Belge No</span><strong>{documentNumber}</strong></div>
                <div><span>Donem</span><strong>{template.context.fiscal_year} / {template.context.fiscal_period}</strong></div>
                <div><span>Tarih</span><strong>{entryDate}</strong></div>
                <div><span>Vade</span><strong>{dueDate}</strong></div>
                <div><span>Cari</span><strong>{counterpartyCode || "-"}</strong></div>
                <div><span>Denge</span><strong>{money(debitTotal, currency)} / {money(creditTotal, currency)}</strong></div>
              </div>
              <table className={styles.table}>
                <thead>
                  <tr>
                    <th>Satir</th>
                    <th>Hesap Kodu</th>
                    <th>Aciklama</th>
                    <th>Borc</th>
                    <th>Alacak</th>
                    <th>Hesap Adi</th>
                  </tr>
                </thead>
                <tbody>
                  {lines.map((line, index) => {
                    const matchedAccount = accountOptions.find((item) => item.code === line.accountCode);
                    return (
                      <tr key={`voucher-line-${index}`}>
                        <td>{index + 1}</td>
                        <td>
                          <input
                            className={styles.tableInput}
                            data-voucher-cell={`${index}-accountCode`}
                            value={line.accountCode}
                            list="finance-account-options"
                            onChange={(event) => updateAccountLookup(index, event.target.value)}
                            onKeyDown={(event) => handleVoucherCellKeyDown(event, index, "accountCode")}
                          />
                        </td>
                        <td>
                          <input
                            className={styles.tableInput}
                            data-voucher-cell={`${index}-description`}
                            value={line.description}
                            onChange={(event) => setLineField(index, "description", event.target.value)}
                            onKeyDown={(event) => handleVoucherCellKeyDown(event, index, "description")}
                          />
                        </td>
                        <td>
                          <input
                            className={styles.tableInput}
                            data-voucher-cell={`${index}-debit`}
                            value={line.debit}
                            onChange={(event) => setLineField(index, "debit", event.target.value)}
                            onKeyDown={(event) => handleVoucherCellKeyDown(event, index, "debit")}
                          />
                        </td>
                        <td>
                          <input
                            className={styles.tableInput}
                            data-voucher-cell={`${index}-credit`}
                            value={line.credit}
                            onChange={(event) => setLineField(index, "credit", event.target.value)}
                            onKeyDown={(event) => handleVoucherCellKeyDown(event, index, "credit")}
                          />
                        </td>
                        <td>{matchedAccount?.name ?? "-"}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
              <datalist id="finance-account-options">
                {accountOptions.map((item) => (
                  <option key={item.code} value={item.code}>
                    {item.name}
                  </option>
                ))}
              </datalist>
              <div className={styles.actionRow}>
                <button type="button" className={styles.actionButton} onClick={() => openChartOfAccounts("voucher-toolbar-f6")}>
                  F6 Hesap Plani
                </button>
                <button type="button" className={styles.actionButton} onClick={() => openVoucherList()}>
                  F7 Fis Listesi
                </button>
                <button type="button" className={styles.secondaryActionButton} onClick={() => applyDescriptionShortcut("*BD")}>
                  *BD
                </button>
                <button type="button" className={styles.secondaryActionButton} onClick={() => applyDescriptionShortcut("*BD2")}>
                  *BD2
                </button>
                <button type="button" className={styles.secondaryActionButton} onClick={() => applyDescriptionShortcut("*BD3")}>
                  *BD3
                </button>
              </div>
              <table className={styles.table}>
                <thead>
                  <tr>
                    <th>Kisayol</th>
                    <th>Davranis</th>
                    <th>Durum</th>
                  </tr>
                </thead>
                <tbody>
                  <tr><td>F2</td><td>Fis kaydet ve ilgili pencereleri ac</td><td>aktif</td></tr>
                  <tr><td>F6</td><td>Hesap planini ac</td><td>aktif</td></tr>
                  <tr><td>F7</td><td>Fis listesini ac</td><td>aktif</td></tr>
                  <tr><td>F8</td><td>Saha ve pozisyon davranisini bilgi olarak goster</td><td>aktif</td></tr>
                  <tr><td>Ctrl+7</td><td>Varsayilan sablon fis tipine don</td><td>aktif</td></tr>
                  <tr><td>Shift+Ctrl+F7</td><td>Sablon fis davranisi</td><td>aktif</td></tr>
                  <tr><td>Ctrl+1</td><td>Hesap makinesi aktarim kancasi</td><td>aktif</td></tr>
                  <tr><td>* + Enter</td><td>Ust satiri mevcut satira kopyala</td><td>aktif</td></tr>
                  <tr><td>Enter</td><td>Bir sonraki hucreye ilerle</td><td>aktif</td></tr>
                </tbody>
              </table>
              {accountLookupRows.length ? (
                <table className={styles.table}>
                  <thead>
                    <tr>
                      <th>Satir</th>
                      <th>Hesap Kodu</th>
                      <th>Hesap Adi</th>
                      <th>Aksiyon</th>
                    </tr>
                  </thead>
                  <tbody>
                    {accountLookupRows.map((item) => (
                      <tr key={`lookup-${item.code}`}>
                        <td>{accountLookupLineIndex !== null ? accountLookupLineIndex + 1 : "-"}</td>
                        <td>{item.code}</td>
                        <td>{item.name}</td>
                        <td>
                          <button type="button" className={styles.secondaryActionButton} onClick={() => applyAccountLookup(item.code)}>
                            Hesabi Yaz
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : null}
            </div>
            <div className={styles.fieldGrid}>
              <label className={styles.field}>
                <span>Fis No</span>
                <input data-voucher-nav="true" value={entryNumber} onChange={(event) => setEntryNumber(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Belge No</span>
                <input data-voucher-nav="true" value={documentNumber} onChange={(event) => setDocumentNumber(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Fis Tarihi</span>
                <input data-voucher-nav="true" type="date" value={entryDate} onChange={(event) => setEntryDate(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Belge Tarihi</span>
                <input data-voucher-nav="true" type="date" value={documentDate} onChange={(event) => setDocumentDate(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Vade Tarihi</span>
                <input data-voucher-nav="true" type="date" value={dueDate} onChange={(event) => setDueDate(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Belge Tip Kodu</span>
                <select data-voucher-nav="true" value={documentTypeCode} onChange={(event) => setDocumentTypeCode(event.target.value)} onKeyDown={handleMetaFieldKeyDown}>
                  {template.voucher_types.map((type) => {
                    const typeMeta = VOUCHER_TYPE_META[type] ?? { label: type, documentCode: type.toUpperCase(), defaultDescription: type };
                    return (
                      <option key={typeMeta.documentCode} value={typeMeta.documentCode}>
                        {typeMeta.documentCode}
                      </option>
                    );
                  })}
                </select>
              </label>
              <label className={styles.field}>
                <span>Fis Turu</span>
                <select data-voucher-nav="true" value={voucherType} onChange={(event) => selectVoucherType(event.target.value)} onKeyDown={handleMetaFieldKeyDown}>
                  {template.voucher_types.map((type) => (
                    <option key={type} value={type}>
                      {(VOUCHER_TYPE_META[type] ?? { label: type }).label}
                    </option>
                  ))}
                </select>
              </label>
              <label className={styles.field}>
                <span>Para Birimi</span>
                <input data-voucher-nav="true" value={currency} onChange={(event) => setCurrency(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Kur</span>
                <input data-voucher-nav="true" value={exchangeRate} onChange={(event) => setExchangeRate(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Cari Kod</span>
                <input data-voucher-nav="true" value={counterpartyCode} onChange={(event) => setCounterpartyCode(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Cari Unvan</span>
                <input data-voucher-nav="true" value={counterpartyName} onChange={(event) => setCounterpartyName(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Masraf Merkezi</span>
                <input data-voucher-nav="true" value={costCenterCode} onChange={(event) => setCostCenterCode(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Kar Merkezi</span>
                <input data-voucher-nav="true" value={profitCenterCode} onChange={(event) => setProfitCenterCode(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Proje Kodu</span>
                <input data-voucher-nav="true" value={projectCode} onChange={(event) => setProjectCode(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Departman</span>
                <input data-voucher-nav="true" value={departmentCode} onChange={(event) => setDepartmentCode(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Depo</span>
                <input data-voucher-nav="true" value={warehouseCode} onChange={(event) => setWarehouseCode(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Vergi Kodu</span>
                <input data-voucher-nav="true" value={taxCode} onChange={(event) => setTaxCode(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>KDV %</span>
                <input data-voucher-nav="true" value={vatRate} onChange={(event) => setVatRate(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.field}>
                <span>Stopaj %</span>
                <input data-voucher-nav="true" value={withholdingRate} onChange={(event) => setWithholdingRate(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.fieldWide}>
                <span>e-Belge Profili</span>
                <input data-voucher-nav="true" value={eDocumentProfile} onChange={(event) => setEDocumentProfile(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.fieldWide}>
                <span>Entegrator Profili</span>
                <select data-voucher-nav="true" value={integratorProfile} onChange={(event) => setIntegratorProfile(event.target.value)} onKeyDown={handleMetaFieldKeyDown}>
                  {template.integration_profiles.map((item) => (
                    <option key={item} value={item}>
                      {item}
                    </option>
                  ))}
                </select>
              </label>
              <label className={styles.fieldWide}>
                <span>Belge Referansi</span>
                <input data-voucher-nav="true" value={documentReference} onChange={(event) => setDocumentReference(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.fieldWide}>
                <span>Odeme Referansi</span>
                <input data-voucher-nav="true" value={paymentReference} onChange={(event) => setPaymentReference(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
              <label className={styles.fieldFull}>
                <span>Aciklama</span>
                <input data-voucher-nav="true" value={description} onChange={(event) => setDescription(event.target.value)} onKeyDown={handleMetaFieldKeyDown} />
              </label>
            </div>
            <div className={styles.actionRow}>
              <button ref={saveButtonRef} type="button" className={styles.actionButton} onClick={() => void createVoucherAndWindows()}>
                Kaydet, Muhasebelestir ve Ilgili Pencereleri Ac
              </button>
              <span className={styles.statusBadge}>{voucherMeta.label}</span>
              <span className={styles.statusBadge}>F2 kaydet</span>
              <span className={styles.statusBadge}>* + Enter ust satiri kopyalar.</span>
            </div>
            <div className={styles.subsectionTitle}>Fis Satir Onizleme</div>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Satir</th>
                  <th>Hesap</th>
                  <th>Aciklama</th>
                  <th>Borc</th>
                  <th>Alacak</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>1</td>
                  <td>{lines[0]?.accountCode} / {accountOptions.find((item) => item.code === lines[0]?.accountCode)?.name ?? "-"}</td>
                  <td>{lines[0]?.description ?? "-"}</td>
                  <td>{money(Number(lines[0]?.debit || 0), currency)}</td>
                  <td>{money(0, currency)}</td>
                </tr>
                <tr>
                  <td>2</td>
                  <td>{lines[1]?.accountCode} / {accountOptions.find((item) => item.code === lines[1]?.accountCode)?.name ?? "-"}</td>
                  <td>{lines[1]?.description ?? "-"}</td>
                  <td>{money(0, currency)}</td>
                  <td>{money(Number(lines[1]?.credit || 0), currency)}</td>
                </tr>
              </tbody>
            </table>
            {message ? <div className={styles.messageBar}>{message}</div> : null}
          </div>
        </section>

        <section className={styles.panel}>
          <div className={styles.panelHeader}>Baglam, Standart ve Kontroller</div>
          <div className={styles.panelBody}>
            <ContextTable
              rows={[
                { label: "Sirket", value: template.context.company_name },
                { label: "Sube", value: template.context.branch_name },
                { label: "Defter", value: template.context.ledger_name },
                { label: "Donem", value: `${template.context.fiscal_year} / ${template.context.fiscal_period}` },
                { label: "Donem Durumu", value: template.fiscal_period.status },
                { label: "Belge Serisi", value: template.default_series },
                { label: "Fis Profili", value: template.journal_profile },
                { label: "Varsayilan Belge Tipi", value: documentTypeCode },
                { label: "Muhasebe Esasi", value: template.context.accounting_basis },
                { label: "Raporlama Esasi", value: template.context.reporting_basis },
                { label: "Varsayilan Belge No", value: template.next_document_number },
              ]}
            />
            <div className={styles.subsectionTitle}>Kabul Kurallari</div>
            <RuleList items={[...getFinanceUiRules(uiContract, "voucher-new", VOUCHER_RULES), ...template.validation_rules]} />
            <div className={styles.subsectionTitle}>Giris Bolumleri</div>
            <RuleList items={template.entry_sections} />
            <div className={styles.subsectionTitle}>Parametre Seti</div>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Kod</th>
                  <th>Baslik</th>
                  <th>Deger</th>
                </tr>
              </thead>
              <tbody>
                {template.parameter_items.slice(0, 8).map((item) => (
                  <tr key={item.parameter_code}>
                    <td>{item.parameter_code}</td>
                    <td>{item.title}</td>
                    <td>{item.value_text}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div className={styles.subsectionTitle}>Rapor Hedefleri</div>
            <RuleList items={template.report_windows.map((item) => `${item} penceresi`)} />
            <div className={styles.subsectionTitle}>SQL Benzeri Saklama Katmani</div>
            <RuleList items={template.storage_tables.map((item) => `${item} tablosu`)} />
            <div className={styles.subsectionTitle}>Posting Zinciri</div>
            <RuleList items={template.posting_chain} />
            <div className={styles.subsectionTitle}>Kaynak Aileleri</div>
            <RuleList items={template.source_families} />
          </div>
        </section>
      </section>
    </div>
  );
}

export function VoucherDetailWindow({
  detail,
  moduleSlug = "finance-gl",
}: {
  detail: VoucherDetail;
  moduleSlug?: string;
}) {
    return (
      <div className={styles.desktopSurface}>
        <FinanceContextBar
          templateCode="voucher-detail"
          title={`Fis Detayi / ${detail.entry_number}`}
          subtitle="Kaydedilen belgenin satir, bakiye ve baglam kontrol penceresi"
        />
        <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="voucher-detail" sourceAction="voucher-detail" />
      <section className={styles.metrics}>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Fis Turu</div>
          <div className={styles.metricValueSmall}>{detail.voucher_type}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Durum</div>
          <div className={styles.metricValueSmall}>{detail.status}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Toplam Borc</div>
          <div className={styles.metricValueSmall}>{money(detail.total_debit)}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Toplam Alacak</div>
          <div className={styles.metricValueSmall}>{money(detail.total_credit)}</div>
        </article>
      </section>
      <section className={styles.gridTwo}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Fis Basligi</div>
          <div className={styles.panelBody}>
            <ContextTable
              rows={[
                { label: "Fis No", value: detail.entry_number },
                { label: "Belge No", value: detail.document_number },
                { label: "Tarih", value: dateLabel(detail.entry_date) },
                { label: "Belge Tarihi", value: dateLabel(detail.document_date) },
                { label: "Vade", value: detail.due_date ? dateLabel(detail.due_date) : "-" },
                { label: "Belge Tipi", value: detail.document_type_code ?? "-" },
                { label: "Tur", value: detail.voucher_type },
                { label: "Durum", value: detail.status },
                { label: "Sirket", value: detail.context.company_name },
                { label: "Defter", value: detail.context.ledger_name },
                { label: "Belge Serisi", value: detail.voucher_profile.document_series },
                { label: "Sira", value: `${detail.voucher_profile.document_sequence}` },
                { label: "Fis Profili", value: detail.voucher_profile.journal_profile },
                { label: "Workflow", value: detail.voucher_profile.workflow_state },
                { label: "Cari", value: `${detail.counterparty_code ?? "-"} / ${detail.counterparty_name ?? "-"}` },
                { label: "Masraf Merkezi", value: detail.cost_center_code ?? "-" },
                { label: "Kar Merkezi", value: detail.profit_center_code ?? "-" },
                { label: "Proje", value: detail.project_code ?? "-" },
                { label: "Departman", value: detail.department_code ?? "-" },
                { label: "Depo", value: detail.warehouse_code ?? "-" },
                { label: "Vergi", value: detail.tax_code ?? "-" },
                { label: "KDV / Stopaj", value: `${detail.vat_rate ?? 0}% / ${detail.withholding_rate ?? 0}%` },
                { label: "Odeme Ref", value: detail.payment_reference ?? "-" },
              ]}
            />
          </div>
        </section>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Pencere Durumu</div>
          <div className={styles.panelBody}>
            <RuleList
              items={[
                "Kayit sonrasi detay penceresi gercek belge kimligi ile acildi.",
                "Muhasebe etkisi buyuk defter ve muavin pencerelerine tasinabilir.",
                detail.balanced ? "Borc ve alacak dengesi dogrulandi." : "Borc ve alacak dengesi bozuk.",
                ...detail.validation_rules,
              ]}
            />
          </div>
        </section>
      </section>
      <section className={styles.gridTwo}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>SQL Benzeri Saklama Profili</div>
          <div className={styles.panelBody}>
            <ContextTable
              rows={[
                { label: "Motor", value: detail.voucher_profile.storage_engine },
                { label: "Header", value: detail.voucher_profile.header_store },
                { label: "Satir", value: detail.voucher_profile.line_store },
                { label: "Baglam", value: detail.voucher_profile.context_store },
                { label: "Audit", value: detail.voucher_profile.audit_store },
              ]}
            />
            <div className={styles.subsectionTitle}>Giris Bolumleri</div>
            <RuleList items={detail.entry_sections} />
          </div>
        </section>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Rapor ve Posting Zinciri</div>
          <div className={styles.panelBody}>
            <div className={styles.subsectionTitle}>Rapor Pencereleri</div>
            <RuleList items={detail.report_windows.map((item) => `${item} penceresi`)} />
            <div className={styles.subsectionTitle}>Saklama Tablolari</div>
            <RuleList items={detail.storage_tables.map((item) => `${item} tablosu`)} />
            <div className={styles.subsectionTitle}>Posting Zinciri</div>
            <RuleList items={detail.posting_chain} />
          </div>
        </section>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Fis Satirlari</div>
        <div className={styles.panelBody}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Hesap</th>
                <th>Aciklama</th>
                <th>Borc</th>
                <th>Alacak</th>
              </tr>
            </thead>
            <tbody>
              {detail.lines.map((line) => (
                <tr key={line.id}>
                  <td>{line.account_code} / {line.account_name}</td>
                  <td>{line.description ?? "-"}</td>
                  <td>{money(line.debit)}</td>
                  <td>{money(line.credit)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

export function VoucherListWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: FinanceWorkspace;
  moduleSlug?: string;
}) {
  const [entries, setEntries] = useState(workspace.journal_entries);
  const [statusFilter, setStatusFilter] = useState("all");
  const [voucherTypeFilter, setVoucherTypeFilter] = useState("all");
  const [startDate, setStartDate] = useState(entries.length ? entries[entries.length - 1].entry_date : "");
  const [endDate, setEndDate] = useState(entries.length ? entries[0].entry_date : "");
  const [message, setMessage] = useState("");

  const filteredEntries = entries.filter((entry) => {
    const voucherType = entry.voucher_profile?.voucher_type ?? "mahsup";
    if (statusFilter !== "all" && entry.status !== statusFilter) {
      return false;
    }
    if (voucherTypeFilter !== "all" && voucherType !== voucherTypeFilter) {
      return false;
    }
    if (startDate && entry.entry_date < startDate) {
      return false;
    }
    if (endDate && entry.entry_date > endDate) {
      return false;
    }
    return true;
  });

  async function openVoucherDetail(voucherId: string) {
    await openModuleWindow({
      moduleSlug,
      templateCode: "voucher-detail",
      recordId: voucherId,
      sourceRoute: `/windows/${moduleSlug}/voucher-list`,
      sourceAction: "voucher-list-detail",
    });
  }

  async function postVoucher(voucherId: string) {
    const result = await postFinanceVoucher(voucherId);
    if (!result) {
      setMessage("Fis post edilemedi.");
      return;
    }
    setEntries((current) =>
      current.map((entry) =>
        entry.id === voucherId ? { ...entry, status: result.status, voucher_profile: result.voucher_profile } : entry,
      ),
    );
    setMessage(`${result.entry_number} post edildi.`);
    await openVoucherDetail(result.id);
  }

  async function reverseVoucher(voucherId: string) {
    const result = await reverseFinanceVoucher(voucherId);
    if (!result) {
      setMessage("Ters kayit olusturulamadi.");
      return;
    }
    setMessage(`${result.entry_number} ters kayit olarak olusturuldu.`);
    await openVoucherDetail(result.id);
    window.location.reload();
  }

  return (
    <div className={styles.desktopSurface}>
      <FinanceContextBar
        templateCode="voucher-list"
        title="Fis Listesi"
        subtitle="Taslak, post ve ters kayit akislarini yoneten gercek fis operasyon penceresi"
      />
      <SourceBand />
      <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="voucher-list" sourceAction="voucher-list" />
      <section className={styles.metrics}>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Toplam Fis</div>
          <div className={styles.metricValue}>{entries.length}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Taslak</div>
          <div className={styles.metricValue}>{entries.filter((item) => item.status !== "posted").length}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Post Edilmis</div>
          <div className={styles.metricValue}>{entries.filter((item) => item.status === "posted").length}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Filtre Sonucu</div>
          <div className={styles.metricValue}>{filteredEntries.length}</div>
        </article>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Fis Listeleme Filtreleri</div>
        <div className={styles.panelBody}>
          <div className={styles.fieldGridCompact}>
            <label className={styles.field}>
              <span>Durum</span>
              <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}>
                <option value="all">tum durumlar</option>
                <option value="draft">taslak</option>
                <option value="posted">posted</option>
              </select>
            </label>
            <label className={styles.field}>
              <span>Fis Turu</span>
              <select value={voucherTypeFilter} onChange={(event) => setVoucherTypeFilter(event.target.value)}>
                <option value="all">tum turler</option>
                {Object.entries(VOUCHER_TYPE_META).map(([value, meta]) => (
                  <option key={value} value={value}>
                    {meta.label}
                  </option>
                ))}
              </select>
            </label>
            <label className={styles.field}>
              <span>Baslangic Tarihi</span>
              <input type="date" value={startDate} onChange={(event) => setStartDate(event.target.value)} />
            </label>
            <label className={styles.field}>
              <span>Bitis Tarihi</span>
              <input type="date" value={endDate} onChange={(event) => setEndDate(event.target.value)} />
            </label>
            <div className={styles.fieldActionCell}>
              <button
                type="button"
                className={styles.secondaryActionButton}
                onClick={() => {
                  setStatusFilter("all");
                  setVoucherTypeFilter("all");
                  setStartDate(entries.length ? entries[entries.length - 1].entry_date : "");
                  setEndDate(entries.length ? entries[0].entry_date : "");
                }}
              >
                Filtreleri Temizle
              </button>
            </div>
          </div>
          {message ? <div className={styles.messageBar}>{message}</div> : null}
        </div>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Fis Operasyon Satirlari</div>
        <div className={styles.panelBody}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Fis No</th>
                <th>Tur</th>
                <th>Tarih</th>
                <th>Durum</th>
                <th>Satir</th>
                <th>Borc</th>
                <th>Alacak</th>
                <th>Aksiyon</th>
              </tr>
            </thead>
            <tbody>
              {filteredEntries.map((entry) => {
                const voucherType = entry.voucher_profile?.voucher_type ?? "mahsup";
                const voucherLabel = (VOUCHER_TYPE_META[voucherType] ?? { label: voucherType }).label;
                const totalDebit = entry.lines.reduce((sum, line) => sum + line.debit, 0);
                const totalCredit = entry.lines.reduce((sum, line) => sum + line.credit, 0);
                return (
                  <tr key={entry.id}>
                    <td>{entry.entry_number}</td>
                    <td>{voucherLabel}</td>
                    <td>{dateLabel(entry.entry_date)}</td>
                    <td>{entry.status}</td>
                    <td>{entry.lines.length}</td>
                    <td>{money(totalDebit)}</td>
                    <td>{money(totalCredit)}</td>
                    <td>
                      <div className={styles.actionRow}>
                        <button type="button" className={styles.actionButton} onClick={() => void openVoucherDetail(entry.id)}>
                          Detay Ac
                        </button>
                        {entry.status !== "posted" ? (
                          <button type="button" className={styles.secondaryActionButton} onClick={() => void postVoucher(entry.id)}>
                            Post Et
                          </button>
                        ) : (
                          <button type="button" className={styles.secondaryActionButton} onClick={() => void reverseVoucher(entry.id)}>
                            Ters Kayit
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

export function ChartOfAccountsWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: ChartOfAccountsWorkspace;
  moduleSlug?: string;
}) {
  const [code, setCode] = useState("120.02");
  const [name, setName] = useState("Yeni Cari Alici Alt Hesabi");
  const [accountClass, setAccountClass] = useState("donen_varlik");
  const [accountType, setAccountType] = useState("asset");
  const [balanceSide, setBalanceSide] = useState("borc");
  const [level, setLevel] = useState("2");
  const [parentCode, setParentCode] = useState("120");
  const [reportTag, setReportTag] = useState("ticari_alacaklar");
  const [taxCategory, setTaxCategory] = useState("ticari_alacak");
  const [reconciliationGroup, setReconciliationGroup] = useState("customer");
  const [openingBalance, setOpeningBalance] = useState("0");
  const [requiresCounterparty, setRequiresCounterparty] = useState(true);
  const [requiresCostCenter, setRequiresCostCenter] = useState(false);
  const [requiresProject, setRequiresProject] = useState(false);
  const [message, setMessage] = useState("");
  const totalBalance = workspace.items.reduce((sum, item) => sum + item.current_balance, 0);
  const leafCount = workspace.items.filter((item) => item.level >= 2).length;
  const customerLinkedCount = workspace.items.filter((item) => item.requires_counterparty).length;

  async function createAccountCard() {
    const result = await createChartAccountCard({
      code,
      name,
      account_class: accountClass,
      account_type: accountType,
      balance_side: balanceSide,
      level: Number(level),
      parent_code: parentCode || null,
      company_id: workspace.context.company_id,
      branch_scope: workspace.context.branch_id,
      currency: "TRY",
      report_tag: reportTag,
      tax_category: taxCategory || null,
      reconciliation_group: reconciliationGroup || null,
      e_document_profile: "gib-e-belge",
      allow_manual_entries: true,
      allow_auto_posting: true,
      allow_debit: balanceSide === "borc",
      allow_credit: balanceSide === "alacak" ? true : accountType !== "asset",
      requires_counterparty: requiresCounterparty,
      requires_cost_center: requiresCostCenter,
      requires_project: requiresProject,
      opening_balance: Number(openingBalance),
      source_family: "eta-logo-mikro-oracle",
      status: "active",
    });

    if (!result) {
      setMessage("Hesap karti kaydi olusturulamadi. Kod benzersiz ve ust hesap tanimli olmali.");
      return;
    }
    setMessage(`Hesap karti olustu: ${result.code} / ${result.name}`);
    window.location.reload();
  }

  return (
    <div className={styles.desktopSurface}>
      <FinanceContextBar
        templateCode="chart-of-accounts"
        title="Hesap Plani"
        subtitle="Tek Duzen hesap kodlari, bakiye ve hesap turu listesi"
      />
      <SourceBand />
      <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="chart-of-accounts" sourceAction="chart-of-accounts" />
      <section className={styles.metrics}>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Aktif Hesap</div>
          <div className={styles.metricValue}>{workspace.items.length}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Alt Hesap</div>
          <div className={styles.metricValue}>{leafCount}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Toplam Bakiye</div>
          <div className={styles.metricValueSmall}>{money(totalBalance)}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Cari Baglantili</div>
          <div className={styles.metricValue}>{customerLinkedCount}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Defter</div>
          <div className={styles.metricValueSmall}>{workspace.context.ledger_name}</div>
        </article>
      </section>
      <section className={styles.gridTwo}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Yeni Hesap Karti Girisi</div>
          <div className={styles.panelBody}>
            <div className={styles.fieldGrid}>
              <label className={styles.field}>
                <span>Hesap Kod</span>
                <input value={code} onChange={(event) => setCode(event.target.value)} />
              </label>
              <label className={styles.fieldWide}>
                <span>Hesap Adi</span>
                <input value={name} onChange={(event) => setName(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Sinif</span>
                <input value={accountClass} onChange={(event) => setAccountClass(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Tur</span>
                <select value={accountType} onChange={(event) => setAccountType(event.target.value)}>
                  {["asset", "liability", "equity", "revenue", "cost", "expense", "ledger"].map((item) => (
                    <option key={item} value={item}>
                      {item}
                    </option>
                  ))}
                </select>
              </label>
              <label className={styles.field}>
                <span>Bakiye Tarafi</span>
                <select value={balanceSide} onChange={(event) => setBalanceSide(event.target.value)}>
                  <option value="borc">borc</option>
                  <option value="alacak">alacak</option>
                </select>
              </label>
              <label className={styles.field}>
                <span>Seviye</span>
                <input value={level} onChange={(event) => setLevel(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Ust Hesap</span>
                <input value={parentCode} onChange={(event) => setParentCode(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Rapor Etiketi</span>
                <input value={reportTag} onChange={(event) => setReportTag(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Vergi Kategorisi</span>
                <input value={taxCategory} onChange={(event) => setTaxCategory(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Mutabakat Grubu</span>
                <input value={reconciliationGroup} onChange={(event) => setReconciliationGroup(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Acilis Bakiyesi</span>
                <input value={openingBalance} onChange={(event) => setOpeningBalance(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Cari Zorunlu</span>
                <select value={requiresCounterparty ? "evet" : "hayir"} onChange={(event) => setRequiresCounterparty(event.target.value === "evet")}>
                  <option value="evet">evet</option>
                  <option value="hayir">hayir</option>
                </select>
              </label>
              <label className={styles.field}>
                <span>Masraf Merkezi</span>
                <select value={requiresCostCenter ? "evet" : "hayir"} onChange={(event) => setRequiresCostCenter(event.target.value === "evet")}>
                  <option value="hayir">hayir</option>
                  <option value="evet">evet</option>
                </select>
              </label>
              <label className={styles.field}>
                <span>Proje</span>
                <select value={requiresProject ? "evet" : "hayir"} onChange={(event) => setRequiresProject(event.target.value === "evet")}>
                  <option value="hayir">hayir</option>
                  <option value="evet">evet</option>
                </select>
              </label>
            </div>
            <div className={styles.actionRow}>
              <button type="button" className={styles.actionButton} onClick={() => void createAccountCard()}>
                Hesap Karti Olustur
              </button>
              <span className={styles.statusBadge}>Olusan hesap karti fiş ve rapor pencerelerinde hemen kullanilir.</span>
            </div>
            {message ? <div className={styles.messageBar}>{message}</div> : null}
          </div>
        </section>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Kart Kurallari ve Hiyerarsi</div>
          <div className={styles.panelBody}>
            <ContextTable
              rows={[
                { label: "Sirket", value: workspace.context.company_name },
                { label: "Sube", value: workspace.context.branch_name },
                { label: "Defter", value: workspace.context.ledger_name },
                { label: "Muhasebe Esasi", value: workspace.context.accounting_basis },
                { label: "Raporlama Esasi", value: workspace.context.reporting_basis },
              ]}
            />
            <RuleList
              items={[
                "Tek duzen hesap karti, ust hesap hiyerarsisi olmadan kaydedilemez.",
                "Cari baglantili hesaplar cari kod olmadan fis kabul etmez.",
                "Masraf merkezi isteyen hesaplar boyut alanlari olmadan posting almaz.",
                "Pasif veya manuel girise kapali hesap kartlari fis satirinda kullanilamaz.",
              ]}
            />
          </div>
        </section>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Hesap Kartlari</div>
        <div className={styles.panelBody}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Kod</th>
                <th>Ad</th>
                <th>Sinif</th>
                <th>Seviye</th>
                <th>Ust Hesap</th>
                <th>Tur</th>
                <th>Bakiye Tarafi</th>
                <th>Rapor</th>
                <th>Para</th>
                <th>Zorunlu Alanlar</th>
                <th>Bakiye</th>
              </tr>
            </thead>
            <tbody>
              {workspace.items.map((item) => (
                <tr key={item.id}>
                  <td>{item.code}</td>
                  <td>{item.name}</td>
                  <td>{item.account_class}</td>
                  <td>{item.level}</td>
                  <td>{item.parent_code ?? "-"}</td>
                  <td>{item.account_type}</td>
                  <td>{item.balance_side}</td>
                  <td>{item.report_tag ?? "-"}</td>
                  <td>{item.currency}</td>
                  <td>
                    {[
                      item.requires_counterparty ? "cari" : null,
                      item.requires_cost_center ? "masraf merkezi" : null,
                      item.requires_project ? "proje" : null,
                    ]
                      .filter(Boolean)
                      .join(", ") || "-"}
                  </td>
                  <td>{money(item.current_balance, item.currency)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
      <section className={styles.gridTwo}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Hesap Karti Zorunlu Alanlari</div>
          <div className={styles.panelBody}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Alan</th>
                  <th>Zorunluluk</th>
                  <th>Amac</th>
                </tr>
              </thead>
              <tbody>
                {[
                  ["Hesap kodu", "zorunlu", "Tek duzen planinda benzersiz kart kimligi"],
                  ["Hesap adi", "zorunlu", "Kartin operasyonel ve raporlama basligi"],
                  ["Hesap turu", "zorunlu", "Varlik, borc, ozkaynak, gelir, gider veya cost ayrimi"],
                  ["Seviye / ust hesap", "zorunlu", "Ana hesap ve alt kirilim hiyerarsisi"],
                  ["Sube / sirket baglami", "zorunlu", "Yanlis organizasyon baglamini engeller"],
                  ["Para birimi", "zorunlu", "Dovizli muhasebe ve rapor koprusu"],
                  ["Rapor etiketi", "zorunlu", "Mizan, muavin, buyuk defter ve mali tablo baglantisi"],
                  ["Audit izi", "zorunlu", "Kim ne zaman degistirdi zinciri"],
                ].map(([field, required, purpose]) => (
                  <tr key={field}>
                    <td>{field}</td>
                    <td>{required}</td>
                    <td>{purpose}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Hesap Karti Operasyon Kurallari</div>
          <div className={styles.panelBody}>
            <RuleList
              items={[
                "Hesap karti olmadan fis satiri kayda alinmaz.",
                "Ust hesap ve alt hesap baglanti zinciri drill-down raporlarini bozmayacak sekilde korunur.",
                "Cari, banka, kasa, stok ve proje etkileri hesap karti baglamina yazilir.",
                "Pasif hesap karti aktif veri girisinde kullanilamaz.",
                "SQLite hesap karti tablosu, fis dogrulama motorunun birincil referansidir.",
              ]}
            />
          </div>
        </section>
      </section>
    </div>
  );
}

export function TrialBalanceWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: TrialBalanceWorkspace;
  moduleSlug?: string;
}) {
  const [currentWorkspace, setCurrentWorkspace] = useState(workspace);
  const [startDate, setStartDate] = useState(workspace.start_date ?? workspace.available_from ?? "");
  const [endDate, setEndDate] = useState(workspace.end_date ?? workspace.available_to ?? "");
  const [message, setMessage] = useState("");

  async function refreshTrialBalance(nextStartDate?: string, nextEndDate?: string) {
    const response = await getTrialBalanceWorkspace(nextStartDate, nextEndDate);
    if (!response) {
      setMessage("Mizan tarih araligi yeniden yuklenemedi.");
      return;
    }
    setCurrentWorkspace(response);
    setMessage(`Mizan ${response.start_date ?? "-"} ile ${response.end_date ?? "-"} araliginda yenilendi.`);
  }

  return (
    <div className={styles.desktopSurface}>
      <FinanceContextBar templateCode="trial-balance" title="Mizan" subtitle="Borc, alacak ve bakiye dagiliminin toplu kontrol penceresi" />
      <SourceBand />
      <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="trial-balance" sourceAction="trial-balance" />
      <section className={styles.metrics}>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Toplam Borc</div>
          <div className={styles.metricValueSmall}>{money(currentWorkspace.totals.debit_total)}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Toplam Alacak</div>
          <div className={styles.metricValueSmall}>{money(currentWorkspace.totals.credit_total)}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Net Bakiye</div>
          <div className={styles.metricValueSmall}>{money(currentWorkspace.totals.balance_total)}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Posting Modu</div>
          <div className={styles.metricValueSmall}>{currentWorkspace.fiscal_period.posting_mode}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Baslangic</div>
          <div className={styles.metricValueSmall}>{currentWorkspace.start_date ?? "-"}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Bitis</div>
          <div className={styles.metricValueSmall}>{currentWorkspace.end_date ?? "-"}</div>
        </article>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Mizan Tarih Araligi</div>
        <div className={styles.panelBody}>
          <div className={styles.fieldGridCompact}>
            <label className={styles.field}>
              <span>Baslangic Tarihi</span>
              <input
                type="date"
                value={startDate}
                min={currentWorkspace.available_from ?? undefined}
                max={endDate || currentWorkspace.available_to || undefined}
                onChange={(event) => setStartDate(event.target.value)}
              />
            </label>
            <label className={styles.field}>
              <span>Bitis Tarihi</span>
              <input
                type="date"
                value={endDate}
                min={startDate || currentWorkspace.available_from || undefined}
                max={currentWorkspace.available_to ?? undefined}
                onChange={(event) => setEndDate(event.target.value)}
              />
            </label>
            <div className={styles.fieldActionCell}>
              <button type="button" className={styles.actionButton} onClick={() => void refreshTrialBalance(startDate || undefined, endDate || undefined)}>
                Mizan Yenile
              </button>
              <button
                type="button"
                className={styles.secondaryActionButton}
                onClick={() => {
                  const nextStart = currentWorkspace.available_from ?? "";
                  const nextEnd = currentWorkspace.available_to ?? "";
                  setStartDate(nextStart);
                  setEndDate(nextEnd);
                  void refreshTrialBalance(nextStart || undefined, nextEnd || undefined);
                }}
              >
                Tum Donem
              </button>
            </div>
          </div>
          <ContextTable
            rows={[
              { label: "Veri Araligi", value: `${currentWorkspace.available_from ?? "-"} / ${currentWorkspace.available_to ?? "-"}` },
              { label: "Secili Aralik", value: `${currentWorkspace.start_date ?? "-"} / ${currentWorkspace.end_date ?? "-"}` },
              { label: "Donem", value: currentWorkspace.fiscal_period.period_label },
            ]}
          />
          {message ? <div className={styles.messageBar}>{message}</div> : null}
        </div>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Mizan Satirlari</div>
        <div className={styles.panelBody}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Kod</th>
                <th>Ad</th>
                <th>Borc</th>
                <th>Alacak</th>
                <th>Bakiye</th>
                <th>Aksiyon</th>
              </tr>
            </thead>
            <tbody>
              {currentWorkspace.items.map((item) => (
                <tr key={item.account_id}>
                  <td>{item.code}</td>
                  <td>{item.name}</td>
                  <td>{money(item.debit_total, item.currency)}</td>
                  <td>{money(item.credit_total, item.currency)}</td>
                  <td>{money(item.balance, item.currency)}</td>
                  <td>
                    <div className={styles.actionRow}>
                      <button
                        type="button"
                        className={styles.secondaryActionButton}
                        onClick={() =>
                          void openModuleWindow({
                            moduleSlug,
                            templateCode: "subledger",
                            recordId: item.code,
                            sourceRoute: `/windows/${moduleSlug}/trial-balance`,
                            sourceAction: "trial-balance-subledger",
                          })
                        }
                      >
                        Muavin Ac
                      </button>
                      <button
                        type="button"
                        className={styles.secondaryActionButton}
                        onClick={() =>
                          void openModuleWindow({
                            moduleSlug,
                            templateCode: "ledger",
                            recordId: item.code,
                            sourceRoute: `/windows/${moduleSlug}/trial-balance`,
                            sourceAction: "trial-balance-ledger",
                          })
                        }
                      >
                        Defter Ac
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className={styles.subsectionTitle}>Mizan Parametreleri</div>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Kod</th>
                <th>Baslik</th>
                <th>Deger</th>
              </tr>
            </thead>
            <tbody>
              {currentWorkspace.table_parameters.map((item) => (
                <tr key={item.parameter_code}>
                  <td>{item.parameter_code}</td>
                  <td>{item.title}</td>
                  <td>{item.value_text}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

export function SubledgerWindow({
  workspace,
  moduleSlug = "finance-gl",
  initialAccountCode,
}: {
  workspace: SubledgerWorkspace;
  moduleSlug?: string;
  initialAccountCode?: string;
}) {
  const [accountCode, setAccountCode] = useState(initialAccountCode ?? "");
  const [startDate, setStartDate] = useState(workspace.items.length ? workspace.items[0].entry_date : "");
  const [endDate, setEndDate] = useState(workspace.items.length ? workspace.items[workspace.items.length - 1].entry_date : "");
  const [sourceFilter, setSourceFilter] = useState("all");

  const filteredItems = workspace.items.filter((item) => {
    if (accountCode && item.account_code !== accountCode) {
      return false;
    }
    if (sourceFilter !== "all" && item.source_type !== sourceFilter) {
      return false;
    }
    if (startDate && item.entry_date < startDate) {
      return false;
    }
    if (endDate && item.entry_date > endDate) {
      return false;
    }
    return true;
  });

  return (
    <div className={styles.desktopSurface}>
      <FinanceContextBar
        templateCode="subledger"
        title="Muavin"
        subtitle="Hesap kartindan satir bazli yevmiye hareketi ve running balance takibi"
      />
      <SourceBand />
      <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="subledger" sourceAction="subledger" />
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Muavin Filtreleri</div>
        <div className={styles.panelBody}>
          <div className={styles.fieldGridCompact}>
            <label className={styles.field}>
              <span>Hesap Kodu</span>
              <input value={accountCode} onChange={(event) => setAccountCode(event.target.value)} placeholder="120.01" />
            </label>
            <label className={styles.field}>
              <span>Kaynak</span>
              <select value={sourceFilter} onChange={(event) => setSourceFilter(event.target.value)}>
                <option value="all">tum kaynaklar</option>
                {Array.from(new Set(workspace.items.map((item) => item.source_type))).map((item) => (
                  <option key={item} value={item}>
                    {item}
                  </option>
                ))}
              </select>
            </label>
            <label className={styles.field}>
              <span>Baslangic Tarihi</span>
              <input type="date" value={startDate} onChange={(event) => setStartDate(event.target.value)} />
            </label>
            <label className={styles.field}>
              <span>Bitis Tarihi</span>
              <input type="date" value={endDate} onChange={(event) => setEndDate(event.target.value)} />
            </label>
          </div>
        </div>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Muavin Hareketleri</div>
        <div className={styles.panelBody}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Hesap</th>
              <th>Tarih</th>
              <th>Kaynak</th>
              <th>Yon</th>
              <th>Tutar</th>
              <th>Kalan</th>
              <th>Aksiyon</th>
            </tr>
          </thead>
          <tbody>
            {filteredItems.map((item, index) => (
              <tr key={`${item.account_id}-${item.source_id}-${index}`}>
                <td>{item.account_code} / {item.account_name}</td>
                <td>{dateLabel(item.entry_date)}</td>
                <td>{item.source_type}</td>
                <td>{item.direction}</td>
                <td>{money(item.amount, item.currency)}</td>
                <td>{money(item.running_balance, item.currency)}</td>
                <td>
                  <div className={styles.actionRow}>
                    <button
                      type="button"
                      className={styles.secondaryActionButton}
                      onClick={() =>
                        void openModuleWindow({
                          moduleSlug,
                          templateCode: "voucher-detail",
                          recordId: item.source_id,
                          sourceRoute: `/windows/${moduleSlug}/subledger`,
                          sourceAction: "subledger-voucher-detail",
                        })
                      }
                    >
                      Fis Ac
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        </div>
      </section>
    </div>
  );
}

export function LedgerWindow({
  workspace,
  moduleSlug = "finance-gl",
  initialAccountCode,
}: {
  workspace: LedgerWorkspace;
  moduleSlug?: string;
  initialAccountCode?: string;
}) {
  const [accountCode, setAccountCode] = useState(initialAccountCode ?? "");
  const [voucherNumber, setVoucherNumber] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [startDate, setStartDate] = useState(workspace.items.length ? workspace.items[workspace.items.length - 1].entry_date : "");
  const [endDate, setEndDate] = useState(workspace.items.length ? workspace.items[0].entry_date : "");

  const filteredItems = workspace.items.filter((item) => {
    if (accountCode && item.account_code !== accountCode) {
      return false;
    }
    if (voucherNumber && !item.voucher_number.toLowerCase().includes(voucherNumber.toLowerCase())) {
      return false;
    }
    if (statusFilter !== "all" && item.status !== statusFilter) {
      return false;
    }
    if (startDate && item.entry_date < startDate) {
      return false;
    }
    if (endDate && item.entry_date > endDate) {
      return false;
    }
    return true;
  });

  return (
    <div className={styles.desktopSurface}>
      <FinanceContextBar
        templateCode="ledger"
        title="Buyuk Defter"
        subtitle="Fis ve hesap satirlarinin borc-alacak etkisini gosteren pencere"
      />
      <SourceBand />
      <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="ledger" sourceAction="ledger" />
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Buyuk Defter Filtreleri</div>
        <div className={styles.panelBody}>
          <div className={styles.fieldGridCompact}>
            <label className={styles.field}>
              <span>Hesap Kodu</span>
              <input value={accountCode} onChange={(event) => setAccountCode(event.target.value)} placeholder="120.01" />
            </label>
            <label className={styles.field}>
              <span>Fis No</span>
              <input value={voucherNumber} onChange={(event) => setVoucherNumber(event.target.value)} placeholder="YVM-..." />
            </label>
            <label className={styles.field}>
              <span>Durum</span>
              <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}>
                <option value="all">tum durumlar</option>
                <option value="draft">taslak</option>
                <option value="posted">posted</option>
              </select>
            </label>
            <label className={styles.field}>
              <span>Baslangic Tarihi</span>
              <input type="date" value={startDate} onChange={(event) => setStartDate(event.target.value)} />
            </label>
            <label className={styles.field}>
              <span>Bitis Tarihi</span>
              <input type="date" value={endDate} onChange={(event) => setEndDate(event.target.value)} />
            </label>
          </div>
        </div>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Defter Satirlari</div>
        <div className={styles.panelBody}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Fis</th>
              <th>Hesap</th>
              <th>Tarih</th>
              <th>Borc</th>
              <th>Alacak</th>
              <th>Etki</th>
              <th>Aksiyon</th>
            </tr>
          </thead>
          <tbody>
            {filteredItems.map((item) => (
              <tr key={`${item.voucher_id}-${item.account_code}-${item.balance_effect}`}>
                <td>{item.voucher_number}</td>
                <td>{item.account_code} / {item.account_name}</td>
                <td>{dateLabel(item.entry_date)}</td>
                <td>{money(item.debit)}</td>
                <td>{money(item.credit)}</td>
                <td>{money(item.balance_effect)}</td>
                <td>
                  <div className={styles.actionRow}>
                    <button
                      type="button"
                      className={styles.secondaryActionButton}
                      onClick={() =>
                        void openModuleWindow({
                          moduleSlug,
                          templateCode: "voucher-detail",
                          recordId: item.voucher_id,
                          sourceRoute: `/windows/${moduleSlug}/ledger`,
                          sourceAction: "ledger-voucher-detail",
                        })
                      }
                    >
                      Fis Ac
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        </div>
      </section>
    </div>
  );
}

export function BankReconciliationWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: BankReconciliationWorkspace;
  moduleSlug?: string;
}) {
  return (
    <div className={styles.desktopSurface}>
      <FinanceContextBar templateCode="bank-reconciliation" title="Banka ve Kasa Mutabakati" subtitle="Defter, tahsilat ve hareket zincirinin fark bazli kontrol penceresi" />
      <SourceBand />
      <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="bank-reconciliation" sourceAction="bank-reconciliation" />
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Mutabakat Satirlari</div>
        <div className={styles.panelBody}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Hesap</th>
              <th>Defter Bakiyesi</th>
              <th>Tahsilat</th>
              <th>Hareket</th>
              <th>Fark</th>
              <th>Durum</th>
            </tr>
          </thead>
          <tbody>
            {workspace.rows.map((item) => (
              <tr key={item.treasury_account_id}>
                <td>{item.account_code} / {item.account_name}</td>
                <td>{money(item.ledger_balance)}</td>
                <td>{money(item.payment_total)}</td>
                <td>{money(item.movement_total)}</td>
                <td>{money(item.difference)}</td>
                <td>{item.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
        </div>
      </section>
    </div>
  );
}

export function FinanceParametersWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: FinanceParametersWorkspace;
  moduleSlug?: string;
}) {
  return (
    <div className={styles.desktopSurface}>
        <FinanceContextBar templateCode="parameters" title="Muhasebe Parametreleri" subtitle="Sabit tanim, seri, belge ve rapor parametrelerinin teknik pencere merkezi" />
        <SourceBand />
        <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="parameters" sourceAction="parameters" />
      <section className={styles.metrics}>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Parametre</div>
          <div className={styles.metricValue}>{workspace.items.length}</div>
          <div className={styles.metricFoot}>Merkezi muhasebe sabit tanimi</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Grup</div>
          <div className={styles.metricValue}>{workspace.groups.length}</div>
          <div className={styles.metricFoot}>Zorunlu alan gruplari</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Veri Katmani</div>
          <div className={styles.metricValue}>{workspace.data_architecture.length}</div>
          <div className={styles.metricFoot}>Header, line, context ve audit zinciri</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Entegrator</div>
          <div className={styles.metricValue}>{workspace.integrator_profiles.length}</div>
          <div className={styles.metricFoot}>Test ve uretim profilleri</div>
        </article>
      </section>
      <section className={styles.gridTwo}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Baglam ve Donem Parametreleri</div>
          <div className={styles.panelBody}>
            <ContextTable
              rows={[
                { label: "Sirket", value: workspace.context.company_name },
                { label: "Sube", value: workspace.context.branch_name },
                { label: "Defter", value: workspace.context.ledger_name },
                { label: "Donem", value: `${workspace.context.fiscal_year} / ${workspace.context.fiscal_period}` },
                { label: "Donem Durumu", value: workspace.fiscal_period.status },
                { label: "Posting Modu", value: workspace.fiscal_period.posting_mode },
              ]}
            />
          </div>
        </section>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>SQL Benzeri Parametre Saklama</div>
          <div className={styles.panelBody}>
            <RuleList
              items={[
                "Muhasebe parametreleri accounting_parameters tablosunda merkezi saklanir.",
                "Fiş baslik ve satir akisi journal_entries ve journal_entry_lines uzerinden yazilir.",
                "Belge baglami ve sabit tanim snapshot'i journal_entry_contexts icinde korunur.",
                "Audit ve red gerekceleri audit_events katmaninda izlenir.",
              ]}
            />
          </div>
        </section>
      </section>
      <section className={styles.gridTwo}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Parametre Grup Ozeti</div>
          <div className={styles.panelBody}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Grup</th>
                  <th>Baslik</th>
                  <th>Adet</th>
                  <th>Kaynaklar</th>
                </tr>
              </thead>
              <tbody>
                {workspace.groups.map((group) => (
                  <tr key={group.parameter_group}>
                    <td>{group.parameter_group}</td>
                    <td>{group.title}</td>
                    <td>{group.item_count}</td>
                    <td>{group.source_families.join(", ")}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Veri Mimarisi Agaci</div>
          <div className={styles.panelBody}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Katman</th>
                  <th>Dugum</th>
                  <th>Tablo</th>
                  <th>Gorev</th>
                </tr>
              </thead>
              <tbody>
                {workspace.data_architecture.map((node) => (
                  <tr key={node.node_code}>
                    <td>{node.layer}</td>
                    <td>{node.title}</td>
                    <td>{node.storage_target}</td>
                    <td>{node.detail}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Sabit Tanim ve Parametre Listesi</div>
        <div className={styles.panelBody}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Grup</th>
                <th>Kod</th>
                <th>Baslik</th>
                <th>Deger</th>
                <th>Kaynak</th>
              </tr>
            </thead>
            <tbody>
              {workspace.items.map((item) => (
                <tr key={item.parameter_code}>
                  <td>{item.parameter_group}</td>
                  <td>{item.parameter_code}</td>
                  <td>{item.title}</td>
                  <td>{item.value_text}</td>
                  <td>{item.source_family}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Entegrator Profil Izleri</div>
        <div className={styles.panelBody}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Profil</th>
                <th>Saglayici</th>
                <th>Mod</th>
                <th>Belge Tipleri</th>
                <th>Endpoint</th>
                <th>Durum</th>
              </tr>
            </thead>
            <tbody>
              {workspace.integrator_profiles.map((profile) => (
                <tr key={profile.profile_code}>
                  <td>{profile.profile_code}</td>
                  <td>{profile.provider_name}</td>
                  <td>{profile.mode}</td>
                  <td>{profile.document_types.join(", ")}</td>
                  <td>{profile.endpoint_url}</td>
                  <td>{profile.status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

export function IntegratorProfilesWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: FinanceParametersWorkspace;
  moduleSlug?: string;
}) {
  const [profileCode, setProfileCode] = useState("ozel-entegrator-test-2");
  const [providerName, setProviderName] = useState("Yeni Entegrator Profili");
  const [mode, setMode] = useState("test");
  const [endpointUrl, setEndpointUrl] = useState("https://ebelge.gib.gov.tr/");
  const [documentTypes, setDocumentTypes] = useState("e_invoice,e_archive,e_ledger");
  const [gibAlias, setGibAlias] = useState("urn:mail:yeni@leyla.local");
  const [certificateLabel, setCertificateLabel] = useState("mali-muhur-profili");
  const [username, setUsername] = useState("entegrator-operator");
  const [status, setStatus] = useState("active");
  const [message, setMessage] = useState("");

  async function createProfile() {
    const result = await createFinanceIntegratorProfile({
      profile_code: profileCode,
      provider_name: providerName,
      mode,
      endpoint_url: endpointUrl,
      document_types: documentTypes.split(",").map((item) => item.trim()).filter(Boolean),
      gib_alias: gibAlias,
      certificate_label: certificateLabel,
      username,
      status,
      notes: null,
    });

    if (!result) {
      setMessage("Profil kaydi olusturulamadi. Kod benzersiz ve alanlar dolu olmali.");
      return;
    }

    setMessage(`Profil kaydedildi: ${result.profile_code}`);
    window.location.reload();
  }

  return (
    <div className={styles.desktopSurface}>
      <FinanceContextBar
        templateCode="integrator-profiles"
        title="Entegrator Profilleri"
        subtitle="e-Belge test, uretim, sertifika ve endpoint yonetim penceresi"
      />
      <SourceBand />
      <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="integrator-profiles" sourceAction="integrator-profiles" />
      <section className={styles.metrics}>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Toplam Profil</div>
          <div className={styles.metricValue}>{workspace.integrator_profiles.length}</div>
          <div className={styles.metricFoot}>Takilabilir baglanti profili</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Aktif Test</div>
          <div className={styles.metricValue}>
            {workspace.integrator_profiles.filter((item) => item.mode === "test" && item.status === "active").length}
          </div>
          <div className={styles.metricFoot}>Test dogrulama profilleri</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Aktif Uretim</div>
          <div className={styles.metricValue}>
            {workspace.integrator_profiles.filter((item) => item.mode === "production" && item.status === "active").length}
          </div>
          <div className={styles.metricFoot}>Canliya hazir profiller</div>
        </article>
      </section>
      <section className={styles.gridTwo}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Profil Kayit Formu</div>
          <div className={styles.panelBody}>
            <div className={styles.fieldGrid}>
              <label className={styles.field}>
                <span>Profil Kod</span>
                <input value={profileCode} onChange={(event) => setProfileCode(event.target.value)} />
              </label>
              <label className={styles.fieldWide}>
                <span>Saglayici Adi</span>
                <input value={providerName} onChange={(event) => setProviderName(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Mod</span>
                <select value={mode} onChange={(event) => setMode(event.target.value)}>
                  <option value="test">test</option>
                  <option value="production">production</option>
                </select>
              </label>
              <label className={styles.fieldWide}>
                <span>Endpoint</span>
                <input value={endpointUrl} onChange={(event) => setEndpointUrl(event.target.value)} />
              </label>
              <label className={styles.fieldWide}>
                <span>Belge Tipleri</span>
                <input value={documentTypes} onChange={(event) => setDocumentTypes(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>GIB Alias</span>
                <input value={gibAlias} onChange={(event) => setGibAlias(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Sertifika</span>
                <input value={certificateLabel} onChange={(event) => setCertificateLabel(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Kullanici</span>
                <input value={username} onChange={(event) => setUsername(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Durum</span>
                <select value={status} onChange={(event) => setStatus(event.target.value)}>
                  <option value="active">active</option>
                  <option value="passive">passive</option>
                </select>
              </label>
            </div>
            <div className={styles.actionRow}>
              <button type="button" className={styles.actionButton} onClick={() => void createProfile()}>
                Profil Kaydet
              </button>
            </div>
            {message ? <div className={styles.messageBar}>{message}</div> : null}
          </div>
        </section>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Kayitli Entegrator Profilleri</div>
        <div className={styles.panelBody}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Profil</th>
                <th>Saglayici</th>
                <th>Mod</th>
                <th>Belge Tipleri</th>
                <th>Alias</th>
                <th>Endpoint</th>
                <th>Durum</th>
              </tr>
            </thead>
            <tbody>
              {workspace.integrator_profiles.map((profile) => (
                <tr key={profile.profile_code}>
                  <td>{profile.profile_code}</td>
                  <td>{profile.provider_name}</td>
                  <td>{profile.mode}</td>
                  <td>{profile.document_types.join(", ")}</td>
                  <td>{profile.gib_alias ?? "-"}</td>
                  <td>{profile.endpoint_url}</td>
                  <td>{profile.status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

function CurrentAccountWindow({
  workspace,
  moduleSlug,
  sourceAction,
  windowTitle,
  subtitle,
  defaultCardCode,
  defaultTitle,
}: {
  workspace: CurrentAccountWorkspace;
  moduleSlug: string;
  sourceAction: string;
  windowTitle: string;
  subtitle: string;
  defaultCardCode: string;
  defaultTitle: string;
}) {
  const [cardCode, setCardCode] = useState(defaultCardCode);
  const [title, setTitle] = useState(defaultTitle);
  const [taxIdentifier, setTaxIdentifier] = useState("");
  const [paymentTerm, setPaymentTerm] = useState(workspace.card_type === "customer" ? "30 gun" : "45 gun");
  const [riskLimit, setRiskLimit] = useState(workspace.card_type === "customer" ? "50000" : "125000");
  const [integrationProfile, setIntegrationProfile] = useState("ozel-entegrator-uretim");
  const [contactEmail, setContactEmail] = useState("");
  const [contactPhone, setContactPhone] = useState("");
  const [openingBalance, setOpeningBalance] = useState("0");
  const [selectedCardId, setSelectedCardId] = useState(workspace.items[0]?.id ?? "");
  const [entryDate, setEntryDate] = useState("2026-04-01");
  const [entryType, setEntryType] = useState(workspace.card_type === "customer" ? "collection" : "vendor-payment");
  const [direction, setDirection] = useState(workspace.card_type === "customer" ? "credit" : "debit");
  const [amount, setAmount] = useState("1000");
  const [referenceCode, setReferenceCode] = useState("");
  const [message, setMessage] = useState("");

  async function createCard() {
    const result = await createCurrentAccountCard({
      card_type: workspace.card_type,
      card_code: cardCode,
      title,
      tax_identifier: taxIdentifier || null,
      payment_term: paymentTerm || null,
      risk_limit: Number(riskLimit),
      opening_balance: Number(openingBalance),
      integration_profile: integrationProfile || null,
      contact_email: contactEmail || null,
      contact_phone: contactPhone || null,
      notes: null,
    });
    if (!result) {
      setMessage("Cari kart olusturulamadi");
      return;
    }
    window.location.reload();
  }

  async function createEntry() {
    if (!selectedCardId) {
      setMessage("Once bir cari kart secin");
      return;
    }
    const result = await createCurrentAccountEntry(selectedCardId, {
      entry_date: entryDate,
      entry_type: entryType,
      direction,
      amount: Number(amount),
      reference_code: referenceCode || null,
      note_text: null,
      source_type: "finance-window",
      source_id: `${workspace.card_type}-${Date.now()}`,
    });
    if (!result) {
      setMessage("Cari hareket olusturulamadi");
      return;
    }
    window.location.reload();
  }

  return (
    <div className={styles.desktopSurface}>
      <FinanceContextBar templateCode={sourceAction} title={windowTitle} subtitle={subtitle} />
      <SourceBand />
      <FinancePopupActionBar moduleSlug={moduleSlug} templateCode={sourceAction} sourceAction={sourceAction} />
      <section className={styles.metrics}>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Cari Kart</div>
          <div className={styles.metricValue}>{workspace.items.length}</div>
          <div className={styles.metricFoot}>SQLite cari kart kayitlari</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Hareket</div>
          <div className={styles.metricValue}>{workspace.latest_entries.length}</div>
          <div className={styles.metricFoot}>Son kayitli cari hareketler</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Zorunlu Alan</div>
          <div className={styles.metricValue}>{workspace.required_fields.length}</div>
          <div className={styles.metricFoot}>Kart olusum standardi</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Profil</div>
          <div className={styles.metricValue}>{workspace.items.filter((item) => item.integration_profile).length}</div>
          <div className={styles.metricFoot}>Profil bagli cari kartlar</div>
        </article>
      </section>
      <section className={styles.gridTwo}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Cari Kart Olusturma</div>
          <div className={styles.panelBody}>
            <div className={styles.fieldGrid}>
              <label className={styles.field}>
                <span>Kart Kod</span>
                <input value={cardCode} onChange={(event) => setCardCode(event.target.value)} />
              </label>
              <label className={styles.fieldWide}>
                <span>Unvan</span>
                <input value={title} onChange={(event) => setTitle(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>VKN / TCKN</span>
                <input value={taxIdentifier} onChange={(event) => setTaxIdentifier(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Odeme / Vade</span>
                <input value={paymentTerm} onChange={(event) => setPaymentTerm(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Risk Limiti</span>
                <input value={riskLimit} onChange={(event) => setRiskLimit(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Acilis Bakiye</span>
                <input value={openingBalance} onChange={(event) => setOpeningBalance(event.target.value)} />
              </label>
              <label className={styles.fieldWide}>
                <span>Entegrator Profili</span>
                <input value={integrationProfile} onChange={(event) => setIntegrationProfile(event.target.value)} />
              </label>
              <label className={styles.fieldWide}>
                <span>E-Posta</span>
                <input value={contactEmail} onChange={(event) => setContactEmail(event.target.value)} />
              </label>
              <label className={styles.fieldWide}>
                <span>Telefon</span>
                <input value={contactPhone} onChange={(event) => setContactPhone(event.target.value)} />
              </label>
            </div>
            <div className={styles.actionRow}>
              <button type="button" className={styles.actionButton} onClick={() => void createCard()}>
                Cari Kart Kaydet
              </button>
            </div>
            <div className={styles.subsectionTitle}>Zorunlu Kart Alanlari</div>
            <RuleList items={workspace.required_fields.map((item) => `${item} zorunlu`)} />
          </div>
        </section>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Cari Hareket Olusturma</div>
          <div className={styles.panelBody}>
            <div className={styles.fieldGrid}>
              <label className={styles.fieldWide}>
                <span>Cari Kart</span>
                <select value={selectedCardId} onChange={(event) => setSelectedCardId(event.target.value)}>
                  {workspace.items.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.card_code} / {item.title}
                    </option>
                  ))}
                </select>
              </label>
              <label className={styles.field}>
                <span>Tarih</span>
                <input value={entryDate} onChange={(event) => setEntryDate(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Tur</span>
                <input value={entryType} onChange={(event) => setEntryType(event.target.value)} />
              </label>
              <label className={styles.field}>
                <span>Yon</span>
                <select value={direction} onChange={(event) => setDirection(event.target.value)}>
                  <option value="debit">debit</option>
                  <option value="credit">credit</option>
                </select>
              </label>
              <label className={styles.field}>
                <span>Tutar</span>
                <input value={amount} onChange={(event) => setAmount(event.target.value)} />
              </label>
              <label className={styles.fieldWide}>
                <span>Referans</span>
                <input value={referenceCode} onChange={(event) => setReferenceCode(event.target.value)} />
              </label>
            </div>
            <div className={styles.actionRow}>
              <button type="button" className={styles.actionButton} onClick={() => void createEntry()}>
                Cari Hareket Kaydet
              </button>
            </div>
            {message ? <div className={styles.messageBar}>{message}</div> : null}
          </div>
        </section>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Cari Kartlar</div>
        <div className={styles.panelBody}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Kod</th>
                <th>Unvan</th>
                <th>Bakiye</th>
                <th>Borc</th>
                <th>Alacak</th>
                <th>Hareket</th>
                <th>Profil</th>
              </tr>
            </thead>
            <tbody>
              {workspace.items.map((item) => (
                <tr key={item.id}>
                  <td>{item.card_code}</td>
                  <td>{item.title}</td>
                  <td>{money(item.balance, item.currency)}</td>
                  <td>{money(item.debit_total, item.currency)}</td>
                  <td>{money(item.credit_total, item.currency)}</td>
                  <td>{item.entry_count}</td>
                  <td>{item.integration_profile ?? "-"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Son Cari Hareketler</div>
        <div className={styles.panelBody}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Kart</th>
                <th>Tarih</th>
                <th>Tur</th>
                <th>Yon</th>
                <th>Tutar</th>
                <th>Referans</th>
              </tr>
            </thead>
            <tbody>
              {workspace.latest_entries.map((item) => (
                <tr key={item.id}>
                  <td>{item.card_code} / {item.card_title}</td>
                  <td>{dateLabel(item.entry_date)}</td>
                  <td>{item.entry_type}</td>
                  <td>{item.direction}</td>
                  <td>{money(item.amount, item.currency)}</td>
                  <td>{item.reference_code ?? "-"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

export function CustomerCurrentAccountsWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: CurrentAccountWorkspace;
  moduleSlug?: string;
}) {
  return (
    <CurrentAccountWindow
      workspace={workspace}
      moduleSlug={moduleSlug}
      sourceAction="customer-current-accounts"
      windowTitle="Musteri Cari Kartlari"
      subtitle="Tahsilat, ekstre ve cari risk takibinin SQLite pencere merkezi"
      defaultCardCode="CARI-0002"
      defaultTitle="Yeni Musteri Cari"
    />
  );
}

export function VendorCurrentAccountsWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: CurrentAccountWorkspace;
  moduleSlug?: string;
}) {
  return (
    <CurrentAccountWindow
      workspace={workspace}
      moduleSlug={moduleSlug}
      sourceAction="vendor-current-accounts"
      windowTitle="Satici Cari Kartlari"
      subtitle="Tedarikci, odeme plani ve mutabakat zincirinin SQLite pencere merkezi"
      defaultCardCode="TED-0002"
      defaultTitle="Yeni Tedarikci Cari"
    />
  );
}

export function TaxComplianceWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: TaxComplianceWorkspace;
  moduleSlug?: string;
}) {
  return (
    <div className={styles.desktopSurface}>
        <FinanceContextBar templateCode="tax-compliance" title="Vergi ve Yasal Uyum" subtitle="KDV, stopaj, belge ve yasal kontrol zincirinin teknik pencere merkezi" />
        <SourceBand />
        <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="tax-compliance" sourceAction="tax-compliance" />
      <section className={styles.metrics}>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Durum</div>
          <div className={styles.metricValueSmall}>{workspace.status}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Muhasebe Esasi</div>
          <div className={styles.metricValueSmall}>{workspace.context.accounting_basis}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Raporlama</div>
          <div className={styles.metricValueSmall}>{workspace.context.reporting_basis}</div>
        </article>
      </section>
      <section className={styles.gridTwo}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Kontrol Noktalari</div>
          <div className={styles.panelBody}>
            <RuleList items={workspace.control_points} />
          </div>
        </section>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Entegrator Profilleri</div>
          <div className={styles.panelBody}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Profil</th>
                  <th>Mod</th>
                  <th>Belge Tipleri</th>
                  <th>Durum</th>
                </tr>
              </thead>
              <tbody>
                {workspace.integrator_profiles.map((profile) => (
                  <tr key={profile.profile_code}>
                    <td>{profile.profile_code}</td>
                    <td>{profile.mode}</td>
                    <td>{profile.document_types.join(", ")}</td>
                    <td>{profile.status}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </section>
    </div>
  );
}

export function PeriodCloseWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: PeriodCloseWorkspace;
  moduleSlug?: string;
}) {
  return (
    <div className={styles.desktopSurface}>
        <FinanceContextBar templateCode="period-close" title="Donem Acilis ve Kapanis" subtitle="Acik donem, blocker ve kapanis hazirlik kontrol penceresi" />
        <SourceBand />
        <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="period-close" sourceAction="period-close" />
      <section className={styles.metrics}>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Donem</div>
          <div className={styles.metricValueSmall}>{workspace.context.fiscal_period}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Acik Donem</div>
          <div className={styles.metricValueSmall}>{workspace.open_period ? "evet" : "hayir"}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Kapanisa Hazir</div>
          <div className={styles.metricValueSmall}>{workspace.close_ready ? "hazir" : "blokeli"}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Bloker</div>
          <div className={styles.metricValueSmall}>{workspace.blockers.length}</div>
        </article>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Kapanis Blokerleri</div>
        <div className={styles.panelBody}>
          <RuleList items={workspace.blockers.length ? workspace.blockers : ["Kapanis icin acik bloker bulunmuyor."]} />
        </div>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Zorunlu Kapanis Adimlari</div>
        <div className={styles.panelBody}>
          <RuleList items={workspace.closure_steps} />
        </div>
      </section>
    </div>
  );
}

export function EDocumentWindow({
  workspace,
  readiness,
  moduleSlug = "finance-gl",
}: {
  workspace: EDocumentWorkspace;
  readiness: EDocumentIntegrationReadiness | null;
  moduleSlug?: string;
}) {
  return (
    <div className={styles.desktopSurface}>
        <FinanceContextBar templateCode="e-documents" title="e-Belge Merkezi" subtitle="GIB kaynagi, ozel entegrator modeli ve belge yasam dongusu penceresi" />
        <SourceBand />
        <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="e-documents" sourceAction="e-documents" />
      <section className={styles.gridTwo}>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>e-Belge Merkezi</div>
        <div className={styles.panelBody}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Tur</th>
                <th>Referans</th>
                <th>Donem</th>
                <th>Durum</th>
              </tr>
            </thead>
            <tbody>
              {workspace.items.map((item) => (
                <tr key={item.id}>
                  <td>{item.document_type}</td>
                  <td>{item.reference_code ?? "-"}</td>
                  <td>{item.period_key ?? "-"}</td>
                  <td>{item.status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className={styles.panel}>
        <div className={styles.panelHeader}>GIB ve Entegrator Hazirligi</div>
        <div className={styles.panelBody}>
          <ContextTable
            rows={[
              { label: "GIB Kaynagi", value: readiness?.gib_source_required ? "zorunlu" : "opsiyonel" },
              { label: "Entegrator Modeli", value: readiness?.integrator_model ?? "veri yok" },
              { label: "Profil Durumu", value: readiness?.profile_status ?? "veri yok" },
              { label: "Hazirlik", value: readiness?.integrator_ready ? "hazir" : "kismi" },
            ]}
          />
          <div className={styles.subsectionTitle}>Kabiliyetler</div>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Kabiliyet</th>
                <th>Durum</th>
                <th>Kaynak</th>
              </tr>
            </thead>
            <tbody>
              {(readiness?.capabilities ?? []).map((item) => (
                <tr key={item.capability_code}>
                  <td>{item.title}</td>
                  <td>{item.status}</td>
                  <td>{item.source_ref}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </section>
    <section className={styles.panel}>
      <div className={styles.panelHeader}>Entegrator Profilleri</div>
      <div className={styles.panelBody}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Profil</th>
              <th>Saglayici</th>
              <th>Mod</th>
              <th>Belge Tipleri</th>
              <th>Endpoint</th>
              <th>Durum</th>
            </tr>
          </thead>
          <tbody>
            {(readiness?.integrator_profiles ?? workspace.integrator_profiles).map((profile) => (
              <tr key={profile.profile_code}>
                <td>{profile.profile_code}</td>
                <td>{profile.provider_name}</td>
                <td>{profile.mode}</td>
                <td>{profile.document_types.join(", ")}</td>
                <td>{profile.endpoint_url}</td>
                <td>{profile.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
    </div>
  );
}

export function ELedgerWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: ELedgerWorkspace;
  moduleSlug?: string;
}) {
  return (
    <div className={styles.desktopSurface}>
        <FinanceContextBar templateCode="e-ledger" title="e-Defter Merkezi" subtitle="Yevmiye, buyuk defter ve berat akisinin resmi pencere zinciri" />
        <SourceBand />
        <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="e-ledger" sourceAction="e-ledger" />
      <section className={styles.metrics}>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Hazirlik</div>
          <div className={styles.metricValueSmall}>{workspace.ready ? "hazir" : "blokeli"}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Bloker</div>
          <div className={styles.metricValue}>{workspace.blockers.length}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Belge</div>
          <div className={styles.metricValue}>{workspace.generated_documents.length}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Son Tarih</div>
          <div className={styles.metricValueSmall}>{workspace.submission_deadline ?? "-"}</div>
        </article>
      </section>
      <section className={styles.gridTwo}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>e-Defter Adimlari</div>
          <div className={styles.panelBody}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Adim</th>
                  <th>Durum</th>
                  <th>Kaynak</th>
                </tr>
              </thead>
              <tbody>
                {workspace.steps.map((step) => (
                  <tr key={step.step_code}>
                    <td>{step.title}</td>
                    <td>{step.status}</td>
                    <td>{step.source_ref}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
        <section className={styles.panel}>
          <div className={styles.panelHeader}>Donem ve Berat Bilgisi</div>
          <div className={styles.panelBody}>
            <ContextTable
              rows={[
                { label: "Donem", value: workspace.period_status.period_label },
                { label: "Posting Modu", value: workspace.period_status.posting_mode },
                { label: "Berat Referansi", value: workspace.berat_reference ?? "-" },
                { label: "Hazirlik", value: workspace.ready ? "tam" : "eksik" },
              ]}
            />
            <RuleList items={workspace.blockers.length ? workspace.blockers : ["e-Defter paketi icin acik bloker bulunmuyor."]} />
          </div>
        </section>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Uretilen Defter Belgeleri</div>
        <div className={styles.panelBody}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Belge Turu</th>
                <th>Referans</th>
                <th>Donem</th>
                <th>Durum</th>
              </tr>
            </thead>
            <tbody>
              {workspace.generated_documents.map((item) => (
                <tr key={item.id}>
                  <td>{item.document_type}</td>
                  <td>{item.reference_code ?? "-"}</td>
                  <td>{item.period_key ?? "-"}</td>
                  <td>{item.status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

export function FiscalCalendarWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: FiscalCalendarWorkspace;
  moduleSlug?: string;
}) {
  return (
    <div className={styles.desktopSurface}>
        <FinanceContextBar templateCode="fiscal-calendar" title="Mali Takvim" subtitle="GIB, VUK ve donem sonu son tarih zincirinin parametrik penceresi" />
        <SourceBand />
        <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="fiscal-calendar" sourceAction="fiscal-calendar" />
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Takvim Kalemleri</div>
        <div className={styles.panelBody}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Kod</th>
                <th>Baslik</th>
                <th>Yururluk</th>
                <th>Son Tarih</th>
                <th>Durum</th>
              </tr>
            </thead>
            <tbody>
              {workspace.items.map((item) => (
                <tr key={item.calendar_code}>
                  <td>{item.calendar_code}</td>
                  <td>{item.title}</td>
                  <td>{item.effective_date}</td>
                  <td>{item.deadline}</td>
                  <td>{item.status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

export function ReportSnapshotsWindow({
  workspace,
  moduleSlug = "finance-gl",
}: {
  workspace: ReportSnapshotsWorkspace;
  moduleSlug?: string;
}) {
  return (
    <div className={styles.desktopSurface}>
        <FinanceContextBar templateCode="report-snapshots" title="Rapor Snapshot Merkezi" subtitle="Yasal raporlarin export, drill ve snapshot kontrol penceresi" />
        <SourceBand />
        <FinancePopupActionBar moduleSlug={moduleSlug} templateCode="report-snapshots" sourceAction="report-snapshots" />
      <section className={styles.metrics}>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Snapshot</div>
          <div className={styles.metricValue}>{workspace.items.length}</div>
        </article>
        <article className={styles.metricCard}>
          <div className={styles.metricLabel}>Export</div>
          <div className={styles.metricValueSmall}>{workspace.enabled_exports.join(", ").toUpperCase()}</div>
        </article>
      </section>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>Rapor Paketleri</div>
        <div className={styles.panelBody}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Baslik</th>
                <th>Tur</th>
                <th>Donem</th>
                <th>Uretim</th>
                <th>Format</th>
                <th>Kaynak</th>
              </tr>
            </thead>
            <tbody>
              {workspace.items.map((item) => (
                <tr key={item.snapshot_code}>
                  <td>{item.title}</td>
                  <td>{item.report_type}</td>
                  <td>{item.period_key}</td>
                  <td>{item.generated_at ? dateLabel(item.generated_at) : "-"}</td>
                  <td>{item.format_options.join(", ")}</td>
                  <td>{item.source_ref}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
