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

Model-only 3D moves do not load or play their 2D move-animation sounds, including
the initial impact pilots. They have no move-specific visual effect to match.
Existing damage, heal, stat-up/down and other common effect sounds remain on
their separate event routes. There is no new generic attack sound. Actual 2D
fallback retains its original move visuals and sounds. Future native move VFX
must explicitly own matching audio inside the 3D move driver's lifetime.

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

## Initial pacing and impact pilot

Desktop 3D physical/special attacks and damage reactions use a presentation
speed of 1.5, separate from replay speed. Idle, sleep, faint and lifecycle clips
retain their existing speed; the reviewed registry's native timing stays intact.
Model-only attacks start without waiting for move audio or its 2D source clock.

`battle_3d_move_timing.gd` initially authors Pikachu Thunderbolt (native impact
frame 48/120), Pikachu Tackle (42/110), and Blastoise Ice Beam (120/407.5).
These markers came from native-pose inspection, not a universal clip percentage.
Profiles require matching species, selected action and reviewed clip length.
Impact timing follows the actual AnimationPlayer position, independently of
audio availability or catalogs. Pause and replay speed continue to affect the
model and the damage/HP boundary together. The prior pilot sound schedule is
not used for the model-only route.

The batch renderer permits an impact boundary only for a single, targeted,
direct HP-loss event preceded solely by critical/effectiveness metadata. Misses,
charge turns, spread/multi-hit, substitutions and other intervening events keep
the complete ordered route. At impact the move releases those ordered events;
the damage event presents HP at the start of the reaction and awaits both the
target reaction and attacker recovery before advancing. Non-PvP banter is held
until that recovery finishes. Server state and render cursors still advance
through the existing event renderer; audio never generates damage. 2D retains
its original HP-after-reaction behavior and message waits.

Unreviewed 3D moves await the complete native attack clip without any extra
move-audio completion boundary. This is an initial timing pass without move VFX;
Blastoise's complete Ice Beam recovery still takes about 4.53 seconds at 1.5×.

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
- `battle_3d_impact_pacing_check.tscn`: real native action clocks with canonical
  clip lengths, all three silent pilot impact/recovery boundaries, an unreviewed
  move, pause/replay speed, shared damage/heal/stat sounds, cancellation,
  eligibility and 2D HP ordering.
