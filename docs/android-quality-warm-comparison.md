# Warm High / Medium renderer comparison

## Protocol

`run_android_quality_benchmark.py --mode warm-compare` uses the existing separate
ARM64 debug APK/USB-only fixture boundary with real production Settings,
presenter, both forest passes, trusted v16 actors and native performance bridge.
No account, production gateway, backend database or live ingestion is involved.
The ordinary game package/data/settings are untouched.

High is first rendered for at most ten minutes. Every five seconds the test
records native thermal/PSS and a short engine FPS observation. It requires at
least thirty seconds of preheat, Android thermal status 2 or 3 and observed
High FPS at most 55 before proceeding. Missing thermal support, critical status
(4+) or failure to reach the condition within ten minutes stops the run. This
is a coarse observed precondition, not proof of a settled thermal equilibrium
or a measured hardware-frequency limit.

The comparison order is **High → Medium → Medium → High**, thirty measured
seconds per window (two minutes total). The first High window reuses the exact
preheated stage. Medium is prepared once and reused for both middle windows;
High is then prepared again. A preparation-driven three-second settle applies
after each profile switch. The final High reference brackets the Medium
windows to expose changes in device performance during the comparison.

The default 60 FPS cap, stationary camera, noon, frozen animation playback/wind,
forest and Charizard/Dragonite remain fixed. Actor pose at the moment of freeze
can differ after preparation; this is not an identical-frame image experiment.
On a 2340×1080 viewport, High uses 2340×1080 and Medium 1560×720, both 2× MSAA
with authored shadows. Medium therefore renders 44.4% as many pixels per pass.

Both pass rasters/MSAA and real actor/pool readiness are checked. Per-window
frame/GPU statistics use bounded arrays; production telemetry summaries use
actual measured intervals. Native queries, sorting, captures, report writes and
USB upload waits occur between windows, outside frame statistics. The renderer
continues drawing through boundaries. Host health sampling every ten seconds
can perturb timings. These are engine-loop/Godot GPU measurements, not display
presentation timestamps or release-game certification.

Native thermal status is recorded before and after every measured window.
Cooling after the initial warm condition is retained as evidence, not silently
rejected or described as a warm-state speedup. Compare both High references
and thermal/power conditions before attributing a change to resolution. One
bracket cannot establish statistical significance or twenty-minute stability.

Background/resume during preheat or measurement invalidates the observation.
Real HOME/resume and opt-out are tested afterwards. The host requires the exact
profile sequence, four complete windows, the actual stage handoffs, a warm
first High start and all four real USB-local uploads. Total host timeout is
twenty minutes; preheat itself is capped at ten. The runner stops its own app
and removes only its owned ADB reverse, preserving all results/cache.

## Running

Export `--suite android-quality --platform android --android-renderer mobile
--architecture arm64-v8a` using the existing exporter, installed Android SDK,
Godot 4.6.2 templates and explicit compatible JDK 17. From the assigned slot:

```sh
ops/worktrees/slot-env slot-a -- python3 .worktrees/slot-a/frontend/tools/run_android_quality_benchmark.py \
  --serial SERIAL --mode warm-compare \
  --apk .worktrees/slot-a/frontend/.tmp/android-quality-phone/warm-export-NEW/android-quality-benchmark.apk \
  --output .worktrees/slot-a/frontend/.tmp/android-quality-phone/warm-run-NEW
```

Use fresh export/run directories. Keep the unlocked diagnostic foregrounded
and connected. The [Ultra soak](android-quality-soak.md) and
[High comparison](android-quality-high-soak.md) document prior conditions and
limits. This test does not require a weaker phone; it cannot certify one.

## Physical result — 2026-10-15

Pending completion of the physical test.
