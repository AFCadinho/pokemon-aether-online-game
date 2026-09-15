# Browser memory baseline — initial phase, 2026-09-15

Status: login and repeated active-map baseline collected; repeated real-battle baseline
is still outstanding. No caching, prefetch, texture quality or loading strategy
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
Real battle creation, first playable actions and teardown still need their own
measurement; the map repeat supplies no battle-start latency evidence.

Reproduce from the frontend task slot (with the connected preview on 8061):

```sh
POKEAETHER_MEMORY_PROBE=1 POKEAETHER_MEMORY_MAP_CYCLES=3 \
  NODE_PATH=/home/adinho/.npm-global/lib/node_modules \
  node tests/web_misty_gameplay_smoke.cjs
```

The diagnostic report is ignored at `builds/web-misty-gameplay-qa/memory-cycles.json`.
Cycles are bounded to 1–5 and repeats require the opt-in memory probe. Ordinary
gameplay smoke still defaults to one round.

## Battle timing protocol still to run

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
