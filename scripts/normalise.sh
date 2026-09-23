#!/bin/bash
# scripts/normalise.sh — make an export diffable
#
# Two structurally-identical realms can still produce non-identical exports:
# Keycloak returns roles, protocol mappers, and role composites in whatever
# order the DB query happened to return them, which varies per instance. So
# beyond stripping volatile IDs, every array of same-shaped entries is sorted
# by its natural key, and config-cli's own bookkeeping attributes (checksums,
# state trackers — meta about the reconciliation run, not the realm) are
# dropped. -S sorts object keys too, so map ordering never causes diff noise.
jq -S '
  walk(if type == "object" then del(.id, .containerId, .createdTimestamp) else . end)
  | walk(
      if type == "array" and length > 0 then
        if all(.[]; type == "object" and has("name")) then sort_by(.name)
        elif all(.[]; type == "object" and has("clientId")) then sort_by(.clientId)
        elif all(.[]; type == "string") then sort
        else .
        end
      else .
      end
    )
  | del(.components)
  | del(.keycloakVersion)
  | .attributes |= with_entries(select(.key | startswith("de.adorsys.keycloak.config.") | not))
' "$1"
