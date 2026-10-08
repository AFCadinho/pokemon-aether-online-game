# Browser file cleanup

Browser publication finishes after activation is confirmed. It does not wait
for removal of old R2 browser files.

`.github/workflows/cleanup-browser-r2.yml` runs every Sunday at 03:23 UTC from
the default branch. It can also be started with **Run workflow**. Manual runs
preview the deletion plan by default; enable **apply** to delete it.

The workflow reads the currently published browser manifest rather than an
old candidate artifact. The pruner also verifies the active browser page,
protects complete current releases and one previous release, leaves files
less than 24 hours old alone, and refuses plans over 20,000 deletions. Failures
leave the maintenance workflow red; publication has already finished.

It shares the `browser-release` concurrency group with browser uploads and
publication to prevent overlapping changes. A release started while cleanup
is running can therefore wait for maintenance to finish. Weekly scheduling
reduces these overlaps; the workflow can take up to 120 minutes. This change
does not alter the existing per-file deletion implementation.

The workflow uses the existing `web-production` environment and R2 secrets.
It becomes scheduled only after publication to the repository's default branch.
Environment approval rules, if configured, still apply. No server cron job,
new game build, or candidate artifact is needed for a cleanup run.
