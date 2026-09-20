# Realtime move presentation

Battle events, HP changes, ordering and turn authority remain in the existing
event renderer. BattleAnimationRouter selects presentation by the active model
presenter, not the preference alone. An inactive presenter (actual 2D fallback)
keeps the existing sprite catalogs and playback code.

## Model-only baseline

`battle_move_presentation_3d.gd` owns the 3D attack/move presentation boundary.
The renderer starts an attack, then awaits the move presentation. These phases
share one attack; direct move calls also work without the start phase.
Physical/special selection is species-independent. Missing attack clips use the
other attack clip if available; otherwise the model keeps its current pose.
Missing actors/effects never request legacy sprite effects in an active 3D scene.

Damage and faint still use model reactions. Idle/sleep, send-out, recall and
switching stay with the existing model lifecycle. Common damage audio stays
shared. Legacy heal/stat flashes and effect-catalog particles (including entrance
and mechanic effects) are suppressed in 3D until native replacements exist;
their battle messages and mechanical effects are not changed. Substitute and
capture transitions are separate existing lifecycle work, not new move effects.

Cancellation invalidates the 3D move generation before releasing model waits.
Miss callbacks are delivered once, even without native dodge visuals, and never
after cancellation. The animation preference and render guard are honored.
Active 3D routes skip legacy move/effect prewarming; startup before presenter
activation can still have shared 2D fallback assets prepared.

## Adding native effects later

Add move-specific selection and playback inside the 3D driver's awaited
`play_move` boundary, using move, actor, target and presentation options. Keep
Node3D effects in the arena's world, separate from the sprite catalogs. Own and
release particles, projectiles and temporary camera overrides on completion,
cancellation and scene teardown. Effects must not apply damage, alter battle
state, invent outcomes or bypass the event renderer's completion boundary.
`play_effect` is the separate entry point for future non-move 3D effects.
No native move VFX or attack-camera shots are shipped by this foundation.

## Focused checks

- `battle_move_presentation_routes_check.tscn`: one attack, physical/special,
  missing actors, no legacy catalog access, miss callback, cancellation,
  animation-disabled mode and actual 2D fallback.
- `battle_arena_integration_check.gd`: real Dragonite/Roaring Moon models,
  routed attacks, recall/send-out, damage, faint and repeated arena teardown.
- Existing event-order and animation-recovery checks retain shared sequencing.
