# S25 Ultra Medium sustained test — 2026-10-15

## Complete run

The full, independent Medium rerun completed forty valid 30-second windows:
**1,200.31 measured seconds** over **1,204.01 seconds wall time**. Its weighted
engine-loop FPS was **60.03**, including **60.03 FPS in the final five minutes**.
Medium sustained approximately the selected 60 FPS target in this fixed forest
workload under the recorded conditions. It did not show the decline observed
in the earlier [High](android-quality-high-soak.md) and
[Ultra](android-quality-soak.md) runs. These are observations under differing
starting/power conditions, not replicated causal comparisons.

The test retained one prepared production forest/presenter, both active v16
Charizard/Dragonite actors and both pool passes throughout. Stage instance
`466943481189` and the Android process remained unchanged; there was no repeated
preparation or workload/background interruption. Medium was **1560×720 with
2× MSAA on both passes**, authored shadows, a 60 FPS cap, fixed camera/noon
and frozen animation playback/wind. The renderer remained active between
windows; 3.70 seconds of native queries, sorting, writes/uploads/captures were
outside frame statistics. Preparation and one 30-second warm-up were excluded.

| Measured minutes | Weighted FPS | Window frame p95 range, ms | Main GPU window p50 range, ms | PSS range, MiB | Peak native thermal |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0–5 | 60.02 | 16.97–17.09 | 11.81–11.89 | 1942.91–1945.98 | 0 |
| 5–10 | 60.02 | 16.99–17.10 | 11.81–11.83 | 1945.96–1946.10 | 0 |
| 10–15 | 60.03 | 16.95–17.11 | 11.82–11.85 | 1946.08–1946.45 | 0 |
| 15–20 | 60.03 | 16.93–17.05 | 11.83–14.26 | 1946.48–1946.54 | 0 |

FPS is weighted by actual serialized frame counts and durations. The percentile
columns are ranges of 30-second window statistics, not pooled or averaged
percentiles. These are engine-loop intervals and Godot GPU measurements, not
display presentation timestamps. Host health queries can perturb timing.

The first and last windows both averaged **60.03 FPS**; their frame p95 values
were **17.02 and 17.00 ms**. Across 72,051 intervals, 70 exceeded the 25 ms
budget tolerance, two exceeded 50 ms and none exceeded 100 ms. The maximum was
60.24 ms. The run therefore does not claim perfectly hitch-free delivery.

Native PSS rose from **1,942.91 to 1,946.53 MiB** (about 3.63 MiB / 0.2%), with
a small early increase and minor later variation, rather than growing materially
throughout the run. Engine render allocation stayed at **532.84 MiB**.
These are separate counters and must not be added. This retained scene cannot
rule out leaks during repeated loading, scene changes or full gameplay.

## Conditions and limits

Samsung SM-S938B / S25 Ultra, Adreno 830, Android API 37, Mobile/Vulkan,
ARM64 debug APK `android-quality-636bed02fa28`, game version 0.3.110. This is
the same APK used for the [warm High/Medium bracket](android-quality-warm-comparison.md).
No Android runtime/preset implementation changed for this duration test.

At the complete rerun's first saved host sample, the battery sensor was
**31.9 °C**, full 100% battery/status 5, USB power true and AC power false.
Power saving was off. The final saved host temperature was **35.4 °C**.
All native boundary samples and 122 host health samples reported thermal status
**0**. That is a coarse reported status, not a die-temperature/frequency trace
or proof of no throttling. GPU timing varied while FPS remained near the cap.

This started warmer than the earlier High/Ultra soaks and used USB-reported
power rather than AC-reported power. Room temperature, screen brightness,
background load and frequency state were not controlled. No exact causal FPS,
thermal or energy-saving percentage is inferred between those separate runs.
The earlier within-run warm bracket provides additional resolution evidence.

**Medium is now supported as a sustained-performance candidate for this scene
on this S25, not a final default for all Android devices or all gameplay.**
A subsequent [animated renderer/menu/reconstruction smoke](android-quality-gameplay-smoke.md)
completed its functional checks but found short attack/setup hitches. Busy
overworld, authenticated loading and battles, longer animated sessions,
release-build behavior and user visual preference remain to be checked. No weaker physical device is available. Neither the game's default
nor automatic quality assignment was changed.

## Interrupted first attempt and host improvement

The first attempt (`soak-medium-run-1`) stopped at twenty windows/about ten
minutes because the local host process terminated with exit code **143
(TERM)**. The USB fixture server disappeared, and the client correctly failed
its upload-completion check. Its engine FPS had remained near 60 up to that
point. This was not accepted as a twenty-minute run, and its intervals were
**not stitched into the complete rerun**. The source of the TERM signal was
not established; no Android crash or performance failure is inferred from it.

Own diagnostic files and PID-scoped logs were recovered before stopping that
app and removing its exact USB reverse. The server's in-memory upload history
and original host health history were unavailable, which is recorded explicitly
in `recovery.json`. The recovered original files are retained, including
`android-quality-details.json`, fixture/phase/result JSON and the first capture.

The host runner now atomically checkpoints report/details/upload evidence at
startup and each health sample. Partial reports remain `usable: false` and
`running: true`; completion clears `running` only after checks/cleanup. TERM
raises through the ordinary error/finally cleanup path. A subprocess test using
an actual TERM signal verifies saved partial evidence stays unusable and no
partial JSON writes remain. This does not claim cleanup after uncatchable kills.

The full rerun used a persistent terminal session, polled throughout, with those
checkpoints enabled. Its data files show clean host commit
`cfc8092a894e576163dc0f59ac4b1d5c41018582` and no terminal interruption.

## Verification and artifacts

All forty actual USB-local summaries uploaded with unique report IDs and the
expected Medium sequence/raster/MSAA, complete duration and retained stage.
Actual HOME/resume after measurement succeeded (2 pause and 2 resume
notifications), and opt-out cleared pending data and stopped processing.
Engine/check errors were empty. Start/end captures were visually inspected:
both actors, forest and authored shadows remained present at the Medium raster.

All forty summaries satisfied the exact backend `PerformanceReport` and
`PerformanceBatch` schema/count contracts, in batches of eight, in a
network-disabled Python 3.13 container. No account/session, backend runtime,
database or authenticated ingestion was used. Twenty-two focused Python
quality/GPU harness checks passed after the host interruption improvement.
The APK itself was reused, so no new Android build was required.

Retained local artifacts under this slot's ignored `.tmp/android-quality-phone/`:
`soak-medium-run-2/` contains final `report.json`, `details.json`,
`telemetry.json`, derived `summary.json`, two arena PNGs and two settings PNGs.
`soak-medium-run-1/` retains only the interrupted attempt's recovered evidence.
`warm-export-1/` contains the shared APK/build logs. APK SHA-256 remains
`953b9614e5174a2f12b5eaae220a47506eed04d2bc8db4c8367e9b57d7b52b21`;
APK source was `636bed02fa28`.

The complete diagnostic process was stopped, its owned ADB reverse removed and
all results saved before telling the user they could disconnect. The normal
game/data/settings were untouched. No production telemetry activation, release
certification, promotion, publishing or deployment was performed.
