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

The physical run completed successfully. Preheat reached the required
condition after **337.84 seconds (5 min 38 s)**: High's latest short observation
was **50.79 FPS**, native thermal status **2 (moderate)**. There were 67 bounded
five-second observations; no workload/background interruption was recorded.

The measured bracket contained **120.03 seconds** over **133.10 seconds wall
time**, with profile switches/settling and instrumentation excluded from frame
statistics. Stage IDs confirmed that the initial High reused preheat, both
Medium windows shared one prepared stage, and the final High used a newly
prepared High stage. All real actor, pool, profile, both-pass raster and MSAA
checks passed. High was 2340×1080 and Medium 1560×720; both had 2× MSAA.

| Window | Profile | FPS | Frame p95 ms | Main GPU p50 / p95 ms | Render MiB | Thermal start → end |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| 0 | high | 51.64 | 33.38 | 17.22 / 17.30 | 632.02 | 2 → 2 |
| 1 | medium | 60.05 | 16.97 | 11.86 / 13.21 | 533.84 | 2 → 2 |
| 2 | medium | 59.83 | 16.99 | 11.86 / 13.19 | 533.84 | 2 → 2 |
| 3 | high | 55.63 | 33.28 | 14.84 / 19.46 | 633.00 | 2 → 2 |

Medium's actual frame-count-weighted average across its two windows was
**59.94 FPS**. The two High references were **51.64 and 55.63 FPS**, weighted
**53.63 FPS**. Medium had five intervals above the 25 ms tolerance and one above
50 ms (maximum 65.41 ms); High had 391 above 25 ms and none above 50 ms.
Neither had intervals above 100 ms. No blocking-pipeline counter increased
within any measured window; preparation/compilation was outside those samples.

Medium improved both observed frame pacing and main-pass GPU time in this
warm bracket, while retaining the same MSAA and authored shadows. Render
allocation was about 533.84 MiB instead of High's 632.02–633.00 MiB. Native
PSS fluctuated around 2.14–2.17 GiB during profile handoffs and must not be
added to render memory or interpreted as a leak from this short comparison.
Arena captures were visually inspected: both actors, forest and shadows were
present; Medium had the expected smaller render raster and coarser edges.

**Medium is a promising candidate, not a certified sustained 60 FPS setting.**
The final High GPU p50 (14.84 ms) was lower than initial High (17.22 ms), so
device performance changed within the bracket even though every boundary
reported thermal status 2. That coarse status does not establish identical
frequencies or die temperatures. Different frozen actor poses and unmeasured
background/system behavior also remain limitations. The improvement is an
observed result of this bracket; one short run cannot assign an exact causal
effect size or prove twenty-minute stability/full gameplay quality. No
quality default, automatic recommendation or production behavior was changed.

The next duration candidate is Medium under recorded comparable conditions;
it was not automatically extended into another twenty-minute run. Wider
physical-device coverage remains unavailable on the user's hardware.

### Device and power conditions

Samsung SM-S938B / S25 Ultra, Adreno 830, Android API 37, Mobile/Vulkan,
ARM64 debug build `android-quality-636bed02fa28`, game version 0.3.110.
Power saving was off. In contrast to the earlier full-battery AC-reported
soaks, Android reported **USB power and active charging, battery 99%** at
both saved endpoints. The host battery sensor went from 28.5 °C at startup to
36.4 °C after the bracket; native and 48 host health samples peaked at thermal
status 2. This trial is compared internally; its absolute values should not be
pooled with the earlier twenty-minute runs as identical power conditions.

### Verification and provenance

All four actual USB-local uploads completed with unique report IDs and the
exact High/Medium/Medium/High order. Actual Android HOME/resume afterwards
succeeded (2 pause and 2 resume notifications), and opt-out cleared pending
data and stopped processing. Engine/check errors were empty. The process was
stopped, its owned ADB reverse removed and artifacts saved before the user
was told they could disconnect.

The four Android payloads passed the exact backend `PerformanceReport` and
`PerformanceBatch` schema/count contracts in a network-disabled Python 3.13
container. No account/session, backend runtime, database or authenticated
server ingestion was used. Twenty-one focused Python harness/GPU checks
passed, including cold/unbounded/wrong-order/recreated-stage rejection and
retention of observed cooling. The updated GDScript parsed, built with the real
Java performance bridge and completed on the phone. No full certification,
release, deployment or production collection was performed.

Local artifacts are retained under this slot's ignored
`.tmp/android-quality-phone/`: `warm-export-1/` has the APK/build/parse logs;
`warm-run-1/` has `report.json`, `details.json` (including preheat samples),
`telemetry.json`, derived `summary.json`, four arena PNGs and two settings PNGs.
The APK SHA-256 is
`953b9614e5174a2f12b5eaae220a47506eed04d2bc8db4c8367e9b57d7b52b21`.
APK source was `636bed02fa28`; the host ran clean commit
`a41e20e027bf1f50bbfc44e7406877d5d4b5b3d0`. Since the earlier soak APK, the
only other game-content change in this branch's ancestry was the Pewter Museum
visual refresh, not the forest benchmark. Existing verified art in this
isolated app's own cache was reused; there were no fixture GETs during this run.
