# Animated move attachment points

`move_attachments_3d.gd` maps a move to an anatomical part, then resolves a
species/form profile to one or more bone-local offsets. This is independent of
the move's damage category: Bite and Ember can both use a mouth, while Scratch
uses a hand. Physical hit graphics still appear at the target. Tackle, Scratch and Bite now
use a separate [contact approach](contact-move-effects.md) to move the attacker
to the target and back on the same native action clock.

## Initial profiles

| Model | Move/part | Bone(s) |
| --- | --- | --- |
| Pikachu | Thunder Shock, Thunderbolt / electric body | `spine_02` |
| Charmander | Ember, Water Gun, Bite / mouth | `head` |
| Charmander | Scratch / hand | `right_hand` |
| Squirtle | Ember, Water Gun, Bite / mouth | `head` |
| Blastoise | Water Gun / cannons | `left_feeler_b_02`, `right_feeler_b_02` |
| Blastoise | Ember, Bite / mouth | `head` |

The primary visual review is Charmander + Ember, Squirtle + Water Gun, and
Blastoise + Water Gun. Profiles are shared with the shiny version, but never
implicitly inherited by Mega or other alternate forms. Unconfigured parts,
unknown rigs, missing bones, and visible Substitutes retain the previous
bounds-based origins. Tackle retains this fallback. Thunder Shock and Thunderbolt follow Pikachu’s upper-body bone
through its jumping attack; other species retain the body fallback. Additional hands, feet, tails and species can be calibrated
as moves need them, without changing the physical/special classifier.

Offsets use the reviewed runtime rig, in bone-local coordinates. The initial
mouth offsets were calibrated against head/face geometry in skin bind space.
Blastoise's cannon mesh weights identify the two `feeler_b_02` bones as the
moving barrels: the muzzle is at approximately local X = 0.261 m, Y/Z = 0.
The rig's rest pose is not its mesh bind pose, so using a mesh-space point as a
bone offset produces an incorrect origin.

Bindings are cached on each model instance; skeleton references are weak.
Each sample reads the current bone pose and applies skeleton/global/world
transforms. Replacing the model drops its cache, with no global references to
old actors. Both effects run after the stage's actor/camera update. Two cannon
origins remain one logical effect with one clock, one impact and one audio plan.
Target impact positioning retains the existing bounds calculation.

## Offline review

From the workspace root, with slot-b assigned to this task:

```bash
ops/worktrees/slot-env slot-b -- godot \
  --path .worktrees/slot-b/frontend \
  --script res://tests/move_attachments_preview.gd -- --moves
```

Choose Charmander + Ember, Squirtle + Water Gun, or Blastoise + Water Gun.
Purple markers label the current emitting part (`mouth`, `cannons`, or the
`bounds` fallback). They are debug visuals only and can be hidden with
**Aanvalspunten tonen**. Pause during the attack and orbit the camera to check
placement. The **Bronmateriaal** toggle compares the approved Water Gun effect
against its previous procedural rendering. Both Ember and Water Gun are now
approved and use the source-textured effects in normal battles.

## Checks

- `move_attachments_3d_check.tscn`: animated translation/rotation, scaled actor
  and transformed world, shiny/form routing, incomplete rigs, model replacement,
  paired emitters, bounded geometry and one target splash for hit/miss/block.
- `move_attachments_preview.gd -- --moves --smoke-attachments`: actual approved
  models for the three primary cases, animated origins, pause and camera orbit.
  Optional `POKEAETHER_STAGE_OUTPUT` captures two angles and a closeup with
  VFX hidden so the attachment itself is visible.
- Existing `source_move_effects_3d_check`, `battle_move_effects_3d_check`,
  `battle_move_presentation_routes_check` and `battle_3d_impact_pacing_check`
  cover approved Ember parity, audio, four actor slots, Substitute, 2D fallback,
  cancellation, gem order, impact recovery and faint.
