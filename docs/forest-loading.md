# Current grassfield and outdoor loading

Grassfield and both Route 22 variants now use ordinary mesh terrain. Terrain3D
and the original forest-world scene are no longer loaded by the client. Shared
art loads asynchronously through the existing preparation UI and session pool.
The old native extension field is ignored; the existing forest art pack remains
required. See [arena structure](../scripts/battle/arenas/README.md).

The measurements and implementation notes below are historical evidence from
before this migration, not measurements of the current mesh-based arenas.

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

Remaining performance work after the first fix: terrain instantiation and clearing/path preparation
still run on the main thread, twice for the two render passes. The previously
observed synchronous hitch is not eliminated by earlier resource loading.
Cold installations and slower hardware need separate timing. Replacing the
approved environment is not warranted by these results.

## Session-owned prepared environment (follow-up)

The earlier web-prefetch hook did not cover ordinary desktop startup/map entry.
Desktop initial state, normal map changes and authorized desktop teleports now
explicitly prepare the selected forest before revealing the map. Startup owns an
input lock only when input was previously unlocked; map transitions retain their
existing cover/lock ownership. Teardown releases the preparation-owned lock.
Changing settings can also request background preparation. Missing packs do not
block map entry. A battle racing an in-progress pool waits rather than assembling
a second copy. There is still an initial load, now paid on map entry.

`forest_environment_pool.gd` retains exactly one main/light-pass pair per world
session, never a battle screen, actor, animation player or server state. Prepared
viewports remain in their original tree: Terrain3D is not detached/re-entered or
flattened again. They stop rendering and processing while idle. An exclusive
weak borrower prevents concurrent battles sharing actors. Release removes every
non-environment world child; mode changes also release the lease. Leaving the
world frees both passes. Other arenas and non-pooled tools keep their previous
ownership. No new assets, cache copies or resolution reductions are involved.

Two fresh-process diagnostic runs with existing disk/driver caches:

- One-time environment preparation: 3055 / 2605 ms.
- First battle after preparation: 667 / 617 ms.
- Second battle: 650 / 616 ms.
- After both battle releases: 5165 total test-process nodes and 317241184 bytes
  reported render video memory in each cycle (about 303 MiB, not incremental
  per-battle usage). The warmup monitor delta was 469562720 bytes; this includes
  transient allocations and is not an isolated retained-pool measurement.

These are local 1152×648 render-target measurements, not a guarantee of instant
startup on all hardware. Fullscreen targets can retain more GPU memory. Terrain
assembly still occupies the main thread during the map-loading cover. Models
and model-specific material warmup are still per battle.

`POKEAETHER_TEST_FOREST_POOL=1` on `forest_cold_start_check.gd` checks exact viewport
reuse, recall/send-out, physical/special/damage/faint, switching, mode change,
stable idle child counts and teardown. `forest_map_preparation_check.gd` checks
desktop call sites, preparation gating and input/cover ownership with no network.
