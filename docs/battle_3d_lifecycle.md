# Independent 3D battle presentation

Active development targets desktop 3D only. The existing sprite renderer stays
in the repository, but feature parity is not a requirement for this milestone.
Battle state, rules, networking and recorded events remain shared.

## Desktop raster quality

The renderer uses a Control with a linearly filtered TextureRect and an
independently sized SubViewport. Its raster size follows the transformed
on-screen dimensions (including window stretch), rather than inheriting the
1152×648 HUD design resolution. Four-times MSAA remains enabled. Camera
projections are converted from raster pixels back into UI coordinates before
exposing anchors, so changing resolution does not move HUD/effect targets.
The local arena uses a 25-unit orthogonal directional shadow region instead
of the default 100-unit cascaded setup. Materials, lighting energy, model size
and camera framing are unchanged; matching the sprite lighting remains separate.

The acceptance test checks raster sizing and anchor stability at 0.75×, 1×
and 1.37× presentation scale, along with its normal three lifecycle rounds.
Higher-resolution displays require more GPU work; this is not a 4K or low-end
hardware certification. See Godot's
[screen transform API](https://docs.godotengine.org/en/4.6/classes/class_canvasitem.html#class-canvasitem-method-get-screen-transform).

## Ownership

- The battle host projects the displayed combatant and sleep status, including
  ordered switch events and replay restoration.
- The animation router sends 3D actions directly to `model_presenter` when it
  handles that side. It does not call hidden sprite attack/damage/faint methods.
- The 3D presenter owns its models, animation players, positions, transition
  scale, visibility, playback speed, cancellation generations and viewport/world.
  Sprite visibility, opacity, scale, frames and action timers are not inputs.
- Optional sprite-box adapters expose projected 3D bounds to the existing
  screen-space effects/HUD and hide the old visuals. `setup()` also works with
  no sprite boxes/platforms; this is covered by the runtime acceptance test.

## Lifecycle contract

| Entry point | Contract |
| --- | --- |
| `set_combatant(index, species, shiny, force)` | Project an occupant; cancel stale transitions. Force resets a same-species switch. |
| `await_prepared()` | Yield frames while prepared local assets load, with a bounded wait. |
| `send_out(ident)` | Await the presentation-owned entry transition; return success or cancellation. |
| `recall(ident)` | Await the presentation-owned exit transition; hide only that actor on success. |
| `start_action(ident, action)` / `wait_action(ident)` | Start the native clip beside move effects, then await its own completion. |
| `play_action(ident, action)` | Await damage/faint; completed faint hides the model, not the authoritative team member. |
| `set_sleeping(index, sleeping)` | Set the resting animation without repeatedly restarting it. |
| `cancel_actions()` | Cancel owned actions/transitions and restore a stable presentation for replay/teardown. |

Send-out and recall currently use simple model scale transitions. They are
explicit lifecycle operations, not final art. Future 3D Poké Ball staging can
replace their internals without changing the host's switching flow. The 3D
host route works without a sprite box or the old Poké Ball player, including
in the focused tests. Rendering does not decide whether a switch is legal,
whether a Pokémon faints, or what the server state becomes.

## Dedicated battle screen

Desktop battles opened with 3D selected now mount `battle_screen_host.tscn`
inside the screen-space battle layer, instead of the draggable map overlay.
This is a separate presentation scene, **not** `change_scene_to_file`: the
overworld instance, connection and map services remain alive. The renderer
already owns its SubViewport/World3D/Camera3D; the map Camera2D is not mutated.

The host covers the overworld with an opaque backdrop, hides its UI and
suspends UI input callbacks (not processing or network services). It scales
the HUD uniformly to fit and expands the logical canvas for different aspect
ratios. A loading cover yields while prepared models load, then fades away.
The existing encounter cover can finish independently without resizing the
full-screen battle. Unsupported model situations retain the current fallback
inside this same screen; changing renderer settings does not reparent a battle.

World remains the sole owner of player input/activity locks. Normal end,
failed setup, replay close and replacement use its central cleanup method.
Host release and tree exit restore the UI once, cancel entry work and free the
screen. Return is currently immediate, not a cinematic exit animation. No
cached player/map transform is restored, so relocation/blackout state is not
overwritten. Connection loss that removes World also removes its battle host;
reconnect/reward/teleport rules themselves are unchanged.

The next visual iteration can add exit choreography without moving battle
authority or input-lock ownership into the renderer.

## Verification and remaining scope

`battle_screen_host_check.tscn` exercises the real World mount/clear methods,
three screen sizes, UI input restoration, repeated cleanup, cancellation during
entry and tree-exit cleanup without starting a backend. It also checks that
the host never overwrites a changed player position or map camera.
The hover regression also places the real party rail in an isolated scaled
screen, checks tooltip placement at 0.75/1/1.5 scale, and injects mouse clicks
through an overlapping tooltip. Selection is observed without a network submit:
healthy reserves emit a choice, active/fainted slots are disabled, and turn/input
locks block selection until reopened. The tooltip and all its children ignore
pointer input; placement uses global scaled dimensions rather than local size.

`battle_3d_presentation_check.gd` now runs through the full-screen host and exercises three full replay sequences,
send-out/recall completion and cancellation, same-species replacement, native
clip completion, speed changes, and an independent presenter with no sprite
boxes. Another check removes hidden sprite frames and visibility and removes
the legacy Poké Ball player while the 3D route continues working.

This uses the real client battle scene/renderer with a synthetic recorded
response sequence and GPU screenshots, not an authenticated live server battle.
Human in-client review is still required. No new species, attack camera shots,
final 3D Poké Balls, map unloading, or network/progression changes are included.
Existing screen-space move effects and fallback sprite assets remain; this is
not yet a full 3D VFX replacement or a zero-sprite-memory claim.

Local GPU check (RTX 3070 Laptop, 2026-09-20): three rounds passed; highest
sampled loading interval 38.659 ms, action interval 36.453 ms, replay setup
45.962 ms. Static memory differed by less than 7 KiB after three rounds and
owned viewport/actor weak references were released. These are local regression
observations, not a guaranteed 60 FPS budget or proof of flat driver VRAM use;
the global video-memory counter rose from about 179 MB to 213 MB in this run.

Hover-fix follow-up: all three GPU replay rounds passed again (loading maximum
29.830 ms, action maximum 46.013 ms). Static memory did not grow across rounds;
the global video-memory sample was 178,953,600 bytes after each round. This still
does not replace a live battle review or establish a universal frame budget.
