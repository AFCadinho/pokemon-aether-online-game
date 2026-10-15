# S25 Ultra physical quality smoke — 2026-10-15

## Scope and isolation

A separate ARM64 debug APK (`com.pokeaether.androidquality.slot_a`) exercised
actual production Settings, the Mobile/Vulkan presenter, both forest pool passes,
current approved v16 Charizard/Dragonite art and the real Java performance bridge.
It used no game account. The ordinary game package and its data were untouched.
All diagnostic gateway, battle, model and environment URLs were redirected to a
USB-local fixture server. Host-downloaded public immutable art retained exact
size/hash pins and the production integrity path. This includes the actors’
reviewed Mega forms, which the real presenter also prepares.

The workload was two fixed combatants, forest, noon, stationary camera,
60 FPS cap and ordinary Android frame pacing. Each phase had 3 seconds of
warm-up and 15 seconds of measurement after production preparation completed.
Animation playback/wind were frozen after preparation; initial actor poses can
differ between phases. This is a renderer smoke, not identical-frame image
comparison, full gameplay, effects/HUD coverage or a sustained thermal test.

Device: Samsung SM-S938B (S25 Ultra), Adreno 830, Android API 37. Landscape
raster was **2340×1080**, so High and Ultra used the same pixel count with
different MSAA. A lower preset on this device does not simulate weaker hardware.
USB remained connected and the phone was charging; power saving was off.

## Results

Two orders were used: Ultra → High → Medium → Low → Ultra, then
Ultra → Low → Medium → High → Ultra. Repeating Ultra brackets each comparison;
it does not remove temperature, driver or operating-system noise.

| Order / phase | Preset | FPS | Frame p95 ms | Main GPU p50 ms | Render MiB (end) | PSS MiB |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Descending / 0 | ultra | 59.94 | 17.23 | 12.38 | 729.6 | 2194.1 |
| Descending / 1 | high | 60.10 | 17.20 | 13.08 | 632.0 | 2193.7 |
| Descending / 2 | medium | 60.11 | 17.28 | 11.80 | 532.8 | 2210.0 |
| Descending / 3 | low | 60.08 | 17.17 | 11.81 | 474.6 | 1965.2 |
| Descending / 4 | ultra | 59.38 | 17.23 | 13.46 | 729.6 | 2227.5 |
| Ascending / 0 | ultra | 55.81 | 33.11 | 12.40 | 729.6 | 2199.0 |
| Ascending / 1 | low | 60.07 | 17.13 | 11.83 | 474.6 | 2211.3 |
| Ascending / 2 | medium | 60.09 | 17.15 | 11.84 | 532.9 | 2225.9 |
| Ascending / 3 | high | 60.11 | 17.16 | 13.09 | 636.0 | 2226.1 |
| Ascending / 4 | ultra | 60.09 | 17.17 | 12.40 | 733.6 | 2232.3 |

Descending: battery sensor 29.2–31.7 °C, maximum Android thermal status 0. Ascending: battery sensor 31.8–33.7 °C, maximum Android thermal status 1.

Nine phases averaged 59.38–60.11 FPS with frame p95 around 17 ms. The first
Ultra phase of the second run averaged **55.81 FPS**, p95 **33.11 ms**,
with 68 frames above the 25 ms budget tolerance. Its GPU p50 was 12.40 ms and
reported thermal status was still 0; this run does not establish the cause.
The final Ultra phase returned to 60.09 FPS with native thermal status 1
(light). Both runs had zero measured frame intervals above 50 ms.

FPS in this table uses frame count / actual recorded interval duration from
the matched production telemetry. The original APK’s `details.json` FPS also
included the synchronous end-of-phase PSS query, lowering its displayed FPS by
about 0.1–0.2; those raw artifacts are preserved. The harness now ends that
clock before the PSS query; this reporting-only correction passed parse checks
and was not re-exported to the phone.

Lowering quality did not establish a consistent GPU-time win;
these measurements do not justify an automatic hardware recommendation.
The engine’s end-of-phase render allocation fell from 729.6 MiB at Ultra to
474.6 MiB at Low (about 35%). This is not a measured battery saving or a 35%
reduction in process memory. Low/Medium/High rasters were respectively
1170×540, 1560×720 and 2340×1080 on both passes.

## Functional evidence

- Both actual arena passes applied the expected aspect-preserving raster and
  MSAA; both actual actors were active in the pooled forest.
- Real native bridge returned API level, process PSS, power-saving mode and
  thermal status. GPU timestamps returned nonzero values.
- Actual Android Graphics and Support screens were captured and inspected:
  quality/FPS controls were readable, and diagnostics initially off. Arena
  captures showed both actors in every preset; Low removed authored shadows
  and had visibly coarser edges. This is inspection, not player visual approval.
- Each phase serialized through the production telemetry service and completed
  its real HTTP upload to the local transport fixture. The exact backend
  `PerformanceReport`/`PerformanceBatch` classes validated all ten physical
  payloads from both runs in a network-disabled Python 3.13 container.
  This does not certify authenticated ingestion: no account/session was used.
- Actual Android HOME/resume notifications discarded an interrupted measurement.
  Opt-out stopped processing and cleared pending data. No engine/check errors.
- Sixteen focused Python harness/GPU-result checks passed. The exported native
  test parsed, built with the real Java bridge and ran on the phone.

## Reproduction and artifacts

Run from the workspace using the assigned paired slot. A compatible local
JDK 17 and installed Godot 4.6.2 templates/Android SDK are required; pass the
JDK explicitly because the general exporter default JDK 26 is incompatible with
this Gradle Android build. Never copy another slot’s assets, caches or userdata.

```sh
ops/worktrees/slot-env slot-a -- python3 .worktrees/slot-a/frontend/tools/export_battle_entry_web_qa.py \
  --suite android-quality --platform android --android-renderer mobile --architecture arm64-v8a \
  --sdk /home/adinho/Android/Sdk --java /PATH/TO/JDK17 \
  --output .worktrees/slot-a/frontend/.tmp/android-quality-phone/export-NEW
ops/worktrees/slot-env slot-a -- python3 .worktrees/slot-a/frontend/tools/run_android_quality_benchmark.py \
  --serial SERIAL --phase-seconds 15 --order descending \
  --apk .worktrees/slot-a/frontend/.tmp/android-quality-phone/export-NEW/android-quality-benchmark.apk \
  --output .worktrees/slot-a/frontend/.tmp/android-quality-phone/run-NEW
```

Use a fresh output directory and keep the unlocked diagnostic foregrounded.
Repeat with `--order ascending` in another fresh directory. The runner verifies
the exact separate debug package/native bridge, records APK hash/provenance,
checks freshness/complete workload, captures only its own app files, owns one
ADB reverse, and stops only its own app afterwards. It retains its isolated app
and cache for repeat runs; it never clears or uninstalls the ordinary game.

Artifacts are retained locally under this slot’s ignored
`.tmp/android-quality-phone/`: `export-4/` contains the measured APK and logs;
`run-3/` is descending and `run-4/` ascending. Each run has `report.json`
(conditions, provenance, validity), `details.json` (timings/native results),
`telemetry.json` (actual serialized summaries) and seven PNG captures.
The measured APK embeds build `android-quality-f8971e555248`, SHA-256
`c5bc0c9b3434507849a972dc838533c0e9b5ad9be7ba34da00911c0a1a2ca410`.
The second run’s host was clean commit `5e4afff19`; the first host recorded its
pending fixture-only change explicitly. No APK source changed between the two measured runs.
The first two attempts stopped before measurement due to incomplete fixture
coverage; they are not performance evidence. No production issue was inferred
from those test setup failures.

## Remaining work

A subsequent [20-minute automated Ultra soak](android-quality-soak.md) found
a sustained FPS decline in the fixed forest scene. The short smoke above
should not be treated as sustained-performance approval.

Measure a weaker physical device with equivalent content, then real loading,
busy overworld, menus and effects with a 20-minute gameplay session. Test 30 FPS,
touch interaction, offline retries and authenticated staging ingestion before
release certification. Process PSS remained substantial: retained models, CPU
resources, driver allocations and debug overhead do not disappear just by
lowering render resolution. Render memory and PSS are different measures and
must not be added together.

No automatic preset assignment, production activation, deployment, release
certification or change to the ordinary game’s settings was performed.
