# Desktop update download investigation — 2026-10-04

## Observations

- A September 30 launcher log recorded 16.96 MB/s for a 56.67 MB
  launcher archive. On October 4 the 243.07 MB game archive took 84.6 seconds
  (2.87 MB/s), and the 69.70 MB music archive took 22.9 seconds (3.05 MB/s).
  These are different archives and dates, not a controlled before/after test.
- The October 4 launcher used all four bounded range connections without
  retries, stalls, or a fallback to a single connection.
- The downloader service has no source changes between v0.3.88 and v0.3.92.
- Direct measurements outside Godot returned approximately 2.02 MB/s for an
  8 MiB game sample, 2.63 MB/s for an 8 MiB launcher sample, and 2.74 MB/s
  for an 8 MiB Cloudflare speed endpoint sample. Both R2 samples were cache
  hits at the Amsterdam edge, with about 0.12 seconds to response headers.
- Four concurrent 4 MiB R2 ranges together reached 1.99 MB/s. An 8 MiB
  sample from Python.org, a separate provider, reached 1.97 MB/s.
- Background Wi-Fi traffic during a three-second idle sample was only
  0.02 MB/s received and negligible transmitted traffic. No application
  proxy or active Tailscale exit node was found. The connection is Wi-Fi;
  reported receive PHY rate was 351 Mbit/s. PHY rate is not usable internet
  throughput and does not rule out Wi-Fi trouble.

## Conclusion and next diagnostic step

The observed slowdown also occurs outside the launcher and on another
provider. It cannot be attributed specifically to the launcher or R2 from
these measurements. A comparison on Ethernet and then another connection
is needed to separate Wi-Fi, router/ISP, and other machine/network limits.
No network settings were changed and no production downloader limits were
changed. The measurements do not identify the exact network bottleneck.

## Confirmed launcher defect and fix

Version metadata was saved only after the entire update queue succeeded.
When the v8 catalog was rejected after the game and music had installed,
the installed version on disk remained 0.3.88. Restarting then queued the
same game and music archives again.

The launcher now saves the version metadata after each successful verified
staging transaction. Failed transactions are not marked installed. The
regression check exercises transaction success, a later failure, process
recreation, unfinished component downloads, completed component skipping,
and repair of missing installed files.

This code fix needs a future launcher release; it is separate from the
already published v8 manifest correction for launcher 0.3.92.

Focused validation: `update_checkpoint_check.gd` reproduced the restart
defect before the change and passed afterward; `localization_check.gd`
also passed, including the existing staged installation/rollback checks.
The checkpoint regression check now runs in the desktop release workflow.
