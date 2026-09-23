# baseline/

Holds `prod-export.json`: a normalised export of the current production
realm, used by `.github/workflows/realm-dry-run.yml` as the starting point
for the dry-run diff.

Normally this is gitignored (see `.gitignore`) — an example repo shouldn't
ship production data, and a stale baseline defeats the point of the CI gate:
a config that already matches production stops looking like "no change" and
starts looking like the entire realm was just added, which buries the one
line a reviewer actually needs to see.

This repo commits one anyway, so the workflow here has something real to
diff against. It was generated the same way `scripts/export-normalised.sh`
generates any baseline (see below) — applying `realms/demo`'s config, as it
existed on `main`, to a throwaway Keycloak and exporting that. There's no
real production system behind this example, so treat the committed file as
illustrative, not as a literal production snapshot.

## Refreshing the baseline

Point the export script at whatever currently represents "production" and
capture its state:

```bash
export KEYCLOAK_URL=https://keycloak.internal   # or wherever prod lives
export KEYCLOAK_USER=<read-only admin service account>
export KEYCLOAK_PASSWORD=<...>
./scripts/export-normalised.sh demo > baseline/prod-export.json
```

`export-normalised.sh` calls the realm's `partial-export` endpoint and pipes
the result through `normalise.sh`, so the file it produces is already in the
same diffable shape the CI job compares against — no separate cleanup step,
and no risk of committing a raw export with the UUID/ordering noise the whole
pipeline exists to strip out.

Do this on a schedule, not by hand before each PR. A baseline that's gone
stale re-surfaces every legitimate change made since the last refresh as
"undeclared drift" on the next PR — exactly the false-positive noise the
dry-run gate exists to avoid. Wire up a scheduled workflow that runs the
export above and opens a PR against this file (or pushes directly, if your
branch protection allows it), using credentials scoped to read-only export —
this job never needs write access to production.
