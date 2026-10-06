# Primal Kyogre Surf mount

Normal and shiny Kyogre use the approved water-contact treatment: the underside,
flippers and tail fade into the map water, with contact foam and a directional
wake while swimming. Native source scale and the riding pose are retained from
the approved V4 rig. The rider uses the ordinary player origin in all four
directions, with zero mount-specific rider offsets. The builder positions every
mount layer around that fixed player anchor using the authored seat coordinates.

`source.png` remains the unmodified supplied art. Rebuild both color variants
with `python3 tools/build_primal_kyogre_mount.py`. The water depth/palette and
pixel foam are in `tools/primal_kyogre_water_contact.py`. Normal and shiny share
the generated `water_contact.png` sheet: four directions of idle contact on top,
four directions of moving contact/wake below, four 192×320 cells per row.

The underwater foreground is removed from
the base atlas so it is drawn once; the original opaque rider mask remains
separate, keeping player anatomy from showing through a translucent fin.
Source art, inventory icons and relative Surf-fishing offsets are unchanged.
Base, foreground, opaque mask and water contact share the same translation in
every direction. Extra transparent canvas prevents clipping; no art is scaled.
The world/collision position and the relative seat geometry remain unchanged.

`MountWaterContact` is a cached AnimatedSprite2D child of the existing foreground.
Local and remote avatars synchronize its direction and frame with the mount;
there is no independent animation clock. Idle and fishing have contact foam
without a wake. The effect shares the actor world depth and is excluded from
player appearance parts. Dismounting or selecting another mount clears it.
Kyogre uses this contact/wake instead of generic circular Surf-step ripples;
Lapras's ripples and all fishing splashes keep their existing behavior.

The player's ordinary position is the alignment reference, not the nose, fin or
foam edge. Compared with the earlier hull-aligned version, the complete rig moves
51px down in front, 31px at either side and 56px behind. The source animation's
18px torso shift is still compensated, keeping the rider stable while swimming.
Fishing retains its existing pose correction relative to the same saddle.

Runtime captures (both player models, idle/swimming/fishing, all directions):

```
ops/worktrees/slot-env SLOT -- godot --path .worktrees/SLOT/frontend \
  --rendering-method gl_compatibility \
  --script res://tools/preview_primal_kyogre_mount.gd -- \
  --water --output=/absolute/output
```

Add `--shiny` for the shiny variant. The capture restores a fixed 2× magnification
after Store auto-fit; `--water` uses a tile from the game water texture. It is a
runtime render study, not a networked live-map session.
Add `--anchors` for a gold outline of the occupied tile and a cross at its center, plus an unmounted player on the same horizontal line.
Use `--mount=lapras` to compare the same world anchor with Lapras.

Focused checks: `kyogre_water_contact_check`, `primal_kyogre_surf_check`,
`surf_mount_render_check`, `mount_world_depth_check`, `mount_nameplate_check`,
and `store_mount_preview_fit_check`.
