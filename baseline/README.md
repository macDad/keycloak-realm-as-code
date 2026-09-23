# baseline/

Holds `prod-export.json`: a normalised export of the current production realm,
used by `.github/workflows/realm-dry-run.yml` as the starting point for the
dry-run diff.

It's refreshed on a schedule (see the article's "Proving two realms match"
section) by a job with production credentials — not written by hand, and not
generated from this repo's own `realms/demo` config. It's gitignored here so
this example repo doesn't ship stale or fake production data; wire up your
own scheduled export job to populate it.
