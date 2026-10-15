# S25 Ultra: High versus Ultra sustained workload — 2026-10-15

## Conditions and method

The full High test reused the **exact APK** and protocol of the
[Ultra soak](android-quality-soak.md): one prepared forest, reviewed v16
Charizard/Dragonite, stationary camera, noon, frozen animation/wind, ordinary
Android frame pacing and a 60 FPS cap. There was one 30-second warm-up, then
forty measured 30-second windows with the same stage (`466943481189`) and no
model/arena reloads. Both real actors and both pooled passes remained active.

Device: Samsung SM-S938B / S25 Ultra, Adreno 830, Android API 37, Mobile/Vulkan,
ARM64 debug build `android-quality-d869ec4ab1e3`, game version 0.3.110.
Both profiles used **2340×1080 on both passes** with authored shadows. High
used **2× MSAA**, while Ultra used **4× MSAA**. This comparison changes the
quality fixture only; no runtime code or APK was changed or rebuilt.

The idle phone was allowed to cool before launching High: its battery sensor
fell from an initial 30.4 °C observation to a last preflight 27.5 °C, thermal
status 0. The first saved High health sample was **27.4 °C**, compared with
**26.6 °C** for Ultra (0.8 °C difference). Both started at thermal status 0,
with USB connected, AC power reported, full 100% battery/status 5 and power
saving off. High's last saved temperature was 38.7 °C versus Ultra's 38.3 °C.
These are battery sensor temperatures, not GPU/CPU die temperatures. Neither
room temperature, brightness nor background system load was controlled, and
this is one sequential run per profile, not a randomized replicated experiment.

The full High run completed **1,200.36 measured seconds** over **1,203.97
seconds wall time**. Instrumentation, upload and capture boundaries accounted
for 3.61 seconds outside frame statistics while the renderer remained active.
The timing/sampling limitations documented in the Ultra protocol also apply.

## Comparison

| Minutes | Ultra weighted FPS | High weighted FPS | High window frame p95 range, ms | High main GPU window p50 range, ms |
| --- | ---: | ---: | ---: | ---: |
| 0–5 | 59.10 | 59.97 | 17.00–17.14 | 13.10–14.85 |
| 5–10 | 51.24 | 50.43 | 17.31–33.55 | 14.87–19.47 |
| 10–15 | 45.56 | 45.49 | 33.43–33.48 | 19.46–19.47 |
| 15–20 | 45.17 | 45.46 | 33.44–33.54 | 19.46–19.47 |

FPS is frame-count weighted from actual serialized frame totals/durations.
Percentile columns are ranges of individual 30-second windows, not pooled or
averaged percentiles. Timings are engine-loop intervals/Godot GPU measurements,
not display presentation timestamps.

- High first window: **59.91 FPS**, frame p95 **17.07 ms**.
- High last window: **45.39 FPS**, frame p95 **33.46 ms**.
- High overall: **50.34 FPS** over 60,424 measured intervals; Ultra: **50.27 FPS**.
- High final five minutes: **45.46 FPS**; Ultra: **45.17 FPS**. This small
  difference does not establish a reliable sustained-FPS improvement.
- High had 11,716 intervals above the 25 ms budget tolerance, five above 50 ms,
  none above 100 ms; maximum 76.04 ms.
- High render allocation stayed at **632.00 MiB** versus Ultra **729.63 MiB**:
  **97.63 MiB / 13.4% less** in this scene. These are engine render allocations,
  not process RAM or measured energy savings.
- High PSS rose from **2,186.71 MiB** to a peak **2,195.57 MiB** early, then
  stayed around that level and ended at **2,193.90 MiB**. No ongoing memory
  increase was observed in this fixed retained workload.
- Both native and 122 host health samples peaked at thermal status **2
  (moderate)**. High, like Ultra, declined while the reported thermal state
  rose; no frequency trace establishes the exact cause.

**High did not sustain 60 FPS, and reducing MSAA alone did not demonstrate a
meaningful sustained-FPS improvement over Ultra in this comparison.** No
hardware-default or automatic preset recommendation was changed. The next
render-budget comparison would be Medium, which also lowers resolution, or
focused GPU profiling to identify which work remains expensive. Those were
not run as part of this High-only task. A subsequent
[warm High/Medium bracket](android-quality-warm-comparison.md) measured the
resolution reduction directly and found Medium promising in a short comparison.

## Verification and artifacts

The host accepted the complete forty-window High sequence with the expected
raster/MSAA, fresh run identity, unchanged stage instance, no repeated
preparation and forty actual USB-local uploads. No engine/check errors or
workload interruptions were recorded. After observation, actual HOME/resume
succeeded (2 pause and 2 resume notifications), and opt-out cleared pending
data and stopped processing. Start/end captures were visually inspected:
both actors, forest, framing and authored shadows remained present.

All forty unique High payloads satisfied the exact backend
`PerformanceReport`/`PerformanceBatch` schema and count contracts in batches of
eight in a network-disabled Python 3.13 container. This checks serialization;
no backend, account/session, database or authenticated ingestion was used.
Eighteen focused Python quality/GPU harness checks passed before the run.
No runtime source changes or additional build were needed.

Artifacts remain in this slot's ignored `.tmp/android-quality-phone/`:
`high-preflight-1/cooldown.jsonl` records cooldown samples;
`soak-high-run-1/` contains `report.json`, `details.json`, `telemetry.json`, a
derived `summary.json`, two arena PNGs and two settings PNGs. The existing
`soak-export-1/` contains the shared APK and build logs. Its SHA-256 remains
`0ec54fe7485912a26bd8630000682372987a895a417b64fea939e1ffd43c13ab`.
The High host ran clean commit `a222cc84860bcdeb88d8f69992dcb85783f7579e`;
the shared APK source was `d869ec4ab1e3`. The diagnostic reused only its own
verified cached art; there were no fixture GETs during the run.

The app was stopped, its owned USB reverse removed and all artifacts saved
before telling the user they could disconnect. The ordinary game and its
settings/data were untouched. No production collection, release certification,
promotion, publishing or deployment occurred.

## Device coverage

The user has no weaker physical phone. This does not block further work on
this renderer or comparisons of presets on the S25. A lower preset or an
emulator does not validate sustained behavior on weaker hardware. Low/Medium
hardware recommendations need later measurements from other physical devices,
for example willing testers or opt-in diagnostics after separately authorized
release/activation. No such production activation was performed here.
