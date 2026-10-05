# Source-textured battle moves: Ember and Water Gun

## Review status

- **Ember: visually approved by the user and enabled in normal 3D battles.**
  Uses the same masks, first sampled colors, sizes, atlas frames, travel and
  impact layout as the approved `da06b8d89` pilot.
- **Water Gun: visually approved by the user and enabled in normal 3D battles.**
  Uses the same source-textured recipe reviewed in the offline preview.
- **Tackle, Scratch and Bite: visually approved by the user.** See
  [contact move effects](contact-move-effects.md) for sources and conversion limits.
- **Thunder Shock: implemented, awaiting visual approval.** See
  [Thunder Shock](thundershock.md) for sources, timing and review.
- **Thunderbolt: visually approved by the user.** See
  [Thunderbolt](thunderbolt.md) for source ribbons, sound timing and review.
- **Flamethrower, Bubble and Bubble Beam: visually approved by the user.**
  See [fire and bubble effects](fire-bubble-effects.md) for source reuse and review.

`experimental_battle_3d.gd` selects `SourceMoveEffect` for Ember and Water Gun. This class
inherits the normal move driver, so model clocks, audio routing, target guards,
miss/blocked outcomes, impact/recovery and cancellation remain shared. It draws
into the driver's existing mesh pool instead of running a second visual clock.
Its process priority follows the arena camera update, including during pause.
Misses use the same aim as hits; the target performs a native 3D dodge.
The original aim is held fixed while the target moves.

Eight PNGs totaling 287,582 bytes are tracked under
`assets/battles/moves_3d/sv_source`. Resources use `preload`, so the normal path
uses Godot's import/export dependency tracking. No game runtime path points to
Documents, a ROMFS, `.tmp`, a local manifest, or the offline extractor. See
`provenance.json` for source particle and PNG SHA-256 hashes. The duplicate
Ember muzzle/hit `cpt_2_fire0005` masks were checked pixel-for-pixel before sharing.

## What Water Gun reuses

The three `ew0055` files provide 23 emitters: muzzle 2, shot 13, hit 8. There are
30 texture entries across the three containers, with duplicates. The extractor
now explicitly supports the inspected BC5 swizzles alongside Ember's BC4 masks:

- BC4 R/R/R/R remains a single-channel PNG mask sampled from red.
- BC5 R/R/R/G becomes an RGBA PNG with independent source opacity in alpha.
- BC5 R/G/G/G preserves the same channel selection in RGBA for inspection.

The packaged water subset uses the source foam/particle atlas, splash atlas
and scrolling noise mask. The Godot implementation authors the beam geometry,
travel, particle placement, timing, normalized water palette and blending.
These are **source-textured reconstructions**, not complete native SV effect
playback. Native emitter simulation, compiled shaders, attachment/bone rules
and TR TML timeline semantics remain outside the converted subset.

## Review

From the control root in the assigned slot:

```bash
ops/worktrees/slot-env slot-b -- godot \
  --path .worktrees/slot-b/frontend \
  --script res://tests/source_moves_preview.gd -- --moves
```

Water Gun is selected initially; choose Ember to inspect the normal live
implementation. **Bronmateriaal** toggles the next playback between the new
look and the old procedural look. Both moves use the production renderer by
default; disabling the toggle compares against their old look. Overrides share the
original clock and are removed when the original effect exits.

Hit/miss/blocked, direction, models, arena, camera orbit, pause and cancellation
remain available. `tests/ember_sv_preview.gd -- --moves` is a compatibility entry
point selecting Ember; its old `--sv-source` argument is no longer needed.

## Extraction and packaging

The Ember commands are recorded in `ember-sv-effect-pilot.md`. For Water Gun,
use the same external pinned BNTX-Extractor checkout:

```bash
python3 tools/battle_effects/extract_sv_ember.py --move watergun \
  --source '/home/adinho/Documents/3d_models/SV Every File/romfs/effect/battle_ew/ew0055' \
  --output ../.tmp/watergun-sv-pilot \
  --bntx-extractor ../.tmp/ember-sv-source/bntx_extract.py

python3 tools/battle_effects/package_sv_move_textures.py \
  --ember ../.tmp/ember-sv-pilot --watergun ../.tmp/watergun-sv-pilot \
  --output assets/battles/moves_3d/sv_source
```

Extraction refuses an existing output directory and never modifies the dump.
Packaging deliberately regenerates only the eight allowlisted PNGs and their
provenance file. Imported caches remain slot-local.

## Focused checks

- `tools/battle_effects/test_extract_sv_ember.py --source EMBER_DIR --watergun WATERGUN_DIR`:
  Ember's 18 malformed-input rejections and named bindings; Water Gun's three
  containers/23 emitters and explicit BC5 opt-in.
- `source_move_effects_3d_check.tscn -- --legacy-source=EXTRACTED_EMBER_DIR`:
  both moves and three outcomes, bounded geometry, exact approved Ember
  placement/count/frame/opacity/tint parity over six timestamps, adjusting the
  historical pilot to use the newly requested on-target miss aim. The external
  argument is optional and only used for comparison with the historical pilot.
- `battle_move_effects_3d_check.tscn`: ten moves, four slots, audio, impact,
  Substitute, cancellation and explicit live-source routing for both approved moves.
- `battle_move_presentation_routes_check.tscn`: ordinary routes and 2D fallback.
- `battle_3d_impact_pacing_check.tscn`: impact recovery, gem-before-attack and faint.
- `source_moves_preview.gd -- --moves --smoke-source-moves`: rendered Dragonite/
  Pikachu, both directions, three outcomes, orbit-facing quads during pause,
  comparison toggles, cancellation and cleanup. Screenshots use the optional
  `POKEAETHER_STAGE_OUTPUT` directory. Flight/impact screenshots inspected.

Anatomical origins now use the [move attachment profiles](move-attachments.md)
for Charmander, Squirtle and Blastoise. Other models retain bounds-based origins.
Both Water Gun renderers support paired cannon origins. The approved source-textured
version is now also selected by normal battles.
