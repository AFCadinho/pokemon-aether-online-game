# Optional desktop battle presentation

Product direction: [battle platform strategy](battle_platform_strategy.md).
Full 3D targets desktop only; browser and Android retain sprite-based battles,
and desktop retains the 2.5D player option.

The default remains **2.5D — sprites**. The overworld, battle rules, networking,
HP state and replay event semantics are unchanged. The 3D presenter receives
actor state and actions from the battle host/router and owns its transitions.
See [independent lifecycle and future battle-scene host](battle_3d_lifecycle.md).

## Try it

In Settings → General, choose **3D — experimental desktop** under Battle
presentation. Use **Choose local 3D preview report…** to select the generated
PBR GLB `report.json`. The file chooser saves its path, so subsequent client
launches need no environment variable. For developer testing only,
`POKEAETHER_3D_STAGE_REPORT` supplies a fallback path when no path is configured.

The report now needs a prepared companion (`report.json.runtime.json`). Run
`tools/sprite_factory/prepare_battle_3d_runtime.gd` once through slot-env with
`POKEAETHER_3D_STAGE_REPORT` pointing to the source report. It writes compressed
native scenes into `prepared-runtime/` beside that report, preserving meshes,
materials and all native 60 Hz animation tracks. It records source hashes.
Re-run preparation after changing a source GLB; this is developer tooling,
not a player-side import, download service or finalized distribution format.
The current local pair is already prepared. The existing selected report path
continues to work; without prepared data the client falls back to 2.5D.

Enable **Gentle 3D camera movement** in the same settings section for a small
idle camera arc. It defaults off, stays on the same side of the battle, and
holds during attacks/damage/faint so existing screen-space effects keep their
framing. Turning it off restores the fixed camera.

The current local study report is:
`/home/adinho/Desktop/pokemonaetheronline/game/.worktrees/slot-c/.tmp/battle-stage-pbr-01/glb/report.json`

Normal Dragonite and Roaring Moon are supported. Test a single battle with
those active species. Unsupported species, shiny variants, doubles, substitutes,
and visible field hazards/screens use the existing 2.5D presentation for both
sides. A temporarily empty slot during a switch can remain in 3D. Selecting
2.5D restores the sprites and releases imported model references.

## Scope and limitations

- This is a desktop opt-in prototype, not the production catalog or delivery
  system. It performs no downloads and bundles no GLBs or outdoor demo assets.
- The integrated arena is original simple geometry with an optional gentle
  camera arc. The separate outdoor camera study remains available; it is not
  the production arena. Attack camera choreography and 3D move VFX are future work.
- The client never imports GLTF during play. Prepared scenes are requested
  through ResourceLoader background loading and collected only when ready.
  Initial summon waits for preparation while frames continue processing (10s
  bounded wait). Canceled loads are drained without blocking or adopting stale
  results. Scene instantiation and GPU work still require measured validation.
  At most the two supported species are retained. Existing sprite resources remain available underneath for
  fallback; this prototype is not a final memory or download optimization.
- Returning to 2.5D clears queued imports, actors, model references and the
  viewport/world. Actions follow AnimationPlayer completion and live playback
  speed. Faint awaits the source animation instead of the legacy sprite fade;
  router cancellation or losing the active presentation cancels that wait.
- Current source material translation is not a visual-parity guarantee.
  Hover bounds are conservative projected bounds. Capture/summon polish and
  live switch/faint review remain necessary.
- Android and web keep 2.5D. No support or performance claim is made for 3D on
  those platforms.

## Focused checks

Run `tests/battle_3d_presentation_check.gd` through `ops/worktrees/slot-env`.
Without a report it checks the default and missing-report fallback. With
`POKEAETHER_3D_STAGE_REPORT` it also checks model loading, actions, an empty
slot, shiny/substitute fallback, projected anchors, camera enable/disable and
action hold, speed changes, faint completion/cancellation, viewport release and a recorded
Dragon Pulse/Dragon Claw, damage, recall/switch-in, return switch, faint and win
through the real replay renderer. It runs three battles, checks released
viewport references, and guards against >1 MiB repeated static-memory growth.
This is a synthetic replay fixture, not a live backend battle test. Model-load
frame intervals, replay setup duration, action frame intervals and post-battle
static/VRAM counters are separate measurements; raw application startup and
OS/driver caches are not included. Set `POKEAETHER_3D_ACCEPTANCE_REPORT` to save
JSON and optionally `POKEAETHER_3D_ACCEPTANCE_MAX_FRAME_MS=50` for a local
long-frame regression gate. This 50ms guard does not certify locked 60 FPS.

Related regression checks: `settings_interface_revamp_check.gd`,
`battle_animation_anchor_check.gd`, and `battle_substitute_presentation_check.gd`.

## Desktop acceptance evidence (2026-09-20)

Godot 4.6.2 Forward+, RTX 3070 Laptop, three consecutive in-process replay
battles. The first process run uses prepared assets; filesystem and driver
caches were not erased. No resolution, animation rate or material reduction.

| Measured phase | Battle 1 | Battle 2 | Battle 3 |
| --- | ---: | ---: | ---: |
| Model preparation maximum frame interval | 28.4 ms | 24.2 ms | 23.0 ms |
| Synchronous replay setup | 31.6 ms | 16.7 ms | 16.9 ms |
| Actions maximum frame interval | 36.0 ms | 18.6 ms | 19.3 ms |
| Actions p95 frame interval | 17.2 ms | 17.4 ms | 17.4 ms |

Post-battle video-memory counters: 176,070,016 / 176,070,016 / 176,086,400 bytes.
Static-memory counters rose by about 4.0 / 3.3 KB on repeats (including test evidence),
not a retained model-sized allocation. This is bounded-repeat evidence, not
proof of zero allocator/driver growth over hours. The separate cancellation
check starts a new request, switches to 2.5D and verifies no models are adopted.

The previous ~250 ms cold replay-setup stall was traced to building hidden
trainer heads. Wild/NPC/AI titles now skip unused appearance construction;
PvP still updates its visible heads. The remaining presentation needs human
review in the actual client before enabling attack camera shots or expanding
the catalog. The automated run does not exercise networking or raw app startup.

Implementation follows Godot's [background-loading guidance](https://docs.godotengine.org/en/4.6/tutorials/io/background_loading.html):
poll completion before retrieving the resource. Instantiation/first GPU draw
remain measured phases, not assumed free because loading is threaded.
