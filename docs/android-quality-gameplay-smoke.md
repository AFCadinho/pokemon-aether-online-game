# Medium animated Android renderer smoke

This extends the private `android-quality` APK/USB fixture with `--mode gameplay`.
It uses no game account or backend and touches only the slot's diagnostic app.
The ordinary game's preferences and Android defaults remain unchanged.

The bounded protocol reconstructs the production forest pool/presenter three
separate times with trusted v16 Charizard/Dragonite assets, Medium on both
passes, authored shadows and a 60 FPS cap. Unlike the fixed-scene soaks,
model playback is enabled at 1×. Noon, wind and camera remain fixed. Each cycle
runs Flamethrower, Thunderbolt, Rock Slide and Draco Meteor through the actual
`BattleAnimationRouter`, alternating actors, with real model-clock playback,
confirmed impacts, recovery and effect/audio cleanup. It then opens the actual
in-game settings menu and visits all eight tabs before closing it. These are
renderer exercises, not claims about those actors' legal battle movesets.

Each observation lasts at least 30 seconds and must complete the sequence in
less than 90 seconds. Overall intervals include menu/attack setup, local audio
loading and diagnostic bookkeeping; a nested series records each move's loop
intervals and both pass GPU samples. Individual boundaries have process-frame
precision. Native PSS queries, arena reconstruction and a three-second settling
period are outside these statistics. Initial preparation is therefore reported
separately rather than hidden in steady-state FPS. Driver/native caches from
prior diagnostic runs are retained: this is not a cold-install test.

A separate unmeasured effect pass saves actual impact images, keeping PNG
readback/encoding outside the performance windows. Real Android HOME/resume and
opt-out checks still run after measurement. The host rejects missing effects,
impacts, cleanup, menu tabs, finite samples or distinct arena instances. Slow but
finite timing results remain valid evidence, not a reason to discard a run.

Build with the normal private Android-quality exporter; run using a fresh output
folder and the assigned slot environment:

```sh
ops/worktrees/slot-env slot-a -- python3 -u .worktrees/slot-a/frontend/tools/run_android_quality_benchmark.py \
  --serial SERIAL --mode gameplay \
  --apk .worktrees/slot-a/frontend/.tmp/android-quality-phone/gameplay-export-1/android-quality-benchmark.apk \
  --output .worktrees/slot-a/frontend/.tmp/android-quality-phone/gameplay-run-1
```

Keep the phone unlocked with this diagnostic in the foreground. Keep polling
its terminal session during the run. Host evidence is checkpointed atomically.
This is an automated native smoke, not a full gameplay duration test: it does
not cover authenticated loading/profile hydration, real map travel, crowded
worlds, server-driven battles/PvP, touch ergonomics or all moves/devices.

## S25 Ultra result — 2026-10-15

The strengthened run (`gameplay-run-2`) completed all three reconstructed arenas,
twelve measured casts and 24 tab visits. Both passes retained **1560×720,
2× MSAA** and Medium. All moves produced visible geometry, reached their
model-clock impact, completed recovery and left no active effect/audio nodes.
The production audio path was used; speaker output was not audited.
All eight settings tabs were visible in each cycle, closing retained Medium,
and the process stayed foregrounded throughout measurement. Engine/check errors
were empty. This is a functional pass with **performance hitches still present**.

| Cycle | Measured seconds | Loop FPS | Frame p95, ms | Maximum interval, ms | Intervals >50 / >100 ms | Arena preparation, ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 30.005 | 57.26 | 17.49 | 235.73 | 12 / 4 | 5002 |
| 2 | 30.012 | 58.74 | 17.33 | 176.97 | 5 / 1 | 2566 |
| 3 | 30.003 | 58.73 | 17.22 | 185.56 | 4 / 1 | 2764 |

Across **90.020 measured seconds / 5,243 intervals**, weighted loop FPS was
**58.24**. There were 98 intervals above the 25 ms budget tolerance, 21 above
50 ms and six above 100 ms. A near-60 median/average must not conceal these
outliers. These are engine-loop intervals, not display presentation timestamps.
Arena reconstruction and its settling interval are not included in this table's
FPS; cached public art was already present. It is not an online loading benchmark.

| Move | First cycle frame p95 / max, ms | Third cycle frame p95 / max, ms |
| --- | ---: | ---: |
| Flamethrower | 33.82 / 158.37 | 17.46 / 37.77 |
| Thunderbolt | 17.47 / 26.35 | 17.38 / 33.16 |
| Rock Slide | 70.67 / 235.73 | 30.83 / 66.63 |
| Draco Meteor | 18.12 / 55.96 | 17.18 / 64.30 |

First-use Flamethrower and Rock Slide deserve focused profiling. Repeated Rock
Slide still exceeded the 60 FPS budget. The largest intervals in cycles 2 and 3
were outside the nested cast samples; menu construction/navigation and other
bookkeeping remain candidates, but the call site was not captured. A CPU/GPU
trace or explicit spans are needed before assigning those stalls to a cause.

The stage's pipeline counters (canvas, mesh, surface, draw) changed by
`[0,0,36,12]`, `[0,0,26,12]`, `[0,0,26,12]` during the observations. Main GPU
p50 was about **11.84 ms** and p95 about **13.2 ms** in all three cycles, with
peaks **77.43 / 39.31 / 41.27 ms**. Pipeline activity and the larger first-cast
stalls justify investigating setup/warm-up, but do not establish that compilation
alone caused them. No production renderer or warm-up behavior was changed.

Native PSS at the three boundaries was **1969.00 / 1969.78 / 1969.79 MiB**;
end-of-window engine render allocation stayed **533.39 MiB**. These separate
counters must not be added. Three cycles show no large increase at those sample
points, but cannot rule out a gameplay/loading leak or establish a memory tier.

Conditions: Samsung SM-S938B, Adreno 830, API 37, Mobile/Vulkan, ARM64 debug,
game 0.3.110. The first/final host samples reported battery **29.0→30.8 °C**,
100%, status 5/full, USB power true and AC power false. Native and host thermal
status remained **0**, with power saving off. This short run does not establish
sustained thermal behavior. Room temperature, brightness and background load
were not controlled. Both prior-run app caches and driver state were retained.

The separate evidence pass was visually inspected: flame stream/impact,
Thunderbolt, rocks and Draco Meteor were all present with the real actors and
forest. Impact images recorded elapsed times beyond `impact + 0.025` and
11–27 active pieces. Actual HOME/resume succeeded (2 pause/2 resume
notifications), and opt-out cleared pending data and stopped sampling. All
three uploaded summaries had unique IDs and satisfied the exact backend
`PerformanceReport` and `PerformanceBatch` classes in a network-disabled Python
3.13 container. This verifies serialization/schema and USB transport, not
account authentication or server ingestion/storage.

The earlier `gameplay-run-1` also completed its timings and exposed a 248.28 ms
Rock Slide interval. Manual image review found a diagnostic error: `hit` is a
configured option at creation, not a notification that impact has occurred.
Its screenshots were therefore pre-impact. The test now requires elapsed impact
and active geometry, and the host rejects missing/early/empty impact evidence.
The original run/artifacts remain unchanged; its `review.json` records this
limitation. Its timing data is retained separately, never combined with run 2.
The stronger run is the accepted visual/functional result. This was a test
harness correction, not a discovered missing-effect bug in the game.

Twenty-four focused Python quality/GPU harness checks passed, including rejection
of missing casts, inactive geometry, early captures, missed impacts, incomplete
cleanup, missing tabs and a retained instead of reconstructed arena. The actual
exported Android script parsed, both native APK builds completed, and the final
physical run passed the strengthened checks. Ordinary Android defaults and the
normal app's account/data/settings were untouched; no release certification,
production telemetry activation, publishing or deployment was performed.

Retained local evidence under `.tmp/android-quality-phone/` in this slot:
`gameplay-run-2/` contains `report.json`, `details.json`, `telemetry.json`, three
arena PNGs, two settings PNGs and four impact PNGs. `gameplay-export-2/` contains
the APK and build logs. APK and clean host source:
`58ff4173d874b5affaae61f7250edb8ee69278b8`; embedded build
`android-quality-58ff4173d874`; APK SHA-256
`3ca67410b06934931e381601346e9cb0d5ef174c8d2e448a9b75da62c9ab5bf5`.
The original `gameplay-run-1/` and `gameplay-export-1/` are retained separately.
The diagnostic app was stopped and its exact USB reverse removed after the run.

The next useful performance task is to profile and reduce the measured first-use
and menu/setup stalls, then repeat this same protocol before expanding to a
long authenticated gameplay session. The earlier fixed-scene Medium soak remains
valid for that narrower workload; this smoke adds evidence that steady rendering
and smooth action/transition delivery need separate acceptance criteria.

## Follow-up attribution

A [native hitch investigation](android-hitch-investigation.md) measured the
router load, menu construction/reopening and effect preparation separately.
The large new-menu and initial dynamic-router costs in this smoke are scene
setup costs that the fixture placed inside the action window. Production retains
the menu and creates its router during scene setup. Reused-menu opening still
had smaller above-budget intervals. Rock Slide preparation also remained costly
with all effect drawing suppressed; lowering raster resolution alone does not
remove that action-time work. See the follow-up for measured spans, the
visible/hidden control and the remaining attribution limits.
