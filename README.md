# keycloak-realm-as-code

Keycloak realm configuration as code with [keycloak-config-cli](https://github.com/adorsys/keycloak-config-cli) —
environment overlays, secret substitution, a CI dry-run gate, and normalised
realm diffing.

Companion repo to the blog post *Keycloak Realm Configuration as Code: Stop
Clicking in the Admin Console*.

## Layout

```text
realms/
  demo/
    realm.yaml          # the realm itself
    clients.yaml         # OIDC clients
    roles.yaml            # realm and client roles
env/
  dev.env                # committed, throwaway values
  staging.env.example     # copy to staging.env locally, never commit it
  prod.env.example        # copy to prod.env locally, never commit it
docker-compose.yml         # Keycloak + a one-shot config-cli job
scripts/
  normalise.sh             # strip UUID/order/key noise from an export
  apply.sh                 # apply a realm config file or directory to a running Keycloak
  export-normalised.sh     # export a realm and normalise it, for diffing
  compare-realms.sh        # export two realms and diff them normalised
.github/workflows/
  realm-dry-run.yml        # CI gate: diff PR config against a prod baseline
hooks/
  pre-commit                # rejects hardcoded secrets in realms/
baseline/
  README.md                 # what prod-export.json is and how it's refreshed
```

Only settings that deviate from Keycloak's defaults belong in `realms/`.
Every default you copy in from an export is a value you now own forever,
including through upgrades where Keycloak changes that default for good
reason.

## Run it locally

```bash
docker compose up
```

Keycloak starts, then the `config` job waits for it to become available and
applies `realms/demo/*` using `env/dev.env`. Run it again — the second run
should report no changes. That idempotency is what makes it safe to run on
every deploy.

## Environments

Never copy `realm.yaml` per environment — substitute values instead, using
`$(env:NAME)`:

```yaml
redirectUris:
  - "$(env:APP_BASE_URL)/*"
```

| Legitimately per-environment | Must be identical everywhere |
|---|---|
| Hostnames, redirect URIs, web origins | Authentication flows |
| External IdP endpoints and client IDs | Roles and role composition |
| SMTP settings | Password policy |
| Log level, debug flags | Required actions |
| Rate limits and brute-force thresholds | Client scopes and protocol mappers |

`env/staging.env.example` and `env/prod.env.example` are templates only. Copy
one to `env/staging.env` / `env/prod.env` for local use — both are
gitignored. In CI, values come from the runner's secret store; in
production, from Vault, AWS Secrets Manager, or your platform's secret
mechanism, fetched at runtime.

## Secrets

Client secrets are never committed — always `$(env:NAME)`. A pre-commit hook
guards against mistakes:

```bash
ln -s ../../hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

If a secret does reach git, the fix is rotating it in Keycloak — not
rewriting history. History rewrites don't reach clones, forks, CI caches, or
anyone's checkout.

## CI dry-run gate

`.github/workflows/realm-dry-run.yml` runs on every pull request: it loads
`baseline/prod-export.json` into a throwaway Keycloak, snapshots it, applies
the PR's config on top, snapshots again, and diffs. Any undeclared change
shows up in the CI log. See `baseline/README.md` for what populates the
baseline.

## Proving two realms match

```bash
./scripts/compare-realms.sh staging prod
```

Raw exports never match — fresh UUIDs, arbitrary array order, rotating keys.
`scripts/normalise.sh` strips that noise before diffing, so empty output
means the realms genuinely match, and non-empty output is a real difference
to either intend or fix. Run this on a schedule, not just on demand — the
value is catching a console change within a day, not confirming things were
fine when you happened to check.

## Migrating an existing realm

config-cli's `NORMALIZE` operation turns a full realm export into minimal
YAML by stripping anything matching Keycloak's defaults. It skips
`components` (LDAP federation, key providers — handle those by hand) and
never includes users. The safe sequence: export production, normalise,
apply to an empty throwaway realm, normalise *that* export, diff against the
first, fix what's missing, repeat until the diff is empty — only then point
the pipeline at a real environment.

## Versions

Keycloak `26.5.5` and `keycloak-config-cli` `6.5.1-26.5.5`. config-cli ships
Docker tags as `<config-cli-version>-<keycloak-version>` and lags the latest
Keycloak release by design — pin the tag to the Keycloak version you
actually run, and re-check both before bumping either.
