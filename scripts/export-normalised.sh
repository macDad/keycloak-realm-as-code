#!/bin/bash
# scripts/export-normalised.sh — export a realm from a running Keycloak, normalised for diffing
set -euo pipefail

REALM="${1:-demo}"

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOKEN=$(curl -sf \
  -d "client_id=admin-cli" \
  -d "username=${KEYCLOAK_USER}" \
  -d "password=${KEYCLOAK_PASSWORD}" \
  -d "grant_type=password" \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  | jq -r '.access_token')

EXPORT_FILE=$(mktemp)
trap 'rm -f "${EXPORT_FILE}"' EXIT

curl -sf -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{}' \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/partial-export?exportClients=true&exportGroupsAndRoles=true" \
  > "${EXPORT_FILE}"

"${SCRIPT_DIR}/normalise.sh" "${EXPORT_FILE}"
