#!/bin/bash
# scripts/normalise.sh — make an export diffable
jq '
  walk(if type == "object" then del(.id, .containerId) else . end)
  | .clients          |= sort_by(.clientId)
  | .roles.realm      |= sort_by(.name)
  | .clientScopes     |= sort_by(.name)
  | .authenticationFlows |= sort_by(.alias)
  | del(.components)
  | del(.keycloakVersion)
' "$1"
