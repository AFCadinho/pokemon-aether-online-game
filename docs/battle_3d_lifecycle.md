# Independent 3D battle presentation

Active development targets desktop 3D only. The existing sprite renderer stays
in the repository, but feature parity is not a requirement for this milestone.
Battle state, rules, networking and recorded events remain shared.

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

## Separate battle-scene direction

The intended next host is a dedicated full-screen battle presentation, with
an entry transition from the overworld and an exit transition back. This change
does **not** implement that screen transition or unload maps yet.

Prefer retaining the overworld instance initially, transferring local input
and camera ownership to the battle host and restoring them exactly once on
exit/cancellation. Keep networking alive; do not pause the entire SceneTree.
The battle host owns and releases its viewport/world, resources and transitions.
It must not own overworld movement state or assume it is embedded in a map.
Server-driven teleports/disconnects during battle will need explicit handling
when the host transition is implemented.

## Verification and remaining scope

`battle_3d_presentation_check.gd` exercises three full replay sequences,
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
