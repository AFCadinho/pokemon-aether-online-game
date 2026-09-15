# Browser memory baseline — initial phase, 2026-09-15

Status: login, repeated active-map and repeated real dev-wild battle measurements
collected. Trainer, Mega and other battle styles are not covered. No caching,
prefetch, texture quality or loading strategy
has been changed. This is not an optimization or a complete RAM certification.

Open the local preview with `http://127.0.0.1:8061/?memory-probe` to enable
statistics. Otherwise the probe does not process frames and the Wasm functions
are not wrapped. Samples remain in browser memory, capped at 240; no account,
session, team, dialogue or private battle payload is collected.

## Measurements

Chromium, 1440 × 900, headless software WebGL:

- Idle login, repeat: 12 samples, 881 nodes, 227 resources; texture counter
  54.69 MiB; sprite cache empty; observed Wasm capacity 165.625 MiB.
- Final idle CDP JavaScript heap used: approximately 11.13 MiB. The separate
  `performance.memory` reading was approximately 463 MiB and disagrees greatly;
  it must not be used as an authoritative live-JS-heap or total-memory figure.
- Per-process resident measurements are recorded separately. The largest
  reported renderer RSS at the final idle sample was approximately 917.7 MiB.
  RSS contains shared mappings, and software WebGL/video/worker process costs
  make this unsuitable as a hardware-browser target or unique physical total.
- The active Bill + sixteen-map fixture passes with no captured runtime errors.
  Sprite prefetch grows the cache to 52 shared sheets, estimated RGBA allocation
  36.71 MiB. The last sample has no outstanding sprite prefetch/downloads.
- Sampled texture counters during the map traversal range from approximately
  235.5 to 457.3 MiB. The final Bill map sample is 336.2 MiB; Wasm capacity
  reached 343.5 MiB. These are not additive memory categories.

## Interpretation and limits

The sprite cache retains prefetched assets as intended; this is not evidence of
a leak. Its estimated 36.7 MiB is substantially smaller than the overall texture
counter. Large map atlases and other textures are therefore additional causal
candidates before deciding to reduce useful battle preparation.

Wasm capacity means reserved/grown linear memory, not live allocator usage;
retained high-water capacity does not prove a leak. The engine texture counter
does not cover complete driver memory. The cache estimate counts each shared
sheet once as width × height × 4, without GPU readback; active textures outside
the service cache, metadata and object overhead are not included.

The map fixture uses canonical HTTP handlers with temporary SQLite data and
authorized fixture travel; automatic trainer starts are suppressed. It does not
play real battles. Initial browser probes included overlapping test processes;
battle latency conclusions require a separate serial controlled run.

## Three-round map repeat

A separate serial run completed Bill's sequence and three consecutive rounds
through the same sixteen maps in one browser session. Each map sample waits for
sprite downloads/prefetch to finish, followed by five seconds of idle time.
No cache clearing, eviction change or forced garbage collection is used.

- All sixteen matched map samples have exactly equal texture counters and
  resource counts between rounds two and three. Warm texture counters range
  from 280.38 MiB (Mt. Moon B2F) to 477.84 MiB (Cerulean Gym).
- At the final Bill map, all three rounds have 336.22 MiB of engine textures,
  343.5 MiB Wasm capacity, 890 resources and the same 52-sheet sprite cache
  (36.71 MiB estimated RGBA; no outstanding downloads or prefetch).
- Godot node counts at those same endpoints are 5660, 5708 and 5756: an increase
  of 48 per round, averaging three per map transition. This is a concrete
  retained-object candidate, not proof of a texture leak or its cause. Check
  orphan-node counts and identify node ownership before proposing a fix.
- CDP live JavaScript heap at the endpoints is approximately 54.16, 61.13 and
  94.21 MiB. Collection timing and fixture traffic were not controlled; this
  alone does not establish a JavaScript leak.
- All 48 transitions pass, with no captured runtime errors or external traffic.

The large texture allocation is reproducible but not continually growing in
this warm map sequence. Do not reduce battle-prefetch based on these results.
The map repeat supplies no battle-start latency evidence; see the separate real
battle run below.

Reproduce from the frontend task slot (with the connected preview on 8061):

```sh
POKEAETHER_MEMORY_PROBE=1 POKEAETHER_MEMORY_MAP_CYCLES=3 \
  NODE_PATH=/home/adinho/.npm-global/lib/node_modules \
  node tests/web_misty_gameplay_smoke.cjs
```

The diagnostic report is ignored at `builds/web-misty-gameplay-qa/memory-cycles.json`.
Cycles are bounded to 1–5 and repeats require the opt-in memory probe. Ordinary
gameplay smoke still defaults to one round.

### Follow-up node classification

A freshly built slot preview on 8062 passed a three-round, two-map repeat
(Cerulean Pokemon Center and Bill's house), including Bill's full sequence.
The first attempt was rejected for stale asset-module resource UID warnings;
both slot modules were rebuilt and the clean repeat passed. No warnings were
silently filtered out.

Final Bill endpoints: total/scene node counts 5618, 5624 and 5630; orphan counter
zero. Between rounds one and three, only RichTextLabel (+4), Timer (+4) and
VScrollBar (+4) counts increased. There was no increase in map script types.
This matches four extra authorized-teleport system chat rows: the UI's
`_on_authorized_teleport_received` adds a chat message after each successful
fixture teleport, and `_add_chat_message` duplicates the RichTextLabel template.
The earlier three-nodes-per-transition signal is therefore consistent with
retained chat history, not unfreed old maps. Do not remove chat messages or
change battle preparation as a supposed map-leak fix. Long-session chat
retention/limits require a separate scoped evaluation.

Use `POKEAETHER_MEMORY_NODE_COUNTS=1` with the memory probe to collect aggregate
scene counts by script/type. This records no node names or private properties.
Traversal has extra overhead and must stay **off** during battle-latency tests.
`POKEAETHER_MEMORY_MAP_FILTER` accepts comma-separated fixture map IDs for a
shorter diagnostic run. The clean report is `memory-node-cycles.json`; diagnostic
samples are also retained on failures in `memory-node-diagnostics.json`, both
under the ignored QA build directory.

## Real battle repeat, 2026-09-15

Under slot C's shared runtime lock, the normal local Compose stack was paused.
The slot stack used a PostgreSQL tmpfs with no database volume and no normal
Gateway `.env`. Database project/storage were attested before provisioning a
synthetic developer account. Account, orchestration and Showdown handlers and
WebSockets were real; no API response fixtures were used. No production was
accessed. The normal stack/database are restored by the wrapper's EXIT trap.

The initial login was correctly rejected by the release-version gate (426).
The existing preview is older than the server minimum, so that gate was disabled
only in the disposable overlay. A dropped preview server was restarted before
successful battle starts. These failed setup attempts are not successful battle
samples. An interactive successful run was followed by the fixed command-sequence
repeat in a new browser context, with no gameplay loading-policy change.

Three Magikarp encounters (level 100) with the same single Pikachu party (level
50) in Pallet: the first battle was won through two Thunderbolts, then the party
was healed through the real dev tool; the next two battles ended through real
Run choices. Generator gender/randomness and mechanical seeds were not fixed.

The fixed-sequence repeat, Chromium 1440 × 900, software WebGL:

| Case | Start request → first playable actions | UI mount → actions | Sprite cache at request → ready |
| --- | ---: | ---: | ---: |
| First encounter | 4010.7 ms | 458.3 ms | 1 → 4 |
| Warm repeat 1 | 1378.9 ms | 350.3 ms | 11 → 11 |
| Warm repeat 2 | 1362.3 ms | 359.9 ms | 11 → 11 |

All ready samples have no outstanding sprite downloads/prefetch. This readiness
timing begins in `start_dev_wild_battle`, after Pokémon text generation; it
includes position sync, battle creation, battle sprite preparation and UI intro.
It is not the complete Spawn-button-to-actions time.

After ten-second post-battle idle waits, all three endpoints have the same
391.67 MiB texture counter, 343.5 MiB Wasm capacity, 866 resources and 11-sheet
sprite cache (8.89 MiB estimated RGBA). Warm battle-ready texture counters are
442.23 MiB, returning to 391.67 MiB after teardown. CDP JS heap used at the three
idle endpoints is 23.69, 23.21 and 21.46 MiB, with no forced GC. Small node-count
growth (5765, 5774, 5782) is consistent with growing chat/UI history; this run
does not classify every node's ownership. No JavaScript page errors were captured.
Validation requires three real successful battle starts, at least one resolved
turn and three teardown markers; the repeat has four successful turn responses.

This supports retaining useful sprite prefetch and does not show continuing
warm texture/resource growth for this encounter. It does not establish total
physical RAM, a hardware-browser SLA, or an optimization gain. Other battle
styles and longer sessions remain untested.

Artifact provenance: existing preview receipt `982d0ce2803d93c0b7d34e6055804bd69ea2ac4a`,
**dirty=true**, Godot 4.6.2; backend bind-mounted source base
`b7b48bf5da624710e1160c298ba38a7d97343ed2`; existing Showdown worker image
`sha256:6ce33533d633d62a2cdcd2740d4b57cf18c3ecebe35f7f575ce9b2fbe128eb6c`.
The dirty build receipt prevents treating this exploratory run as an exact
committed candidate/control artifact. Rebuild a clean, identified control before
accepting any performance optimization. Both runs use the same existing preview
binary; the raw reports remain ignored under `builds/web-real-battle-memory/`.

Reproduce (after saving scenes and allowing the local backend interruption):

```sh
ops/worktrees/runtime-lock slot-c -- \
  .worktrees/slot-c/backend/ops/run_web_battle_memory_runtime \
  env NODE_PATH=/home/adinho/.npm-global/lib/node_modules \
  node .worktrees/slot-c/frontend/tests/web_real_battle_memory.cjs \
  < .worktrees/slot-c/frontend/tests/web_real_battle_memory.commands.jsonl
```

The preview must already be served on 8061. The command file is a viewport-specific
canvas sequence; UI changes or a different generated battle outcome may require
interactive adjustments. Do not edit the runtime wrapper while it is running.
`ops/test_web_battle_memory_runtime.py` checks fixture refusal guards and the
resolved volume/env-file/version-gate configuration without runtime mutations.

## Clean control and packed-texture inventory, 2026-09-15

The slot-C core was rebuilt before editing the diagnostic tooling. Its receipt
identifies `e06f548c5a6c2ee5efbc73aaa0461ba79ae26d0a`, **dirty=false**,
Godot `4.6.2.stable.official.71f334935`, 261.6147 MiB initial files.
Core PCK SHA-256:
`3072ab86eb02accf075bdfa9ede14b62486e2ff24c5d75777be26dca0aeda8c7`.
Both map modules were rebuilt in this same slot, not copied from another checkout.
The Misty module PCK SHA-256 is
`cd7af0e05028d521e715a4a66b13b9c911ac2fee7752703799e9956cc88b15f1`.

The control is served separately on 8062, leaving the user's 8061 preview alone.
Bill's complete meeting, cell separation and ticket reward, then authorized
travel to `kanto_cerulean_city_pokemon_center` and
`kanto_route_25_bills_house` pass with no captured runtime errors. This is one
two-map cycle, not the earlier sixteen-map warm sequence or a real battle run.
Texture counters at these indoor endpoints are 266.06 and 264.48 MiB; resources
831 and 786, Wasm capacity 286.25 MiB, orphan counters zero, sprite cache empty.
These areas/fixture do not exercise encounter prefetch. Do not compare the empty
cache with the earlier 52-sheet route as an optimization gain.

The first attempted map filter used invalid abbreviated IDs and was rejected
after Bill's sequence; the valid rerun above passed. Its initial setup overlapped
an exploratory login process, so only the later serial login rerun is retained
as the login control. No shared backend interruption was needed for these
SQLite-fixture checks. The serial login control has 13 samples, 54.69 MiB engine
textures, 165.625 MiB Wasm capacity, 881 nodes, 227 resources and an empty sprite
cache; its final CDP JS heap used is 11.60 MiB. No optimization gain is claimed.
The export logs contain existing duplicate/invalid resource
UID and nested-launcher-project warnings (no script/export errors found).
These are not suppressed or described as warning-free/full certification.
The clean core still needs a like-for-like real battle control before accepting
a battle-memory or latency optimization; the older real-battle timings above
do not automatically become timings for this newly built binary.

`tools/audit_web_texture_memory.py` reads PCK directory entries and imported
CTEX dimensions directly. It does not load, resize or evict game resources.
The core contains 9,219 CTEX entries. Important findings:

- The source combo/text logos are imported at 2048 × 1805 and 2048 × 686,
  approximately 14.10 and 5.36 MiB RGBA respectively, not their larger source
  dimensions. Existing importer size limits are respected by this audit.
- `assets/ui/moon.png` is packed at 5000 × 5000 (95.37 MiB RGBA estimate), but
  no explicit scene/script/data reference to that exact asset was found. Its
  packed presence alone does not prove that it is loaded in the world.
- There are 43 groups of byte-identical battle-effect CTEX payloads, covering
  159 texture paths. Their duplicate packed payloads total only 1.99 MiB.
  Nine Electric sheets each have the same 16.17 MiB RGBA estimate; sixteen
  Strike sheets each have the same 4.22 MiB estimate. The simultaneous resident
  subset is not measured here: multiplying all these entries is not live RAM.
- Generated map textures use PortableCompressedTexture2D `.texture.res`, not
  CTEX. They are reported separately with packed sizes only: 150 core resources
  (11.40 MiB) and 150 Misty-module resources (8.29 MiB). No decoded atlas-size
  inference is made from these compressed file sizes.

World code preloads `battle.tscn`, including its terrain sheets. The animation
router retains requested resources by path and prepares them through threaded
requests. Byte-identical sheets at different paths are therefore a concrete
sharing candidate. First measure which duplicates coexist (including terrain
and move effects), then share canonical textures without postponing current
preparation. Keep the sprite cache/prefetch unchanged. No sharing change or
memory saving has been implemented or demonstrated in this phase.

Reproduce the read-only inventory and control checks from slot-C frontend:

```sh
python3 tools/audit_web_texture_memory.py
python3 tools/audit_web_texture_memory.py builds/web/modules/kanto-through-misty-maps.pck
python3 tests/test_audit_web_texture_memory.py
POKEAETHER_WEB_PREVIEW_URL=http://127.0.0.1:8062 \
  NODE_PATH=/home/adinho/.npm-global/lib/node_modules node tests/web_memory_baseline.cjs
POKEAETHER_WEB_PREVIEW_URL=http://127.0.0.1:8062 POKEAETHER_MEMORY_PROBE=1 \
  POKEAETHER_MEMORY_MAP_FILTER=kanto_cerulean_city_pokemon_center,kanto_route_25_bills_house \
  NODE_PATH=/home/adinho/.npm-global/lib/node_modules node tests/web_misty_gameplay_smoke.cjs
```

Run the browser checks serially. Seven auditor tests cover PCK versions/base
offsets, imported dimensions, refusal of encryption/truncation/out-of-bounds
payloads, invalid CTEX headers and read-only duplicate reporting.

### Cached-effect residency probe

The real-battle driver accepts `POKEAETHER_MEMORY_TEXTURE_AUDIT=1`. It derives
an explicit whitelist of at most 256 public battle-effect asset paths from the
packed duplicate inventory and sets `window.pokeaetherMemoryTexturePaths`.
The opt-in memory probe reports cached paths/dimensions and a RID-deduplicated
RGBA estimate using only `ResourceLoader.get_cached_ref`, without resource
loads or GPU/image readback. Uncached resources stay uncached. It holds no
texture references in its output; no player/session/resource properties are
read. Native gameplay and ordinary unprobed browser gameplay remain disabled.

An audit run records `textureAudit=true` and `timingComparable=false`; use it
to identify coexisting textures, not as a latency control. Timing comparisons
must leave this whitelist unset. The focused Godot test covers existing shared
textures, repeated paths, absent resources and refusal of non-effect paths.
This tooling does not yet change sharing, eviction or prefetch. A real rendered
audit must be collected before claiming resident-memory savings.

## Battle timing protocol for a future candidate

Use a disposable local gameplay account with the real battle runtime. Repeat
the same encounter/side/species and map sequence, separating cold and warm
sprite cases. Record request-to-first-playable-actions and UI-mount-to-actions,
then idle samples after teardown. Compare only like-for-like repeats before and
after a concrete optimization. Keep party/current-area prefetch and battle
assets ready; reject candidates that noticeably slow battle entry.

Probe labels include `battle_start_requested` for wild/dev/trainer starts,
`battle_ui_mount_begin`, `battle_actions_ready`, and `battle_teardown_begin`.
AI training's `battle_response_received` starts after the backend response,
so it excludes request/network latency. Later turn-ready events must not be
mistaken for a new battle. Playable-actions readiness does not independently
prove all asynchronous sprite downloads are finished.

Focused checks: `web_memory_probe_check.gd` (shared-sheet counting, unchanged
96-entry limit, native probe disabled), `web_memory_bridge_check.cjs` (opt-in,
real Wasm capacity/growth, bounded samples), existing settings-interface check,
`web_memory_baseline.cjs`, and the memory-enabled Misty gameplay smoke all pass.
Raw diagnostic reports remain ignored under `builds/`; no production, release
or full paired certification operation was performed.
