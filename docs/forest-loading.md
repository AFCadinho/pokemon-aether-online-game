# Forest first-battle preparation

The fixed 10-second total preparation deadline could reject a still-loading
forest. Terrain I/O previously began only after the model queue completed.
The cached terrain resource then made a second battle substantially faster.

Desktop 3D now requests the selected forest pack from the existing map-prefetch
hook, using the same arena/environment resolver as battles. No battle nodes,
combatants or network state are retained. If prefetch has not happened, terrain
loading starts concurrently with model loading at battle preparation.

Preparation uses a 10-second inactivity budget, refreshed by resource/model and
shader preparation progress, with a 120-second total safety ceiling. The screen
cover displays the current phase. A stalled preparation stops 3D activation and
offers an explicit 2.5D continuation. Disconnect/end still cancels preparation.
This does not pause server-side PvP clocks.

## Focused evidence (2026-09-21)

Godot 4.6.2, Linux, RTX 3070 Laptop GPU, local purchased forest pack and prepared
Dragonite/Roaring Moon catalog. Fresh processes, existing disk/driver caches;
these are individual diagnostic runs, not clean-install or statistical results.

| Preparation | First battle | Second battle |
| --- | ---: | ---: |
| Before | 6786 ms | 2066 ms |
| Concurrent terrain/model loading | 3708 ms | 2217 ms |
| After completed terrain prefetch | 2299 ms | 2066 ms |

The explicit prefetch run spent about 919 ms loading terrain before the battle.
The reported user timeout was not reproduced on this workstation; the old fixed
deadline and serial loading were confirmed directly in code. No paid assets,
caches or machine settings were modified/copied for this fix.

Focused regression entry points:

- `tests/forest_cold_start_check.gd`: immediately awaits readiness in a fresh
  process, then repeats and checks viewport release. Requires the local model
  report in `POKEAETHER_3D_STAGE_REPORT`. Set `POKEAETHER_TEST_FOREST_PREFETCH=1`
  to complete terrain resource prefetch before creating the first battle.
- `tests/battle_preparation_progress_check.gd`: progress extends the window;
  actual inactivity still times out and cannot activate 3D afterward.
- `tests/battle_screen_host_check.tscn`: cover, explicit fallback, cancellation,
  world restoration and party hover/click regression.
- `tests/battle_arena_integration_check.gd`: forest actions, recall/send-out,
  switching, repeat battle and release of both viewports.

Remaining performance work: terrain instantiation and clearing/path preparation
still run on the main thread, twice for the two render passes. The previously
observed synchronous hitch is not eliminated by earlier resource loading.
Cold installations and slower hardware need separate timing. Replacing the
approved environment is not warranted by these results.
