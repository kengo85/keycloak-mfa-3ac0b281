#!/bin/bash
set -euo pipefail

MODE="${KC_MODE:-prod}"

echo "========================================="
echo " Keycloak MFA Identity Provider"
echo " Mode: ${MODE}"
echo "========================================="

if [ "${MODE}" = "dev" ]; then
  echo "[WARN] Dev mode: ephemeral in-memory DB, no hostname/TLS enforcement."
  echo "[WARN] Do NOT use this mode for anything reachable by real users."
  exec /opt/keycloak/bin/kc.sh start-dev --http-port="${KC_HTTP_PORT:-8080}" --import-realm
fi

required_vars="KC_HOSTNAME KC_DB_URL KC_DB_USERNAME KC_DB_PASSWORD KC_BOOTSTRAP_ADMIN_USERNAME KC_BOOTSTRAP_ADMIN_PASSWORD"
missing=""
for v in ${required_vars}; do
  if [ -z "${!v:-}" ]; then
    missing="${missing} ${v}"
  fi
done

if [ -n "${missing}" ]; then
  echo "[ERROR] Missing required environment variables for production mode:${missing}"
  echo "[ERROR] Set KC_MODE=dev for a local/ephemeral instance instead."
  exit 1
fi

echo "[INFO] Hostname : ${KC_HOSTNAME}"
echo "[INFO] Database : ${KC_DB_URL}"
echo "[INFO] Realm import: /opt/keycloak/data/import/realm-export.json"

exec /opt/keycloak/bin/kc.sh start --optimized --import-realm
