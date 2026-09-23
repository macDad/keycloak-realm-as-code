#!/bin/bash
# scripts/apply.sh — apply a realm config file or directory to a running Keycloak
set -euo pipefail

SOURCE="${1:?Usage: apply.sh <path-to-realm-config-file-or-dir>}"
case "${SOURCE}" in
  /*) ;;
  *) SOURCE="$(pwd)/${SOURCE}" ;;
esac

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"
CONFIG_CLI_IMAGE="${CONFIG_CLI_IMAGE:-adorsys/keycloak-config-cli:6.5.1-26.5.5}"

if [ -d "${SOURCE}" ]; then
  LOCATION="/config/target/*"
else
  LOCATION="/config/target"
fi

# Forward realm substitution variables ($(env:NAME) in the YAML/JSON), if set.
SUBSTITUTION_ENV=()
[ -n "${APP_BASE_URL:-}" ] && SUBSTITUTION_ENV+=(-e "APP_BASE_URL=${APP_BASE_URL}")
[ -n "${BACKEND_CLIENT_SECRET:-}" ] && SUBSTITUTION_ENV+=(-e "BACKEND_CLIENT_SECRET=${BACKEND_CLIENT_SECRET}")

docker run --rm --network host \
  -v "${SOURCE}:/config/target" \
  -e KEYCLOAK_URL="${KEYCLOAK_URL}" \
  -e KEYCLOAK_USER="${KEYCLOAK_USER}" \
  -e KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD}" \
  -e KEYCLOAK_AVAILABILITYCHECK_ENABLED=true \
  -e KEYCLOAK_AVAILABILITYCHECK_TIMEOUT=120s \
  -e IMPORT_FILES_LOCATIONS="${LOCATION}" \
  -e IMPORT_VARSUBSTITUTION_ENABLED=true \
  "${SUBSTITUTION_ENV[@]+"${SUBSTITUTION_ENV[@]}"}" \
  "${CONFIG_CLI_IMAGE}"
