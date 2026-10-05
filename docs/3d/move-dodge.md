# Native 3D Dodge

A real `miss` uses the existing trainer-command callback before the move VFX
starts, matching the 2D Dodge presentation. The attacker clock is held during
the existing 0.32-second command lead, so sound and VFX cannot advance while
the trainer is still giving the command. The event renderer still owns trainer
availability, localization and dialogue; wild opponents do not gain a trainer.

The target performs a short procedural sidestep with a small hop, holds while
the attack passes, then returns during the attack's recovery. It uses the
attacker's native animation clock, including speed changes and pauses, rather
than a separate wall-clock tween. The direction is perpendicular to the attack
on the arena floor and the distance scales with the target's bounds. No new
model asset, hit sound, damage event, particle burst or gameplay change is added.

Missed VFX aim at the target's original point. They no longer add the old
sideways endpoint offset, and they do not follow the moving target. The normal
source attachments continue to animate. Contact graphics also remain at the
original target location, with impact feedback disabled. Hit, immune, fail and
protected outcomes retain their existing behavior.

The generic sidestep works for all four actor slots, visible Substitute models,
and model-only attacks that have no native move VFX yet. Cancellation,
deactivation and actor replacement clear displacement; returning completes
inside the move presentation's awaited lifetime. The 2D route is unchanged.

## Offline review

From the workspace root while slot-b owns this task:

```bash
ops/worktrees/slot-env slot-b -- godot \
  --path .worktrees/slot-b/frontend \
  --script res://tests/dodge_moves_preview.gd -- --moves
```

**Ontwijken (miss)** is selected initially. Play Water Gun, Ember or a contact
move, reverse the attacker, pause and orbit. The trainer's localized Dodge
callout appears before movement. The existing **Bronmateriaal** switch retains
the Water Gun comparison; its source-textured candidate remains preview-only.

## Focused checks

- `battle_dodge_3d_check.tscn`: four actor slots, fixed aim, pause, return,
  Substitute, command/clock ordering, model-only moves, non-miss outcomes,
  cancellation during command preparation with real audio, and deactivation.
- `battle_move_effects_3d_check.tscn` and
  `battle_move_presentation_routes_check.tscn`: routing, sound, outcomes,
  recovery and cancellation with the newly earlier command moment.
- `source_move_effects_3d_check.tscn`: approved visual recipe parity, with the
  historical Ember reference instructed to use the requested straight miss aim.
- `battle_3d_impact_pacing_check.tscn`: impact bridge, gem ordering and faint.
- `battle_animation_recovery_check.tscn`: existing 2D Dodge and restore behavior.
- `dodge_moves_preview.gd -- --moves --smoke-dodge`: real rendered models, all
  six native moves in both directions, command lead, fixed aim, pause/orbit,
  restore and cancellation. Set `POKEAETHER_STAGE_OUTPUT` for screenshots.
