# Android ordinary battle entry trial — 2026-10-15

This follows the [first-attack preparation control](android-first-attack-preparation.md)
using the ordinary battle screen host, battle scene, request parser, intro and
animation router. The integration had a gap: Team Preview intentionally skips
effect preparation, but there was no later attempt once lead selection supplied
the active Pokémon's move request. The optional trial now checks that request
after summons and before opening first-turn actions.

Automatic activation remains off. The existing `android_3d_move_warmup` feature
still requires experimental Android 3D and the Mobile renderer. Neither preset
defaults nor production telemetry activation changed.

## Entry and ownership

Wild, trainer and player PvP setup now call the same gated preparation hook. It
reads `BattleState.get_available_moves()` for the local player at that point,
locks input while waiting and restores the previous lock only if the same
battle/presenter remains valid. An inactive 2D fallback proceeds normally;
cancelled preparation does not open first-turn actions.

The presenter waits for any host-owned preparation to finish, then checks its
normalized move request and preparation generation. Repeating the same request
does not restart the budget or refill a consumed effect. A changed request or a
cleared pool can prepare again. Metrics retain at most four rounds and contain
no effect/actor references. The existing cooperative 1,500 ms budget, five
reviewed reusable paths, single-use handoff and hidden sampling remain in force.
Own available moves take priority; the existing small common set can fill gaps.

Team Preview prepares no guessed casts. The ordinary party selection signal
chooses slot 2 in this trial, changing the own lead from Charizard to Dragonite;
the later authoritative-style response supplies its moves before the new hook.
No lead selection is sent to a game server.

## Physical comparison

The first Rock Slide maximum loop interval fell from **145.44 to 33.59 ms**.
The later two Rock Slide casts were already around 33 ms in both conditions.
Preparing five effects took **950 / 849 / 896 ms**, with no budget overruns.
Each prepared measured cast consumed exactly the recorded preparation node.

| Scenario | First-turn readiness, off / on ms | Effect preparation, on ms | Rock Slide maximum, off / on ms |
| --- | --- | --- | --- |
| Covered wild | 2907 / 3576 | 950 | 145.44 / 33.59 |
| Early-visible wild | 2517 / 3339 | 849 | 32.50 / 33.53 |
| Trainer, changed preview lead | 6144 / 6902 | 896 | 34.04 / 33.53 |

Preparation moves work before the first turn and adds entry latency. These are
two separate processes with variable unrelated setup; subtracting their total
entry times does not isolate preparation cost. Its independently measured
0.85–0.95 seconds is the more useful estimate for this fixture.

| First process window | Off maximum / p95 interval ms | On maximum / p95 interval ms |
| --- | --- | --- |
| Flamethrower | 46.18 / 30.77 | 33.98 / 32.68 |
| Thunderbolt | 20.33 / 17.06 | 31.62 / 30.39 |
| Rock Slide | 145.44 / 38.98 | 33.59 / 33.49 |
| Draco Meteor | 54.99 / 19.74 | 30.19 / 18.79 |

This supports reducing the large first Rock Slide hitch in the ordinary host.
It does not show every attack becoming faster: first-window Thunderbolt and
some p95 intervals worsened. Intervals around 33 ms also remain above the
16.67 ms target for smooth 60 FPS. Unlike the earlier standalone test, the real
battle scene preloads its router; there is no dynamic-router-load placement in
the first Flamethrower probe.

Whole-window FPS was **57.81 / 58.94 / 58.34** off and
**57.94 / 59.11 / 58.78** on. Per-window PSS was **2548.6–2586.0 MiB** off
and **2542.6–2559.5 MiB** on; render memory was **639.43–662.98 MiB** off
and **658.47–667.43 MiB** on. Three windows with different scene work do not
establish a memory saving or a leak. The full UI fixture also differs from the
previous standalone-stage fixture, so their aggregate FPS/PSS are not a matched
before/after comparison.

Each fresh process reconstructs the actual host/scene for three scenarios:
covered wild entry, early-visible wild entry before the response, and trainer
Team Preview with a changed lead. Each intro is followed by a 30-second Medium
window with four real router casts, impact/audio/cleanup checks and eight
settings tabs. Whole-window FPS includes menu construction and idle rendering;
it is not an attack-only FPS measurement.

Both APKs use the same clean source commit and differ in the explicit warmup
feature. The fixed order is off then on. Models are actual pinned v16
Charizard/Dragonite art in the real forest arena, with fixed noon/wind/camera,
60 FPS cap, Mobile/Vulkan and ARM64 debug. Both rendering passes are
**1558×720 / 2× MSAA**. The screen is 2340×1080, while the ordinary scene's
transformed arena is 2339×1081 because of UI scaling/rounding. The runner checks
the actual arena dimensions using the same transform as the presenter, rather
than requiring the standalone diagnostic's full-screen aspect ratio.

Entry time runs from host mounting to first-turn readiness. A full UI image is
read back only after that timestamp and before the settling/measured window;
the outer `preparation_ms` includes that readback, so it is not pure intro time.
Move impact pictures come from a separate unmeasured evidence pass. Timed casts
have independent visibility, impact and exact prepared-instance evidence.

## Verification and boundaries

The fixture changes the network boundary, not the ordinary host, BattleState,
intro, summon, controls, model presenter or router. Lead submission applies an
offline response. Account-only owned-icon lookup and damage-calculator prefetch
are disabled. No account is authenticated and no world/network battle is played.
Actual move names, type and base PP come from the bundled move summary index,
wrapped in the server request shape. USB-local asset wrappers preserve the
existing model/environment pins and mobile asset size/hash verification.

The full UI also needs streamed HOME icons. The first off attempt was rejected
because its local server lacked the mobile/HOME catalogs, causing two engine
JSON parse errors. Its partial first window is excluded. The rerun serves only
the two real bootstrapped party images plus hash-verified catalogs; unknown
requests still fail. The two already-built APKs were reused because this was a
host fixture correction. Nothing filters or suppresses those parse errors.

Focused checks in slot A:

- `android_battle_entry_preparation_check.gd`, headless Mobile with the real
  Android/trial gates: ordinary covered/early/preview entry, a late move request,
  changed shiny lead, first-use node identity, no refill on repeated request,
  and cancellation during both host-owned and post-host preparation. This local
  test uses generated sphere model fixtures and a local model service; it checks
  integration/ownership, not real art appearance or phone performance.
- Trainer staging, initial event pre-render order and trainer 3D summon
  visibility checks passed. The PvP realtime stream source-contract check also
  passed; its existing fixture leaves ObjectDB/resources in use at exit. That
  cleanup warning is retained in the log, not presented as a clean runtime test
  or as verification of a real PvP session.
- 36 Python quality/GPU harness checks passed, including missing/wrong request,
  input, selected lead, prepared-instance and finite timing evidence rejection;
  arena dimensions; fixture catalogs; and explicit export flag restrictions.
- Private phone script parsing and both native APK exports passed.

Both physical runs finished `usable: true`, with no engine/check errors,
foreground interruption or missing captures. Each reconstructed three distinct
arenas, used the four actual request move IDs, held first-turn input throughout
preparation and kept samples hidden. The preview selected slot 2, prepared no
casts before selection and used Dragonite as the actual own actor afterward.
All four casts in each window showed visible effect geometry and impacts and
cleaned up. HOME/resume and opt-out cleanup passed in both runs.

Six unique USB-local reports passed the exact backend `PerformanceReport` and
`PerformanceBatch` classes, three per batch, in a network-disabled Python 3.13
container. This verifies serialization and local transport, not authenticated
ingestion or persistence. All three ordinary UI images from each run and the
on-run Rock Slide/Draco Meteor impact images were visually inspected. Party
icons, changed lead, visible controls, arena and effects were present.

Device: SM-S938B / S25 Ultra, Adreno 830, Android API 37, game 0.3.110.
Battery sensor **25.1→27.4 °C** off, **27.6→29.3 °C** on. Both runs were
100%, status 5, USB powered, AC false, with power saving off; native and host
thermal statuses stayed 0. Their different starting temperatures are recorded,
not treated as controlled conditions. Foreground health polling spans intro;
the pause/resume probe begins afterward and does not certify detection of very
brief interruptions during intro.

These short runs on one S25 Ultra do not establish behavior on weaker devices,
release-build timing, long-term memory/thermal behavior, authenticated ingestion,
database persistence or fleet-wide gains. Native and host thermal status,
temperature, PSS and run order are recorded. Caches are retained between runs;
clocks, room temperature, brightness and background activity are uncontrolled.
Debug code, timing probes and host-health queries can affect measurements.

## Retained evidence and reproduction

All evidence stays in slot A's ignored `.tmp/android-quality-phone/`:

- `entry-off-2/` and `entry-on-1/`: raw report/details/telemetry, three arena,
  three ordinary UI, four impact and two settings images per accepted run.
- `entry-off-1/`: rejected incomplete attempt, log and explicit review note.
- `entry-off-export-2/` and `entry-on-export-2/`: measured APKs and export logs.
  Export 1 folders are retained but superseded and were never measured.
- `entry-comparison.json`: derived metrics from the two accepted runs.

Both APKs were exported from clean
`0ca5de808891c3b1ed7d419066273fa4ef03ba18`. Both accepted host launches recorded
clean `6b3a7a01ac3ea9d4c859dfda696a4cc3ce120fe0` after the catalog-only fix.
The host report's `source_commit` describes the host runner; APK provenance is
the export commit above and these SHA-256 values:

- Off: `cc19b0990a7f12c006f2dff66fabc1b1681ad807e2dcb166c379a6c3ef284116`.
- On: `be9ac499e2071e6f312aafb2b6ae4d9fa2bfb75e5c6e7092ff6e7dda60b1dc74`.

Export the separate `android-quality` physical ARM64/Mobile suite, adding
`--entry-move-warmup` only for the on APK. Run through the assigned slot's
`slot-env` with a fresh output directory:

```bash
python3 tools/run_android_quality_benchmark.py --serial DEVICE \
  --mode battle-entry --apk APK --output OUTPUT
```

Add `--entry-warmup` for the on APK. The app verifies its actual gate against
that expectation. Keep the unlocked diagnostic in the foreground; the host
performs HOME/resume after the three windows. The separate test process and its
owned USB reverse are stopped after each run. Ordinary game/account data stays
untouched.

Before enabling this automatically, evaluate real authenticated battle flows,
including disconnects and PvP, missing/changed requests, release builds and
more representative devices. The local cancellation checks and three physical
offline intro scenarios cover only the boundaries described above. No complete
paired certification, main promotion, publishing, deployment or production
activation was performed.
