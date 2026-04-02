"use client";

import { createContext, useContext, type ReactNode } from "react";

import type { FinanceUiContract } from "@/lib/api";
import { DEFAULT_FINANCE_UI_CONTRACT, getFinanceUiThemeStyle, resolveFinanceUiContract } from "./finance-ui-contract";

const FinanceUiContractContext = createContext<FinanceUiContract>(DEFAULT_FINANCE_UI_CONTRACT);

export function FinanceUiContractProvider({
  contract,
  children,
}: {
  contract?: FinanceUiContract | null;
  children: ReactNode;
}) {
  const resolved = resolveFinanceUiContract(contract);
  return (
    <FinanceUiContractContext.Provider value={resolved}>
      <div style={getFinanceUiThemeStyle(resolved)}>{children}</div>
    </FinanceUiContractContext.Provider>
  );
}

export function useFinanceUiContract() {
  return useContext(FinanceUiContractContext);
}
