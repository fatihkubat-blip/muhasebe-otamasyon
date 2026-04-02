#!/usr/bin/env bash
set -euo pipefail

if [[ -f .env.sqlserver ]]; then
  set -a
  source .env.sqlserver
  set +a
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL bulunamadi. .env.sqlserver olusturun veya env var tanimlayin."
  exit 1
fi

if [[ "${DATABASE_URL}" != mssql+* ]]; then
  echo "Bu script sadece SQL Server icindir. DATABASE_URL mssql+ ile baslamali."
  exit 1
fi

exec uvicorn app.main:app --host 127.0.0.1 --port 8001
