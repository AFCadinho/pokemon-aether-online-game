# Android quality soak

## Protocol

The isolated `android-quality` diagnostic supports `--mode soak`. It retains
one prepared production forest/presenter and the same two reviewed v16 actors
for forty measured 30-second windows (at least 1,200 seconds). The default is
Ultra at a 60 FPS cap, stationary camera, noon and frozen wind/animation playback.
There is one 30-second warm-up after preparation, then no arena/model reloads
between windows. This measures sustained behavior of this renderer workload;
it does not cover full gameplay, attacks, overworld, UI interaction or repeated
loading/release cycles. The retained model cache includes transformation art.

The APK/package, real native bridge, pinned art and USB-only fixture transport
are the same isolation boundary as the [short phone smoke](android-quality-phone-smoke.md).
There is no game account, authenticated server ingestion or production telemetry
activation. The normal game and its data/settings are not involved.

The player does not need to interact. Keep the unlocked diagnostic foregrounded
and the phone connected. Android pause/resume during the measured workload
invalidates the run. Critical thermal status (4 or above) stops the test; a
lower thermal status is evidence to report, not an automatic pass/fail target.
The host records charging state, battery sensor temperature, PSS, foreground
and thermal status about every ten seconds. These readings can perturb timing.
Native PSS/thermal samples are also taken at window boundaries, and render
counters are sampled once per second during each window.

Frame/GPU arrays are bounded to one window and reduced to p50/p95/max. Native
queries, sorting, report writes, USB uploads and the two captures occur between
windows and are excluded from frame statistics. The renderer remains active
through those boundaries; report both measured time and total wall time.
This instrumentation does not emulate the ordinary authenticated collector’s
five-second native-sampling cadence. Native PSS includes CPU/driver/debug/cache
allocations; do not add it to engine render memory or call it a memory leak
without further evidence.

The host accepts completion only with forty complete windows, the expected
profile/raster/MSAA, the same live stage instance throughout, no repeated
preparation, fresh run identity and all forty actual telemetry uploads. Actual
HOME/resume and opt-out checks run after the twenty-minute observation.
Unexpected interruptions, restarts, incomplete duration or engine/check errors
produce an unusable report. A wall-clock timeout bounds the run to 30 minutes.

## Running

Build the native suite with the existing exporter and a compatible JDK 17 as
described in the short phone smoke. Use a fresh output directory for each run:

```sh
ops/worktrees/slot-env slot-a -- python3 .worktrees/slot-a/frontend/tools/run_android_quality_benchmark.py \
  --serial SERIAL --mode soak --soak-preset ultra \
  --apk .worktrees/slot-a/frontend/.tmp/android-quality-phone/soak-export-NEW/android-quality-benchmark.apk \
  --output .worktrees/slot-a/frontend/.tmp/android-quality-phone/soak-run-NEW
```

Artifacts include the actual per-window telemetry, detailed timings, host health
samples, build/APK provenance, validation errors and start/end arena plus native
settings captures. The runner stops only its own diagnostic app and removes its
owned ADB reverse after completion. It retains the separate app/cache.

## S25 Ultra result — 2026-10-15

Result pending the complete physical run.
