# Fourth source move batch: ten ranged moves

Implemented in normal 3D battles. **Visual approval pending for all ten.**
The previous thirteen moves retain their approved effects.

| Move | Own SV source | Inspected emitters | Presentation |
| --- | --- | ---: | --- |
| Shadow Ball | `ew0247`, 4 containers | 20 | Dark textured orb, rotating violet rings and a short trail |
| Sludge Bomb | `ew0188`, 3 containers | 15 | Wobbling sludge on an arcing path, falling droplets and a splash |
| Focus Blast | `ew0411`, 4 containers | 34 | Cyan energy sphere with gold rings and an impact flash |
| Moonblast | `ew0585`, 5 containers | 33 | Brief source moon during charge, lilac orb and sparkles |
| Ice Shard | `ew0420`, 2 containers | 11 | Three faceted 3D crystals and a short ice burst |
| Poison Sting | `ew0040`, 3 containers | 12 | Five thin 3D needles with the source streak atlas and poison impact |
| Swift | `ew0129`, 3 containers | 17 | Five rotating extruded stars on fan trajectories |
| Flash Cannon | `ew0430`, 4 containers | 33 | Silver-blue source-textured beam, traveling rings and metallic impact |
| Magical Leaf | `ew0345`, 3 containers | 26 | Curved source-textured leaves with pastel highlights on spiral paths |
| Water Pulse | `ew0352`, 3 containers | 22 | Three expanding 3D water rings with bubbles and a brief splash |

## Source reuse and limits

All ten have existing 2D catalog entries and their own inspected SV dump files.
The subset contains 223 emitters across 34 particle containers. Thirty-six PNGs
are packaged under `assets/battles/moves_3d/sv_<move>`, each with particle-source
and PNG SHA-256 provenance. Runtime uses only those packaged textures.

This is **source-textured reconstruction**, not complete native SV playback.
Godot authors the geometry, paths, palettes, timing and shading; native particle
simulation, compiled materials and timelines remain unconverted. For example,
Swift uses an authored extruded star mesh with its source star/blur masks, and
Ice Shard uses an authored faceted mesh with its source ice mask. The selected
flow textures supply moving surface detail; effect colors are authored using
the inspected source palettes as reference. Atlas frame counts and independent
alpha channels were inspected before using them.

`tools/battle_effects/sv_batch_four.py` holds the exact particle, texture and
format allowlists. The existing decoder supports these BC4, BC5, BC7, BC3 and
R8 variants; no new format decoder is introduced. Unsupported formats/swizzles
still fail closed. Extraction and packaging do not modify the dump.

## Runtime behavior

- All ten use ranged release clips. Physical damage classification does not
  cause Ice Shard or Poison Sting to approach as contact attacks.
- Existing mouth profiles apply to Shadow Ball, Sludge Bomb, Poison Sting,
  Flash Cannon and Water Pulse. Blastoise's Flash Cannon uses both animated
  cannon bones, with the 407.5-frame special-attack pilot: launch 60, impact 120.
  Normal/shiny share that profile; unsupported rigs and Substitutes use bounds.
- Focus Blast, Moonblast, Ice Shard, Swift and Magical Leaf use body origins.
  Released projectiles hold their launch position; subsequent head movement
  cannot drag them. Flash Cannon continuously follows its emitting bones.
- Geometry, audio and impact share the native action clock. The existing
  supported-move cap of 1.25 seconds remains in place. No wall-clock shader
  `TIME`, random placement per frame or independent particle timer is used.
- All ten reuse their current 2D sounds. Shadow Ball, Sludge Bomb, Moonblast,
  Swift, Magical Leaf and Water Pulse have separate launch and impact samples;
  the other four have one launch sample. The 2D catalog is unchanged.
- Confirmed-hit geometry requires battle outcome evidence. Misses retain the
  original aim while the target dodges. This does not alter accuracy rules;
  forced misses for Swift/Magical Leaf exist only in the offline harness.
- No move effect applies persistent Poison/Freeze or changes HP. Existing
  event routes own statuses, damage, recovery, cancellation and replacement.

## Review

From the control root, with slot-b assigned:

```sh
ops/worktrees/slot-env slot-b -- godot --path .worktrees/slot-b/frontend \
  --script res://tests/batch_four_moves_preview.gd -- --moves
```

Shadow Ball starts selected. **Vorige nieuwe move** / **Volgende nieuwe move**
cycle through these ten, selecting Blastoise for Flash Cannon, Bulbasaur for
Magical Leaf and Squirtle for Water Pulse. The ordinary model/move selectors,
outcome, direction, camera, pause, arena and cancellation controls remain.
`--smoke-batch-four` renders all sixty move/direction/outcome combinations.
`POKEAETHER_STAGE_OUTPUT` optionally captures flight/impact screenshots.

## Extraction and focused checks

Use the existing `extract_sv_ember.py` CLI with the move key above and its
corresponding SV folder; supply a new output directory and the external pinned
BNTX extractor described in [source move effects](source-move-effects.md).
`package_sv_fire_bubbles.py --source EXTRACTED_MOVE --output DESTINATION` also
supports this fourth allowlist.

- `test_batch_four_sources.py --source SV_BATTLE_EW --extracted EXTRACTED_ROOT`:
  all ten emitter counts, unchanged source hashes, invalid-format/swizzle
  rejection and byte-identical regeneration of every packaged PNG/provenance.
- `batch_four_moves_3d_check.tscn`: ten moves, three outcomes, single/paired
  origins, bounded pools, no false impacts, paused orbit, stable launch points,
  correct ranged release selection, shared audio and damage/recovery.
- `battle_move_effects_3d_check.tscn`: all 23 supported moves across four slots,
  dedicated renderer selection, audio cues, Substitute and cancellation guards.
- Existing 2D/native presentation routing and approved Ember/Water Gun plus
  Ice Beam/Razor Leaf/Quick Attack regression checks.
- Rendered batch smoke: both directions, all three outcomes, anatomical cannon/
  mouth examples, orbit-facing sprites, pause, fixed dodge aim and cleanup.
