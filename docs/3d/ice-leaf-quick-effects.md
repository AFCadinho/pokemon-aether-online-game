# Ice Beam, Razor Leaf and Quick Attack

Implemented in normal 3D battles; **all three visually approved by the user**.
Thunder Shock was approved before this batch.

| Move | Inspected SV source | Authored 3D presentation |
| --- | --- | --- |
| Ice Beam | `ew0058`, seven containers / 47 emitters | Textured blue-white beam, small faceted ice shards and a confirmed-hit burst |
| Razor Leaf | `ew0075`, two containers / 11 emitters | Six curved, tumbling leaves on fan trajectories and a green contact burst |
| Quick Attack | `ew0098`, four containers / 14 emitters | Fast body approach, crossed speed ribbons and a brief impact ring |

These reuse source textures; Godot authors geometry, choreography, colors and
timing. Native particle simulation, shaders and timelines are not converted.
The eleven packaged PNGs and their particle/PNG hashes live in `sv_icebeam`,
`sv_razorleaf` and `sv_quickattack` under `assets/battles/moves_3d`.
There is no runtime dependency on the local dump or extraction tools.

Ice Beam uses mouth attachments, or both cannon bones for Blastoise. Its guarded
Blastoise/shiny pilot uses launch frame 60 and impact 120 of the 407.5-frame
special clip. It follows the supported-move 1.25-second cap. Shards are temporary
move artwork and never imply or apply the Freeze status.

Razor Leaf uses the special-attack release clip despite being a physical damage
move. Leaves start at the body, stay in world space during camera orbit and
converge at the original target position. Quick Attack uses the physical clip,
a later, faster approach and a maximum 0.8-second action. Its guarded Pikachu
pilot launches at frame 12 and impacts at 42 of 110. Contact movement preserves
the existing clearance, grounded height, fixed HUD, dodge aim and return rules.
Other rigs retain generic native-clock timings and bounds-based attachment
fallbacks when there is no reviewed anatomical profile.

All three reuse existing 2D move sounds. Ice Beam and Quick Attack play their
sample at launch; Razor Leaf plays Leaf1 at launch and Leaf2 at impact. Damage
outcomes and HP remain owned by the battle event router. Hit-only bursts are
suppressed on miss/block; missed moves aim normally while the target dodges.
Pause and cancellation use the existing shared native clock and lifecycle.

## Preview

From the workspace root, with slot-b assigned:

```sh
ops/worktrees/slot-env slot-b -- godot --path .worktrees/slot-b/frontend \
  --script res://tests/ice_leaf_quick_preview.gd -- --moves
```

Ice Beam with Blastoise starts selected. Use Razor Leaf with Bulbasaur and Quick
Attack with Pikachu for the other examples. Existing outcome, direction, arena,
camera, pause and cancellation controls remain available.
`--smoke-ice-leaf-quick` exercises all three examples in both directions and
three outcomes; `POKEAETHER_STAGE_OUTPUT` optionally captures screenshots.

## Extraction and focused checks

Use `extract_sv_ember.py --move icebeam|razorleaf|quickattack` with the respective
`ew0058`, `ew0075`, `ew0098` source folder. The existing BC3/BC5 decoder is opted
in for these moves and existing BC7 support for Ice Beam. No new format decoder
or native source mutation is introduced. The external decoder and remaining
arguments are described in [source move effects](source-move-effects.md).
`package_sv_fire_bubbles.py --source EXTRACTED_MOVE --output DESTINATION` now
also supports these three bounded selections.

- `test_ice_leaf_quick_sources.py --source SV_BATTLE_EW --extracted EXTRACTED_ROOT`:
  inspected emitter counts, source immutability and reproducible packaged PNGs.
- `test_fire_bubble_sources.py`: existing format guards and packaging regression.
- `ice_leaf_quick_3d_check.tscn`: outcomes, paired origins, bounded pools, fixed
  world positions on paused orbit, audio, attachment policy and impact bridge.
- `contact_move_effects_3d_check.tscn`: four contact moves across four actor slots,
  approach, dodge, grounded return, pause, Substitute and cancellation.
- `battle_move_effects_3d_check.tscn`: thirteen routes, four slots, audio and lifecycle.
- Impact pacing, 2D/native routing and approved Ember/Water Gun regression checks.
- Rendered preview: real models, both directions, all outcomes, paused orbit,
  original dodge aim and cancellation.
