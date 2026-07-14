#!/bin/bash
set -e

KEYCLOAK_DIR="/opt/keycloak"
REALM_EXPORT="/opt/keycloak/data/import/realm-export.json"

echo "========================================="
echo " Starting Keycloak MFA Server"
echo "========================================="

# 環境変数のデフォルト設定
export KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
export KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin1234}"

echo "[INFO] Keycloak Admin User: ${KEYCLOAK_ADMIN}"
echo "[INFO] HTTP Port: 80"

# realm-export.jsonが存在する場合はインポートフラグを設定
IMPORT_ARGS=""
if [ -f "${REALM_EXPORT}" ]; then
    echo "[INFO] Found realm-export.json. Realm will be imported on startup."
    IMPORT_ARGS="--import-realm"
else
    echo "[WARN] realm-export.json not found at ${REALM_EXPORT}. Skipping realm import."
fi

echo "[INFO] Launching Keycloak in start-dev mode..."
echo "========================================="

exec "${KEYCLOAK_DIR}/bin/kc.sh" start-dev \
    --http-port=80 \
    --http-enabled=true \
    --hostname-strict=false \
    --hostname-strict-https=false \
    --log-level=INFO \
    ${IMPORT_ARGS}