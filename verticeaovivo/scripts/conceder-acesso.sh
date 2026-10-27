#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-DEFAULT}"
APP_NAME="${2:-minha-torre}"
CATALOG="${3:-lakehouse_vertice}"

echo "Buscando service_principal_client_id do app '${APP_NAME}' (profile: ${PROFILE})..."
SP_CLIENT_ID=$(databricks apps get "${APP_NAME}" --profile "${PROFILE}" -o json | python -c "import sys, json; print(json.load(sys.stdin)['service_principal_client_id'])")

if [[ -z "${SP_CLIENT_ID}" ]]; then
  echo "Erro: não foi possível obter service_principal_client_id para ${APP_NAME}." >&2
  exit 1
fi

echo "Service Principal Client ID: ${SP_CLIENT_ID}"
echo "Concedendo USE CATALOG em ${CATALOG} e USE SCHEMA + SELECT em ${CATALOG}.silver e ${CATALOG}.gold..."

databricks experimental aitools tools query --output json \
  "GRANT USE CATALOG ON CATALOG ${CATALOG} TO \`${SP_CLIENT_ID}\`" \
  "GRANT USE SCHEMA, SELECT ON SCHEMA ${CATALOG}.silver TO \`${SP_CLIENT_ID}\`" \
  "GRANT USE SCHEMA, SELECT ON SCHEMA ${CATALOG}.gold TO \`${SP_CLIENT_ID}\`" \
  --profile "${PROFILE}"

echo "Permissões concedidas com sucesso para ${SP_CLIENT_ID}!"

