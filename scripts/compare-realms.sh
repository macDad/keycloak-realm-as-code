#!/bin/bash
# scripts/compare-realms.sh — export two realms and diff them normalised
#
# Usage: compare-realms.sh <realm-a> <realm-b>
# Each realm is fetched from KEYCLOAK_URL by default; point at separate
# instances with KEYCLOAK_URL_A / KEYCLOAK_URL_B (e.g. staging vs prod).
set -euo pipefail

REALM_A="${1:?Usage: compare-realms.sh <realm-a> <realm-b>}"
REALM_B="${2:?Usage: compare-realms.sh <realm-a> <realm-b>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

EXPORT_A=$(mktemp)
EXPORT_B=$(mktemp)
trap 'rm -f "${EXPORT_A}" "${EXPORT_B}"' EXIT

KEYCLOAK_URL="${KEYCLOAK_URL_A:-${KEYCLOAK_URL:-http://localhost:8080}}" \
  "${SCRIPT_DIR}/export-normalised.sh" "${REALM_A}" > "${EXPORT_A}"

KEYCLOAK_URL="${KEYCLOAK_URL_B:-${KEYCLOAK_URL:-http://localhost:8080}}" \
  "${SCRIPT_DIR}/export-normalised.sh" "${REALM_B}" > "${EXPORT_B}"

diff -u "${EXPORT_A}" "${EXPORT_B}"
