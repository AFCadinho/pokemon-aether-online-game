# Atlas export validation — block 8

## Scope

Follow-up to block 7: validate the real desktop exports and rerun the rendered
Misty-area browser smoke test. This is not development certification, a release,
or a fresh-account story-through-Misty playthrough.

The exported atlas source is frontend `235d85c28` and backend `90b554e349`.
Follow-up testing found a browser metadata timing defect; the candidate fix
defers three metadata services across two frame boundaries in web builds only.
Desktop request timing, network timeout and battle preloading are unchanged.
The normal backend
stack was not interrupted; browser account handlers run in an isolated SQLite
fixture inside a network-disabled container, with no published backend ports.

## Desktop exports

Godot 4.6.2, the existing release presets, and the locally installed matching
official export templates were used. Explicit template-binary symlinks were
added to slot C's template directory; no checkout caches, sessions, configuration,
or assets were copied. Initial Linux export failed because slot C only had web
templates; the subsequent Linux, Windows, and macOS exports succeeded.

Each exported PCK was mounted in the existing empty probe project. The new
`desktop` probe scope checks all 33 approved visual IDs, cells, layers, used
tiles, lossless portable texture format, dimensions, and base-RGBA budget against
`tests/fixtures/tiled/migrated_visual_fingerprints.json`. All three passed. This
checks packaged resources with the Linux Godot engine, not native macOS rendering.

| Export | PCK SHA-256 |
| --- | --- |
| Linux | `244db5a31e7dff94dd1df11ce1f7b9488757b889a0eacc8e3872ecb2d00f4eaf` |
| Windows | `d90023f2d1cf1302b9a4a324a346a8693fd42425b9ee87c606a4f1d30aaa965b` |
| macOS | `cfa68b9714415fa0512cc5bb67518f4d72187c0bb3d5b262c9e325af9850dbee` |

Artifacts are slot-owned under `builds/desktop-atlas-qa/`. The macOS ZIP's PCK
was extracted within that same output directory, not copied between checkouts.

The exported Linux binary and Windows binary under Wine both started headlessly
and exited successfully with `--quit-after 120`: engine banner present, no
`ERROR`, `SCRIPT ERROR`, or missing-resource messages. Wine uses its own new
slot-local prefix. The recorded final startup runs explicitly set
`POKEAETHER_GATEWAY_URL=http://127.0.0.1:8000`; always override release defaults
for local runtime tests. This is startup coverage, not battle/UI coverage. Release
templates disable `--path` overrides; an exploratory Linux attempt with that
flag was rejected and is not counted as a successful runtime test.

## Account/story regression checks

The isolated account container ran:

```sh
POKEAETHER_WEB_BROWSER_TEST=1 ops/web_browser_test_python -m unittest \
  tests.test_web_misty_browser_fixture tests.test_starter_story_slice \
  tests.test_story_progression tests.test_story_commands
```

81 tests passed. Initially one catalog assertion failed because its expected
list ended at `help_bill`; the existing catalog also contains
`challenge_cerulean_gym`, `pokemon_fan_club_chairman`, and `board_ss_anne`.
Only the stale expected list was corrected; the catalog and browser boundary
were not expanded. These are service/contract regressions, not an actual
fresh-account browser playthrough or actual battle-engine victories.

`desktop_music_integrity_check.gd` passed as well.

## Rendered browser check

Preview: `http://127.0.0.1:8062/`, using the existing block-7 browser build.
Run `POKEAETHER_WEB_PREVIEW_URL=http://127.0.0.1:8062 node
tests/web_misty_gameplay_smoke.cjs` separately from heavy exports.

The first run completed Bill's meeting, computer sequence and ticket reward,
and reached all 16 Misty-module gameplay maps. Its strict error assertion failed
on Cerulean metadata timeouts while the desktop exports were running. The
synthetic transport recorded 200 responses for those metadata requests. Export
load is a hypothesis, not a proven diagnosis or a game-code fix. That run is
not counted as passing. A separate idle-machine rerun failed identically, ruling
out export load as a sufficient explanation. A single-Cerulean diagnostic run
recorded 200 responses within 12–15 ms for its metadata, yet the client timed
out. Long-frame request-timer accounting is the working causal explanation.

The candidate crosses two `process_frame` boundaries before creating each web
NPC, overworld-Pokémon and encounter metadata HTTPRequest. This avoids starting
their timers in the long scene-initialization frame, rather than increasing the
three-second timeout or suppressing errors. The new
`map_metadata_request_timing_check.gd` passes: no desktop frame delay, two web
boundaries, all three services defer before request creation and retain their
bounded timeout. The NPC role-boundary and dialogue metadata checks passed too.

The rebuilt browser candidate is clean frontend commit `0f0436cd2`, with PCK
SHA-256 `5bb39bfb51ba7e0ab9a5599aa48e67e1335cf8beee832e533fa02802f25f01f0`
(`219905704` bytes; total initial build still 246.2 MiB before HTTP compression).
Its single-Cerulean regression run passed with no errors. A subsequent unfiltered
run passed Bill's meeting, cell separator and ticket reward and all 16 active
Misty-module gameplay maps, with no runtime errors or external traffic. Source
checkouts remained clean throughout both candidate runs; the final report is
slot-owned `builds/web-misty-gameplay-qa/result.json`.

The paired failure/success supports the frame-timing correction on this rendered
software-WebGL setup. It is not a browser performance SLA or a measured physical
memory improvement. Desktop exports above validate the migrated atlas resources
from before this browser-only correction; native unit checks verify that the new
helper leaves desktop request scheduling immediate.

## Remaining coverage limits

No native Windows/macOS playthrough, fresh-account full storyline E2E, new
matched live battle benchmark, or physical/GPU memory measurement is established
by these checks. Existing block-6 battle measurements still apply only to their
recorded candidate/control pair. No main promotion, push or deployment occurred.
