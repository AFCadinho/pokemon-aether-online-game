# Viridian jail depth correction — 23 October 2026

The rear jail wall was split between `TreeBottom` and `StructureTop`. Its upper
edge was connected to the front wall, so it inherited the front wall's depth,
while the lower middle bars always drew below actors. Large mounts exposed both
problems. Actor ground-depth and mount/rider ordering remain unchanged.

The artist source now contains complete `JailBack`, `JailFront`, and `JailPosts`
assemblies with `pao_depth_sort=groups`. `JailSides` uses `pao_depth_sort=rows` so
its vertical rails do not join the two wall boundaries. The visual importer
retains this metadata; world normalization uses it without reserved layer names.
Existing layers without the hint retain their previous sorting behavior.

The rear wall sorts at world Y 1248 and the front wall/posts at Y 1440 when the
map is at the origin. Side rows sort at their individual bottom edges. These
are visual anchors, not prescribed blocked/open tiles. No gameplay scene,
Collision layer, movement, mount asset, backend, or release configuration changed.

## Source and generated output

Edited source:
`/home/adinho/Documents/tiled_pokeaether/kanto/artist/exterior/towns/Viridian City.tmx`

Backup:
`/home/adinho/Documents/tiled_pokeaether/kanto/artist/backups/viridian-jail-depth-20261023/Viridian City.tmx`

The artist directory is not a Git repository. The exact source edit is retained
in [viridian-jail-depth-source.patch](viridian-jail-depth-source.patch).

- Before SHA-256: `75173e8f3a989ce4a33a5fd5b52037bd791bad3ad05a2e88c25b0d02fa07332a`
- After SHA-256: `c1047e20bfbae0eae2c330cc31633bf5a917b79679d8b3cbb7926f973f2f666b`

52 visual tiles moved between layers; none were added, deleted, or repositioned.
The full-map native Tiled renders before and after have identical pixels.

A full standard reimport was tested and rejected: existing Godot tree animations
are not present in the artist TMX, so rebuilding the atlas removed those native
animations. The final generated scene instead uses
`tools/update_viridian_jail_layers.gd` to apply precisely the same layer split to
the existing imported tile identities. All original atlas and TileSet files are
unchanged. The tool is a one-time migration for the pre-split visual and is a
no-op once the layers exist. Future full imports still need to preserve the
project's native animation additions; this task does not rebuild that pipeline.

From `game/`, after applying the paired TMX edit:

```sh
ops/worktrees/slot-env slot-b -- godot --headless --path .worktrees/slot-b/frontend --script res://tools/update_viridian_jail_layers.gd
```

## Verification

Passed:

- Artist `mapping/tools/audit_maps.py`: finite CSV layout, GIDs, dependencies,
  animation references, and all 11 layers.
- `viridian_visual_jail_check`: independent front/rear boundaries, row sorting,
  complete posts, preserved tile identity, translated synthetic fixture,
  repeated normalization, and legacy fallback.
- `tmx_visual_importer_check`: both depth hints survive actual TMX import.
- `mount_world_depth_check`, `object_lower_depth_check`, `tree_lower_depth_check`,
  `viridian_forest_depth_order_check`, and `map_depth_lookup_check`.
- `tools/check_viridian_jail_repartition.gd -- <previous frontend checkout>`:
  all 9,917 visual tile occurrences retain their pixels and animation timelines;
  1,216 unique frames per version compared, with compact/lossless atlas checks.
- Native `viridian_jail_render_check` (OpenGL compatibility, real display):
  192 comparisons covering local/remote actors, walking/Zekrom/Rayquaza,
  four directions, walk frames 0 and 2, and both sides of both walls. Hover is
  sampled for mounts. Each wall crop matches independently forced correct
  ordering and differs from deliberately reversed ordering, proving visible
  actor/wall overlap in every case. The test disables actor cameras and pauses
  sprite processing while comparing each pose; unrelated scenery animation is
  excluded by the wall crop.

![Local player and Zekrom on both sides of both walls](evidence/viridian-jail-depth.png)

Tests ran through `slot-env slot-b`; logs and full native screenshots remain in
that slot's `.runtime` directory. Existing battle texture UID warnings fall back
to their valid text paths. No full release gate, multiplayer server playtest,
push, deployment, or main-branch merge was performed.
