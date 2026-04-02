import type { CSSProperties } from "react";

import type { FinanceUiAction, FinanceUiContract, FinanceUiReferenceShell, FinanceUiWindow } from "@/lib/api";

export const DEFAULT_FINANCE_UI_CONTRACT: FinanceUiContract = {
  module_slug: "finance-gl",
  display_name: "Muhasebe ve Finans UI Contract",
  version: "2026.04",
  contract_version: "2026.04",
  theme_tokens: {},
  source_band: [
    { label: "SQLite", tone: "default" },
    { label: "Finans", tone: "default" },
    { label: "e-Belge", tone: "critical" },
  ],
  status_badges: ["Popup calisma modeli", "VUK / Tek Duzen", "Drill-down zorunlu"],
  window_family_tabs: [
    { label: "Genel Gorunum", template_code: "overview" },
    { label: "Hesap Plani", template_code: "chart-of-accounts" },
    { label: "Yeni Fis", template_code: "voucher-new" },
    { label: "Fis Listesi", template_code: "voucher-list" },
    { label: "Mizan", template_code: "trial-balance" },
    { label: "Muavin", template_code: "subledger" },
    { label: "Buyuk Defter", template_code: "ledger" },
    { label: "Banka Mutabakati", template_code: "bank-reconciliation" },
    { label: "Musteri Cari", template_code: "customer-current-accounts" },
    { label: "Satici Cari", template_code: "vendor-current-accounts" },
    { label: "Parametreler", template_code: "parameters" },
    { label: "Entegrator Profilleri", template_code: "integrator-profiles" },
    { label: "Vergi Uyumu", template_code: "tax-compliance" },
    { label: "Donem Kapanis", template_code: "period-close" },
    { label: "e-Belge", template_code: "e-documents" },
    { label: "e-Defter", template_code: "e-ledger" },
    { label: "Mali Takvim", template_code: "fiscal-calendar" },
    { label: "Rapor Snapshot", template_code: "report-snapshots" },
  ],
  popup_actions: [
    { label: "Hesap Plani", template_code: "chart-of-accounts" },
    { label: "Yeni Fis", template_code: "voucher-new" },
    { label: "Fis Listesi", template_code: "voucher-list" },
    { label: "Mizan", template_code: "trial-balance" },
    { label: "Muavin", template_code: "subledger" },
    { label: "Buyuk Defter", template_code: "ledger" },
    { label: "Banka Mutabakati", template_code: "bank-reconciliation" },
    { label: "Musteri Cari", template_code: "customer-current-accounts" },
    { label: "Satici Cari", template_code: "vendor-current-accounts" },
    { label: "Parametreler", template_code: "parameters" },
    { label: "Vergi Uyumu", template_code: "tax-compliance" },
    { label: "Donem Kapanis", template_code: "period-close" },
    { label: "Entegrator Profilleri", template_code: "integrator-profiles" },
    { label: "e-Belge", template_code: "e-documents" },
    { label: "e-Defter", template_code: "e-ledger" },
    { label: "Mali Takvim", template_code: "fiscal-calendar" },
    { label: "Rapor Snapshot", template_code: "report-snapshots" },
  ],
  reference_shell: {
    topbar_title: "Turkiye Muhasebe ve Finans Baslatma Merkezi",
    utility_tabs: [
      { label: "Ana Sayfa", route: "/" },
      { label: "Finans ve Buyuk Defter", route: "/modules/finance-gl" },
      { label: "Yeni Fis Penceresi", template_code: "voucher-new" },
    ],
    filter_actions: [
      { label: "Hesap Plani", template_code: "chart-of-accounts" },
      { label: "Yeni Fis", template_code: "voucher-new" },
      { label: "Fis Listesi", template_code: "voucher-list" },
      { label: "Mizan", template_code: "trial-balance" },
      { label: "Muavin", template_code: "subledger" },
      { label: "Buyuk Defter", template_code: "ledger" },
      { label: "Banka Mutabakati", template_code: "bank-reconciliation" },
      { label: "Musteri Cari", template_code: "customer-current-accounts" },
      { label: "Satici Cari", template_code: "vendor-current-accounts" },
      { label: "Parametreler", template_code: "parameters" },
      { label: "Entegrator Profilleri", template_code: "integrator-profiles" },
      { label: "Vergi Uyumu", template_code: "tax-compliance" },
      { label: "Donem Kapanis", template_code: "period-close" },
      { label: "e-Belge Merkezi", template_code: "e-documents" },
      { label: "e-Defter Merkezi", template_code: "e-ledger" },
      { label: "Mali Takvim", template_code: "fiscal-calendar" },
      { label: "Rapor Snapshot", template_code: "report-snapshots" },
    ],
    ribbon_actions: [
      { label: "Yeni Fis", template_code: "voucher-new" },
      { label: "Fisleri Ac", template_code: "voucher-list" },
      { label: "Mizan Ac", template_code: "trial-balance" },
      { label: "Buyuk Defter Ac", template_code: "ledger" },
      { label: "Musteri Cari", template_code: "customer-current-accounts" },
      { label: "Satici Cari", template_code: "vendor-current-accounts" },
      { label: "Parametreler", template_code: "parameters" },
      { label: "Entegrator", template_code: "integrator-profiles" },
      { label: "Vergi Uyumu", template_code: "tax-compliance" },
      { label: "e-Belge Ac", template_code: "e-documents" },
      { label: "e-Defter", template_code: "e-ledger" },
      { label: "Mali Takvim", template_code: "fiscal-calendar" },
      { label: "Snapshot", template_code: "report-snapshots" },
    ],
    status_badges: ["VUK / Tek Duzen", "GitHub source", "SQLite runtime"],
    action_message: "Tum kritik muhasebe ve finans akislari GitHub kaynakli pencere sozlesmesiyle ayri pencerelerde acilir.",
  },
  windows: [],
};

const DEFAULT_FINANCE_UI_REFERENCE_SHELL: FinanceUiReferenceShell = {
  topbar_title: "Turkiye Muhasebe ve Finans Baslatma Merkezi",
  utility_tabs: [
    { label: "Ana Sayfa", route: "/" },
    { label: "Finans ve Buyuk Defter", route: "/modules/finance-gl" },
    { label: "Yeni Fis Penceresi", template_code: "voucher-new" },
  ],
  filter_actions: [
    { label: "Hesap Plani", template_code: "chart-of-accounts" },
    { label: "Yeni Fis", template_code: "voucher-new" },
    { label: "Fis Listesi", template_code: "voucher-list" },
    { label: "Mizan", template_code: "trial-balance" },
    { label: "Muavin", template_code: "subledger" },
    { label: "Buyuk Defter", template_code: "ledger" },
    { label: "Banka Mutabakati", template_code: "bank-reconciliation" },
    { label: "Musteri Cari", template_code: "customer-current-accounts" },
    { label: "Satici Cari", template_code: "vendor-current-accounts" },
    { label: "Parametreler", template_code: "parameters" },
    { label: "Entegrator Profilleri", template_code: "integrator-profiles" },
    { label: "Vergi Uyumu", template_code: "tax-compliance" },
    { label: "Donem Kapanis", template_code: "period-close" },
    { label: "e-Belge Merkezi", template_code: "e-documents" },
    { label: "e-Defter Merkezi", template_code: "e-ledger" },
    { label: "Mali Takvim", template_code: "fiscal-calendar" },
    { label: "Rapor Snapshot", template_code: "report-snapshots" },
  ],
  ribbon_actions: [
    { label: "Yeni Fis", template_code: "voucher-new" },
    { label: "Fisleri Ac", template_code: "voucher-list" },
    { label: "Mizan Ac", template_code: "trial-balance" },
    { label: "Buyuk Defter Ac", template_code: "ledger" },
    { label: "Musteri Cari", template_code: "customer-current-accounts" },
    { label: "Satici Cari", template_code: "vendor-current-accounts" },
    { label: "Parametreler", template_code: "parameters" },
    { label: "Entegrator", template_code: "integrator-profiles" },
    { label: "Vergi Uyumu", template_code: "tax-compliance" },
    { label: "e-Belge Ac", template_code: "e-documents" },
    { label: "e-Defter", template_code: "e-ledger" },
    { label: "Mali Takvim", template_code: "fiscal-calendar" },
    { label: "Snapshot", template_code: "report-snapshots" },
  ],
  status_badges: ["VUK / Tek Duzen", "GitHub source", "SQLite runtime"],
  action_message: "Tum kritik muhasebe ve finans akislari GitHub kaynakli pencere sozlesmesiyle ayri pencerelerde acilir.",
};

export function resolveFinanceUiContract(contract?: FinanceUiContract | null): FinanceUiContract {
  return contract ?? DEFAULT_FINANCE_UI_CONTRACT;
}

export function getFinanceUiWindow(contract: FinanceUiContract | null | undefined, templateCode: string): FinanceUiWindow | null {
  return resolveFinanceUiContract(contract).windows.find((item) => item.template_code === templateCode) ?? null;
}

export function getFinanceUiTitle(
  contract: FinanceUiContract | null | undefined,
  templateCode: string,
  fallbackTitle: string,
  dynamicSuffix?: string,
): string {
  const windowMeta = getFinanceUiWindow(contract, templateCode);
  if (!windowMeta) {
    return dynamicSuffix ? `${fallbackTitle}${dynamicSuffix}` : fallbackTitle;
  }
  if (dynamicSuffix && windowMeta.title_prefix) {
    return `${windowMeta.title_prefix}${dynamicSuffix}`;
  }
  return windowMeta.title ?? fallbackTitle;
}

export function getFinanceUiSubtitle(
  contract: FinanceUiContract | null | undefined,
  templateCode: string,
  fallbackSubtitle: string,
): string {
  return getFinanceUiWindow(contract, templateCode)?.subtitle ?? fallbackSubtitle;
}

export function getFinanceUiSourceAction(
  contract: FinanceUiContract | null | undefined,
  templateCode: string,
  fallbackSourceAction: string,
): string {
  return getFinanceUiWindow(contract, templateCode)?.source_action ?? fallbackSourceAction;
}

export function getFinanceUiRules(
  contract: FinanceUiContract | null | undefined,
  templateCode: string,
  fallbackRules: string[] = [],
): string[] {
  const rules = getFinanceUiWindow(contract, templateCode)?.rules ?? [];
  return rules.length ? rules : fallbackRules;
}

export function getFinanceUiStatusBadges(
  contract: FinanceUiContract | null | undefined,
  templateCode: string,
): string[] {
  const resolved = resolveFinanceUiContract(contract);
  const local = getFinanceUiWindow(contract, templateCode)?.status_badges ?? [];
  return local.length ? local : resolved.status_badges;
}

export function getFinanceUiTabs(contract: FinanceUiContract | null | undefined, moduleSlug: string, sessionId?: string) {
  const suffix = sessionId ? `?sessionId=${sessionId}` : "";
  const base = `/windows/${moduleSlug}`;
  return resolveFinanceUiContract(contract).window_family_tabs.map((item) => ({
    label: item.label,
    href: `${base}/${item.template_code ?? "overview"}${suffix}`,
  }));
}

export function getFinanceUiPopupActions(contract: FinanceUiContract | null | undefined): FinanceUiAction[] {
  return resolveFinanceUiContract(contract).popup_actions;
}

export function getFinanceUiReferenceShell(
  contract: FinanceUiContract | null | undefined,
): FinanceUiReferenceShell {
  return resolveFinanceUiContract(contract).reference_shell ?? DEFAULT_FINANCE_UI_REFERENCE_SHELL;
}

export function getFinanceUiThemeStyle(contract: FinanceUiContract | null | undefined): CSSProperties {
  const tokens = resolveFinanceUiContract(contract).theme_tokens;
  const style: Record<string, string> = {};
  for (const [key, value] of Object.entries(tokens)) {
    style[`--finance-ui-${key.replaceAll("_", "-")}`] = value;
  }
  return style;
}
