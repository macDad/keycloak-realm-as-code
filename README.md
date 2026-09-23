# Keycloak Realm as Code

![Keycloak](https://img.shields.io/badge/Keycloak-26.5.5-4D96D9?style=flat-square&logo=keycloak&logoColor=white) ![config--cli](https://img.shields.io/badge/keycloak--config--cli-6.5.1-4D96D9?style=flat-square) ![CI](https://img.shields.io/badge/CI-GitHub%20Actions-1B2838?style=flat-square&logo=githubactions&logoColor=white) ![License](https://img.shields.io/badge/license-MIT-C9D2DB?style=flat-square)

Keycloak realm configuration as code — environment overlays, secret substitution, a CI dry-run gate, and normalised realm diffing.

## What this is

Realm settings, clients, and roles as minimal, reviewable YAML, applied idempotently by [keycloak-config-cli](https://github.com/adorsys/keycloak-config-cli) instead of clicked through the admin console. One config, three environments — values are substituted at apply time, not copy-pasted into per-environment files — and every pull request runs through a CI job that applies the change to a throwaway Keycloak seeded from a production baseline and surfaces exactly what would change.

Companion repo for [the article](ARTICLE_URL_PLACEHOLDER); the article has the reasoning, this README is the reference.

## Quick start

1. Clone the repo:

   ```bash
   git clone https://github.com/macDad/keycloak-realm-as-code.git
   cd keycloak-realm-as-code
   ```

2. Start Keycloak and apply the realm:

   ```bash
   docker compose up -d
   ```

   > [!NOTE]
   > The `config` job waits on `KEYCLOAK_AVAILABILITYCHECK_ENABLED` before it imports anything — without it, the job would race Keycloak's startup and fail on a cold `docker compose up`. Check its logs with `docker compose logs config`; it should exit 0.

3. Apply it again, against the same running Keycloak, and confirm nothing changes:

   ```bash
   docker compose run --rm config
   ```

   That's idempotency — the property that makes it safe to run this on every deploy, not just the first time.

4. Optional: look at what it created. Open `http://localhost:8080`, sign in with `admin` / `admin`, switch to the **demo** realm, and check **Clients** for `demo-web` and `backend-service`, and **Realm roles** for `dispatcher` and `viewer`.

## Project structure

```text
realms/demo/
├── realm.yaml              # realm-level settings only — no UUIDs, no computed defaults
├── clients.yaml             # OIDC clients
└── roles.yaml                # realm roles

env/
├── dev.env                  # committed, throwaway values — loaded by docker-compose.yml
├── staging.env.example        # copy to staging.env locally; that copy is gitignored
└── prod.env.example            # copy to prod.env locally, or inject at deploy time; gitignored

scripts/
├── normalise.sh              # jq: strip UUID/order/key noise from a raw export
├── apply.sh                   # apply a realm config file or directory to a running Keycloak
├── export-normalised.sh        # export a realm and normalise it, for diffing
└── compare-realms.sh            # export two realms and diff them normalised

.github/workflows/
└── realm-dry-run.yml        # CI gate: diff a PR's config against a prod baseline

hooks/
└── pre-commit                # rejects a hardcoded secret staged under realms/

baseline/
└── README.md                 # what prod-export.json is and how it's refreshed

docker-compose.yml            # Keycloak + a one-shot config-cli job
```

> [!NOTE]
> Every file under `realms/demo/` carries its own top-level `realm: demo` key, including `clients.yaml` and `roles.yaml`. config-cli reconciles each imported file independently against the realm named inside it — omit the key and it can't resolve which realm the file targets.

## Environment overlays

Never copy `realm.yaml` per environment — substitute values instead, with `$(env:NAME)`:

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

`env/dev.env` is committed with throwaway values for local use. `env/staging.env.example` and `env/prod.env.example` are templates only — copy one to `env/staging.env` or `env/prod.env` for local use (both gitignored), or in CI and production, inject the values from the runner's secret store or your platform's secret mechanism instead of a checked-out file.

## Secrets

Client secrets are never committed — always `$(env:NAME)`:

```yaml
clients:
  - clientId: backend-service
    secret: "$(env:BACKEND_CLIENT_SECRET)"
```

A pre-commit hook catches a mistake before it reaches review:

```bash
ln -s ../../hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

> [!WARNING]
> If a secret does reach git, rotate it in Keycloak — don't rewrite history. History rewrites don't reach clones, forks, CI caches, or anyone's existing checkout; a rotated secret closes the exposure everywhere at once.

## The CI dry-run gate

`.github/workflows/realm-dry-run.yml` runs on every pull request: it starts a throwaway Keycloak, loads `baseline/prod-export.json` with `scripts/apply.sh`, snapshots it with `scripts/export-normalised.sh`, applies the PR's `realms/demo` config on top, snapshots again, and diffs the two. Any change the PR didn't declare shows up in the job log — a realm-terms diff, not a YAML-terms one, which is a different and more useful artifact than the file diff GitHub already shows.

`baseline/prod-export.json` is gitignored by default — it's written by a separate scheduled job with production credentials, refreshed regularly rather than checked in by hand. See [baseline/README.md](baseline/README.md) for what generates it and how to refresh it yourself. Wire that job up before this workflow can run in a fork.

This repo's own committed baseline predates the `passwordPolicy` hardening above (it was captured while the minimum length was still `12`) — so any pull request against the current `realms/demo` config reproduces the gate's actual payoff: the job diff comes back showing that one line changed, not the whole realm.

## Realm comparison

```bash
./scripts/compare-realms.sh staging prod
```

`staging` and `prod` here are realm names in your own environments, not something the quick-start stack above creates — this compares two already-deployed realms, typically on two different Keycloak instances.

Raw exports never match, even between genuinely identical realms — fresh UUIDs, arbitrary array order, rotating keys. `scripts/normalise.sh` strips that before diffing, so empty output means the realms actually match, and non-empty output is a real difference to either intend or fix.

> [!NOTE]
> Point each side at its own instance with `KEYCLOAK_URL_A` / `KEYCLOAK_URL_B`, or leave them unset to compare two realms on the same `KEYCLOAK_URL`. Run this on a schedule, not just on demand — the value is catching a console change within a day, not confirming things were fine when you happened to check.

## Migrating an existing realm

config-cli's `NORMALIZE` operation turns a full realm export into minimal YAML by stripping anything matching Keycloak's defaults:

```bash
docker run --rm -v "$PWD:/data" \
  adorsys/keycloak-config-cli:6.5.1-26.5.5 \
  --run.operation=NORMALIZE \
  --normalization.files.input-locations=/data/prod-export.json \
  --normalization.files.output-directory=/data/out
```

It skips `components` (LDAP federation, key providers — handle those by hand) and never includes users; that's correct, user data doesn't belong in realm config.

The safe sequence:

1. Export production, normalise it, commit the result
2. Apply it to an empty throwaway realm
3. Export that, normalise both, diff
4. Fix what's missing, repeat until the diff is empty
5. Only then point the pipeline at a real environment

> [!WARNING]
> Don't run config-cli against production until step 4 gives you an empty diff. config-cli reconciles toward your file — anything you failed to capture is something it may remove.

## Version compatibility

| keycloak-config-cli | Keycloak | Used here |
|---|---|---|
| `6.5.1-26.5.5` | `26.5.5` | Yes |
| `6.5.1-26.1.0` | `26.1.0` | — |
| `6.5.1-26.0.5` | `26.0.5` | — |

> [!WARNING]
> config-cli's Docker tags pair its own version with a specific Keycloak version (`<config-cli-version>-<keycloak-version>`), and it lags the latest Keycloak release by design — at the time of writing, Keycloak's latest is `26.7.4` but config-cli's newest published pairing is `6.5.1-26.5.5`. Pin the tag to the Keycloak version you actually run, and re-check both before bumping either; don't use `latest`.

## Contributing

Issues and PRs are welcome.
Keep `realms/demo` minimal — only settings that deviate from Keycloak's defaults belong there.
Run `docker compose up -d` followed by `docker compose run --rm config` before opening a PR, and confirm the second run reports no changes.

## License

MIT — see [LICENSE](LICENSE).
