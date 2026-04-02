#!/usr/bin/env bash
set -euo pipefail

base="${BASE_URL:-http://127.0.0.1:8001}/api/v1"

post(){
  local path="$1"
  local body="$2"
  local code
  code=$(curl -sS -o /tmp/resp.json -w "%{http_code}" -X POST "$base$path" -H 'Content-Type: application/json' -d "$body")
  echo "POST $path -> $code"
  if [[ "$code" -ge 400 ]]; then
    cat /tmp/resp.json
    echo
    exit 1
  fi
}

get(){
  local path="$1"
  local code
  code=$(curl -sS -o /tmp/resp.json -w "%{http_code}" "$base$path")
  echo "GET $path -> $code"
  if [[ "$code" -ge 400 ]]; then
    cat /tmp/resp.json
    echo
    exit 1
  fi
}

get "/companies"
get "/accounts?company_id=1"
get "/current-accounts?company_id=1"
get "/vouchers?company_id=1&fiscal_year_id=1"

post "/reports/trial-balance" '{"company_id":1,"fiscal_year_id":1,"start_date":"2026-01-01","end_date":"2026-12-31"}'
post "/reports/journal" '{"company_id":1,"fiscal_year_id":1,"start_date":"2026-01-01","end_date":"2026-12-31"}'
post "/reports/general-ledger" '{"company_id":1,"fiscal_year_id":1,"start_date":"2026-01-01","end_date":"2026-12-31"}'
post "/reports/sub-ledger" '{"company_id":1,"fiscal_year_id":1,"start_date":"2026-01-01","end_date":"2026-12-31"}'
post "/reports/balance-sheet" '{"company_id":1,"fiscal_year_id":1,"as_of_date":"2026-12-31"}'
post "/reports/income-statement" '{"company_id":1,"fiscal_year_id":1,"start_date":"2026-01-01","end_date":"2026-12-31"}'
post "/reports/tax" '{"company_id":1,"period_from":"2026-01-01","period_to":"2026-12-31","threshold_tl":5000}'
post "/reports/aging" '{"company_id":1,"as_of_date":"2026-12-31"}'

echo "SQL Server smoke test tamamlandi."
