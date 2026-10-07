# World startup latency, 2026-10-07

The reported pause is after authentication, with Trainer and Party complete and
World active ("Opening the path to your adventure..."). The spinner stopping
before world entry points to synchronous client work. Threaded resource loading
does not make scene instantiation or node `_ready()` callbacks asynchronous.

## Observations and scope

- Production HTTP observations in a login window included a 371 ms successful
  login and two full profile responses at 182 and 173 ms, both 34,895 bytes.
  The window also contained repeated identical inventory response sizes,
  including a simultaneous burst around 806–837 ms. Requests were not bound to
  a captured account identity; these are window observations, not a complete
  timeline for a specific player. No response bodies or session tokens were
  retained.
- Recent numeric client log samples showed battle UI prewarms of 187–801 ms
  and forest preparation of 1,067–1,754 ms. These samples do not partition the
  reported approximately 20-second login or establish which player/run they
  belong to.
- Changes here are frontend-only and require a new client build. They do not
  alter network RTT, ping averaging, or server authentication. No deployment or
  publication is part of this task.

## Changes

1. Login preview uses the fresh `appearance` returned by login or `/auth/me`,
   avoiding a full `/game/profile` request just for the outfit. Older responses
   retain the profile fallback. Late or mismatched fallback replies are rejected.
2. Loading still performs story recovery before the authoritative game profile.
   It hydrates the profile's full inventory, including borrowed items and mount
   license regions, before world/mount restoration. An incomplete older profile
   uses the inventory endpoint fallback.
3. Initial key-item and field-move readers reuse that account/session-bound
   inventory. Explicit Bag opens and reloads after purchases, item use and other
   mutations continue to fetch fresh state. Account reset invalidates the cache;
   an inventory GET completing after a session/account exchange cannot apply.
4. Loading joins or reuses the auth transition's thieving-state load. Explicit
   refreshes remain server reads. Concurrent waiters share their result, and
   completion from an old account cannot erase a new account's pending request.
5. Nine hidden windows are constructed on first open: Trainer Card, Gift Store,
   Poké Mart, Exchange, Atelier, Bank, Move Mentor, Move Deleter and Shiny Tracker.
   Subsequent opens reuse their windows and signal connections. Mount box
   notifications are connected independently of opening Shiny Tracker.
6. Desktop/mobile saved map resources load on a worker while the loading screen
   can still draw. The prepared PackedScene is held across the world handoff.
   Browser map placement keeps its existing no-placeholder-frame ordering.
7. World startup no longer builds an unused battle UI. Actual encounters use
   the existing cold mount path; live battle recovery still mounts its UI before
   idle recovery and presence. Optional prewarms elsewhere remain available.

## Local measurements

Godot 4.6.2, slot-a, headless/dummy renderer. The initial source was
`de2ea2b566b6fec7ba3dba40ae7bddf01f993cda`. Five fresh HUD instances per process,
with the real synchronous `_ready()` callbacks and no authenticated account.

| HUD ready time (ms) | Before | After lazy windows |
| --- | ---: | ---: |
| Sample 0 | 1,007.530 | 774.098 |
| Sample 1 | 917.189 | 619.224 |
| Sample 2 | 768.615 | 627.193 |
| Sample 3 | 745.333 | 608.542 |
| Sample 4 | 738.911 | 615.070 |
| Median | 768.615 | 619.224 |
| Instantiated HUD nodes | 4,168 | 3,084 |

This removes 1,084 initial nodes (26%) and reduced median HUD-ready CPU wall time
by 149.391 ms (19%) in this small sample. In the individual popup probe, the
first nine windows cost 282.439 ms combined; Trainer Card was 107.963 ms, Gift
Store 92.654 ms and Exchange 33.039 ms. A focused battle-entry fixture also
measured a 720 ms prewarm which is no longer mandatory during login.

These are local CPU observations, not a production RTT or total-login forecast.
Cache state, other local work, renderer, hardware and first shader compilation
affect timings. Popup/battle construction now occurs at first use, so first
opening can take longer than reopening. Scene instantiation, remaining HUD
construction and 3D arena preparation can still block or delay entry.

Reproduce the probes from the workspace root (each command uses slot isolation):

```sh
ops/worktrees/slot-env slot-a -- godot --log-file "$PWD/.worktrees/slot-a/.runtime/test-logs/startup-popups.log" --headless --path .worktrees/slot-a/frontend --script res://benchmarks/startup_popups.gd
ops/worktrees/slot-env slot-a -- godot --log-file "$PWD/.worktrees/slot-a/.runtime/test-logs/startup-popups-full.log" --headless --path .worktrees/slot-a/frontend --script res://benchmarks/startup_popups.gd -- --full
```

## Client phase diagnostics

Enable `POKEAETHER_STARTUP_TIMINGS=1` for the client process, or pass
`-- --startup-timings`. Logs contain only fixed phase names and durations:
story bootstrap, game profile, profile hydration, inventory/thieving bootstrap,
world/map resource loading, world/map instantiation, saved map ready, HUD ready,
desktop arena, battle/idle recovery and world restoration. They contain no
usernames, identities, credentials or game-state payloads. Timing is disabled
by default and is usable in release builds.

`world_instantiate` measures `change_scene_to_packed()`'s synchronous creation;
child ready callbacks happen later and are measured separately. Recovery phases
include awaited network/arena work and are not pure CPU timings. Use these
phases with client frame observations after publishing the new build to locate
the remaining startup delay; the existing 20-second report is not yet resolved
into an end-to-end client trace.

## Focused validation

25 task-related functional checks passed (24 scripts plus the trainer-resume scene).
Coverage includes profile inventory/licenses, request reuse and account exchange,
actual first-open/close/reopen actions for all nine windows, localization,
initial spawn/browser ordering, mounts/field moves, thieving/jail state,
preferences, wild/trainer entry, activity recovery and trainer snapshot resume.
Cold fullscreen entry is exercised with both 2D and 3D presentation settings;
actions stay locked until authoritative responses, and rejected entry restores
the world. The loading handoff also rejects a changed session with the same ID.

`login_visual_choice_check` exits 0 with PASS but has a two-resource shutdown
diagnostic; this is identical on the original task base. Its settings write
warning deliberately tests a failed write. An additional manual
`battle_screen_host_check.tscn` hits its Team Preview cover assertion (line 71)
on both current code and the original base, including Vulkan/RTX 3070 runs. It
is not counted as passed or as complete 3D rendering certification. The relevant
new cold-entry controller checks pass, while that separate fixture remains a
validation limitation. Existing resource UID fallback warnings also occur in
the slot. No full release/development certification was requested or run.

After incorporating newer development commits, request reuse, lazy windows and
cold battle entry passed again. Discord bridge, account/privacy controls and
Android platform policy compatibility checks also passed (28 distinct passing
checks in total). The separate Android pilot scenario requires a tagged Android
debug APK; its desktop invocation correctly rejected the platform and is not
counted as passed or as device validation.
