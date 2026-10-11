# Animated move attachment points

`move_attachments_3d.gd` maps a move to an anatomical part, then resolves a
species/form profile to one or more bone-local offsets. This is independent of
the move's damage category: Bite and Ember can both use a mouth, while Scratch
uses a hand. Physical hit graphics still appear at the target. Tackle, Scratch, Bite and Quick Attack now
use a separate [contact approach](contact-move-effects.md) to move the attacker
to the target and back on the same native action clock.

## Profiles and review status

The expanded registry is `data/battle_move_attachments_3d.json`. Each form has
its own `parts`; shiny variants share the matching form's rig coordinates.
The original profiles below remain available when no calibrated replacement
exists. The per-form [review ledger](attack-attachment-review.json) records
sampled marker reviews, model hashes, unresolved parts and actual effect reviews.
Its `complete: false` means the individual review of all attack animations is
still in progress. Coverage means a point is configured, not that every move
has been visually approved.

An outer array describes separate emitters. Each emitter's inner array contains
weighted bone-local points, allowing a mouth origin to follow both moving lips.
`actions` can override parts for a particular native clip; `moves` selects a
part for an individual move and `move_actions` selects its native attack clip.
Snivy's Vine Whip uses both animated vine tips and `physical_attack_2`.
Servine uses that same action name with its own measured tip offsets; Serperior
uses `physical_attack`. Magmortar's Ember and Flamethrower use the right cannon
opening, independently of its claw contact points and mouth.
The first point in an emitter group may specify `visible_mesh`, an exact
actor-relative mesh path. The group emits only while that mesh is visible.
This supports rigs that replace a closed muzzle with a separate open muzzle;
each surface can use its own calibrated skin influences. Missing or freed
predicate meshes invalidate the attachment and retain the bounds fallback.
Mega Golurk also uses separate anchors for its attached hands and detached
rocket fists, selected by the visibility of their respective meshes.

Sound-call and sound-tunnel effects charge at every configured mouth, then retain
each mouth’s release position for the traveling waves. Moving a head after launch
does not pull the released waves around; multiple mouths still produce one target
impact. Doduo uses separately measured upper/lower bill points for its two mouths
and upper-bill tips for Peck. Its sampled Peck approach still leaves a contact
gap, recorded explicitly in the review ledger.

Per-move `move_choreography` applies only when the selected native `action`
matches. It supplies `launch_fraction`, `impact_fraction`, optional
`emission_end_fraction` and optional `contact_yaw_degrees`. Emission end stops
source streams and particles; target impact graphics retain their own lifetime.
The fire, ice, Flash Cannon, staged-beam and Water Gun presenters consume that end marker.
Unspecified values retain their existing move timing.

Fire, ice, Flash Cannon, staged beams and Water Gun accept `emission_scale` (positive, at
most 4). It adjusts the source stream width, muzzle and traveling particles;
endpoints and target impact sizes remain unchanged. Water Gun additionally
accepts `water_stream_arc_height` (0–4 world units).
The Water Gun arc is a parabola with fixed source and target endpoints. Stunfisk uses
these settings with an individually selected early native pose so its upward
mouth can emit a narrow stream clear of its body. These settings belong to the
exact form and move; a visible Substitute does not inherit them.

Mud-Slap accepts `emission_scale` and `projectile_arc_height` (0–4 world units).
Its projectile and trail use a sinusoidal arc with fixed endpoints; the default
height remains 1.8. Rolycoly uses .05 so the projectile leaves its low wheel
source without immediately rising through its body. Target impact size remains
unchanged. Other staged projectiles retain their existing arc.

The [full catalog coverage audit](move-attachment-coverage.md) lists every
supported species/form and distinguishes configured attachments from bounds
fallbacks. Rerun it after changing profiles or admitting additional models.

| Model | Move/part | Bone(s) |
| --- | --- | --- |
| Pikachu | Thunder Shock, Thunderbolt / electric body | `spine_02` |
| Charmander | Ember, Flamethrower, Water Gun, Bubble, Bubble Beam, Ice Beam, Bite / mouth | `head` |
| Charmander | Scratch / hand | `right_hand` |
| Charmeleon | Flamethrower and other mouth moves / mouth | `head` |
| Squirtle | Ember, Flamethrower, Water Gun, Bubble, Bubble Beam, Ice Beam, Bite / mouth | `head` |
| Blastoise | Water Gun, Bubble Beam, Ice Beam, Flash Cannon / cannons | `left_feeler_b_02`, `right_feeler_b_02` |
| Blastoise | Ember, Flamethrower, Bubble, Bite / mouth | `head` |

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

Charmeleon's mouth uses head-local `(-0.015, 0, 0.235)`, calibrated against
the native special-attack pose and the lip geometry in skin bind space. This
also applies to shiny Charmeleon. Previously its mouth moves used 82% of the
idle bounds height, which did not follow the head during attacks, including
the player's Flamethrower in NPC battles.

Bindings are cached on each model instance; skeleton references are weak.
Each sample reads the current bone pose and applies skeleton/global/world
transforms. Replacing the model drops its cache, with no global references to
old actors. Both effects run after the stage's actor/camera update. Two cannon
origins remain one logical effect with one clock, one impact and one audio plan.
Target impact positioning retains the existing bounds calculation.

## Offline review

For the catalog-wide review, use the assigned task slot and an approved local
runtime catalog. The tools read those scenes without modifying them:

- `tools/sprite_factory/inspect_attack_attachments.gd`: inventory of bones,
  native attack clips and skin-bind geometry for each form.
- `attack_attachment_candidates.gd`: unapproved attachment proposals.
- `attack_attachment_preview.gd`: individual marker sheets for idle and every
  native attack clip at 20%, 45% and 65%, plus a second view at 45%.
- `calibrate_attack_attachment.py` and `fit_attack_attachment.py`: recorded
  anatomical pixel measurements to bone-local offsets; their output still
  requires rendering and visual review.
- `project_attack_attachment_landmarks.gd`: projects selected surface pixels onto
  captured visible skinned triangles and combines their bone influences. Use
  fresh forward-sampled captures and inspect the chosen mesh/triangle before
  approving a new marker sheet. Active blend shapes are rejected. Transparent
  texture regions and material displacement are not resolved by this geometry
  projection; they still require anatomical review.
- `attack_attachment_pose.gd`: samples each pose by advancing from the start.
  This preserves discrete mesh visibility when returning to the same pose for
  another camera. Older sheets could show a closed mouth in the side view after
  seeking backwards. `audit_attack_attachment_pose_visibility.gd` identifies
  affected captures; these require a fresh visual review.
- `attack_attachment_move_preview.gd`: actual stage anchors and move effects
  with native animation and contact movement. These are offline captures;
  they do not certify live wild or NPC battle presentation. `--camera-frame both`
  frames the entire source-to-target trajectory; the default remains a source
  closeup. `--fractions` selects up to eight native clip fractions.
  `--target-species pikachu` uses a separately approved opponent model to
  inspect a different target height or avoid the opponent obscuring the source.
  It records both runtime revisions and adds `-vs-SPECIES` to the output name;
  omitting it preserves the same-species comparison.
  `--hide-effects` preserves the native pose and contact movement while hiding
  the effect art, so a large hit graphic cannot conceal an approach gap.
  The capture records `effects_hidden`; this mode does not validate the VFX.
  `--neutral-reflections` adds a neutral sky reflection for inspecting metallic
  surfaces and records `neutral_reflections`. It preserves authored materials
  and is an offline review option; it does not change production lighting.
- `check_calibrated_move_attachments.gd`: binding and finite-coordinate checks
  at 21 moments per native clip, including normal/shiny consistency.
  Inspect the engine log as well as the JSON result. The checker retains active
  mesh/material resources until mesh instances have been freed and a frame has
  elapsed. This fixes the reproduced Diglett, Alolan Diglett and Pineco
  null-material cleanup errors (six-model headless and twenty-model GPU focused
  checks). A clean binding report alone still does not certify rendering or
  visual placement.
- `tools/audit_move_attachment_learnsets.gd`: supported move/part coverage
  against local learnsets, including moves still using bounds fallbacks. Each
  move also records the actual stage-selected native clip and whether that
  clip has a configured attachment. This identifies routes that use hidden
  body parts; the report does not visually approve those routes.

Marker sheets deliberately draw markers over the model, including transparent
surfaces. An obscured anatomical surface requires another camera view before
approval. Always inspect both views: a frontal overlap alone cannot establish
the depth of an attachment. Store approved coordinates and their review evidence
in the registry, then refresh the review ledger and coverage audit. Never install
an entire proposal directory solely because it passes the binding checks.

The calibration math checks can be run with
`python3 tools/sprite_factory/test_attack_attachment_calibration.py`.
`check_attack_attachment_pose.gd` checks repeated discrete-visibility sampling
and ray/triangle projection.
All Godot commands must run through the assigned slot's `slot-env` wrapper.

The original interactive preview is also available. For example, from the
workspace root when slot-b is assigned to the task:

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

The [fourth source batch](source-move-batch-four.md) reuses the existing mouth
profiles for Shadow Ball, Sludge Bomb, Poison Sting, Flash Cannon and Water Pulse.
Flash Cannon uses Blastoise's paired cannons. Released projectiles keep their
launch point; the continuous cannon beam follows the current bones.
