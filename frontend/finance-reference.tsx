"use client";

import { useRouter } from "next/navigation";

import type { RuntimeModuleSnapshot, FinanceWorkspace } from "@/lib/api";
import {
  getFinanceUiReferenceShell,
  getFinanceUiThemeStyle,
} from "./finance-ui-contract";
import { openModuleWindow } from "@/lib/window-actions";
import { useFinanceUiContract } from "./finance-ui-contract-provider";

import styles from "./finance-reference.module.css";

type Props = { snapshot: RuntimeModuleSnapshot; workspace: FinanceWorkspace };

function money(value: number, currency = "TRY") {
  return `${currency} ${value.toLocaleString("tr-TR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function dateLabel(value: string) {
  return new Intl.DateTimeFormat("tr-TR", { day: "2-digit", month: "2-digit", year: "numeric" }).format(new Date(value));
}

export function FinanceReference({ snapshot, workspace }: Props) {
  const router = useRouter();
  const uiContract = useFinanceUiContract();
  const referenceShell = getFinanceUiReferenceShell(uiContract);
  const themeStyle = getFinanceUiThemeStyle(uiContract);
  const totalBalance = workspace.chart_of_accounts.reduce((sum, account) => sum + account.current_balance, 0);

  function openFinanceWindow(templateCode: string, recordId?: string) {
    void openModuleWindow({
      moduleSlug: "finance-gl",
      templateCode,
      recordId,
      sourceRoute: "/modules/finance-gl",
      sourceAction: templateCode,
    });
  }

  return (
    <div className={styles.page} style={themeStyle}>
      <header className={styles.topBar}>
        <div className={styles.topLeft}>
          <span className={styles.menuButton}>III</span>
          <span className={styles.title}>{referenceShell.topbar_title}</span>
        </div>
        <div className={styles.topRight}>
          <span>{snapshot.companyContext ?? "TR-MERKEZ / Istanbul Merkez"}</span>
          <span>{snapshot.periodContext ?? "2026 / 2026-03"}</span>
          <span>{snapshot.runtimeStatus}</span>
          <span>{snapshot.financeExtensionVersion ? `ext ${snapshot.financeExtensionVersion}` : "host fallback"}</span>
        </div>
      </header>

      <div className={styles.utilityBar}>
        {referenceShell.utility_tabs.map((item, index) => {
          const isActive = item.route === "/modules/finance-gl" || (!item.route && item.template_code === "overview");
          return (
            <button
              key={`${item.label}-${index}`}
              type="button"
              className={isActive ? styles.utilityTabActive : styles.utilityTab}
              onClick={() => {
                if (item.route) {
                  router.push(item.route);
                  return;
                }
                if (item.template_code) {
                  openFinanceWindow(item.template_code);
                }
              }}
            >
              {item.label}
            </button>
          );
        })}
      </div>

      <div className={styles.workspace}>
        <aside className={styles.filterRail}>
          <div className={styles.filterHead}>Pencere Aksiyonlari</div>
          <div className={styles.currentFilters}>
            <div className={styles.sectionLabel}>Zorunlu Muhasebe Pencereleri</div>
            {referenceShell.filter_actions.map((item, index) => (
              <button
                key={`${item.label}-${index}`}
                type="button"
                className={styles.filterChip}
                onClick={() => item.template_code && openFinanceWindow(item.template_code)}
              >
                {item.label}
              </button>
            ))}
          </div>
        </aside>

        <section className={styles.mainArea}>
          <div className={styles.ribbon}>
            {referenceShell.ribbon_actions.map((item, index) => (
              <button
                key={`${item.label}-${index}`}
                type="button"
                className={styles.ribbonButton}
                onClick={() => item.template_code && openFinanceWindow(item.template_code)}
              >
                {item.label}
              </button>
            ))}
            {referenceShell.status_badges.map((badge) => (
              <div key={badge} className={styles.versionBadge}>{badge}</div>
            ))}
            <div className={styles.versionBadge}>
              {snapshot.financeExtensionStatus
                ? `SQLite ext ${snapshot.financeExtensionStatus}`
                : "SQLite host fallback"}
            </div>
          </div>

          <div className={styles.metricsRow}>
            <article className={styles.metricCard}>
              <div className={styles.metricLabel}>Hesap</div>
              <div className={styles.metricValue}>{workspace.chart_of_accounts.length}</div>
            </article>
            <article className={styles.metricCard}>
              <div className={styles.metricLabel}>Fis</div>
              <div className={styles.metricValue}>{workspace.journal_entries.length}</div>
            </article>
            <article className={styles.metricCard}>
              <div className={styles.metricLabel}>Mizan</div>
              <div className={styles.metricValue}>{workspace.trial_balance.length}</div>
            </article>
            <article className={styles.metricCard}>
              <div className={styles.metricLabel}>Toplam Bakiye</div>
              <div className={styles.metricValue}>{money(totalBalance)}</div>
            </article>
          </div>

          <div className={styles.actionMessage}>
            {referenceShell.action_message}
          </div>

          <div className={styles.gridRow}>
            <section className={styles.gridPanel}>
              <div className={styles.gridToolbar}>
                <span>Son Fisler</span>
                <strong>{workspace.journal_entries.length}</strong>
                <span>kayitli fis</span>
              </div>
              <table className={styles.table}>
                <thead>
                  <tr>
                    <th>FIS</th>
                    <th>TARIH</th>
                    <th>DURUM</th>
                    <th>PENCERE</th>
                  </tr>
                </thead>
                <tbody>
                  {workspace.journal_entries.slice(0, 10).map((item) => (
                    <tr key={item.id}>
                      <td>
                        <div className={styles.primaryCell}>{item.entry_number}</div>
                        <div className={styles.secondaryCell}>{item.description ?? "-"}</div>
                      </td>
                      <td>{dateLabel(item.entry_date)}</td>
                      <td>{item.status}</td>
                      <td>
                        <button type="button" className={styles.inlineAction} onClick={() => openFinanceWindow("voucher-detail", item.id)}>
                          Detay Penceresi
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </section>

            <section className={styles.gridPanel}>
              <div className={styles.gridToolbar}>
                <span>Hesap Plani</span>
                <strong>{workspace.chart_of_accounts.length}</strong>
                <span>aktif hesap</span>
              </div>
              <table className={styles.table}>
                <thead>
                  <tr>
                    <th>HESAP</th>
                    <th>TUR</th>
                    <th>BAKIYE</th>
                  </tr>
                </thead>
                <tbody>
                  {workspace.chart_of_accounts.slice(0, 10).map((item) => (
                    <tr key={item.id}>
                      <td>
                        <div className={styles.primaryCell}>{item.code}</div>
                        <div className={styles.secondaryCell}>{item.name}</div>
                      </td>
                      <td>{item.account_type}</td>
                      <td>{money(item.current_balance, item.currency)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </section>
          </div>

          <div className={styles.footerRow}>
            <section className={styles.footerPanel}>
              <div className={styles.footerTitle}>Calisma Durumu</div>
              <div className={styles.footerValue}>{snapshot.runtimeStatus}</div>
            </section>
            <section className={styles.footerPanel}>
              <div className={styles.footerTitle}>Mutabakat</div>
              <div className={styles.footerValue}>{snapshot.reconciliationStatus ?? "beklemede"}</div>
            </section>
            <section className={styles.footerPanel}>
              <div className={styles.footerTitle}>Dead Control</div>
              <div className={styles.footerValue}>{snapshot.deadControlCount ?? 0}</div>
            </section>
          </div>
        </section>
      </div>
    </div>
  );
}
