# Lower object depth

Viridian City's lanterns and jail side posts split their artwork between
`StructureTop` and `StructureBottom`. The top groups use world depth, while
the bottom layer kept a fixed low Z. Large mounted silhouettes could therefore
disappear behind a lamp or cage while still covering its lower shaft or foot.

`object_lower_depth_sorting.gd` recognizes the complete five-tile lantern/post
family using exact RGBA hashes. It moves only the two lower tiles to the
existing upper group's absolute depth. Lower parts still draw before upper
overlays at equal Z, including the jail bars. The upper boundary, actor depth,
collision rules, steps, paving and other object artwork are preserved.

The helper accepts `ObjectsBottom`, `ObjectBottom`, spaced variants, `Objects`
and the existing structure-bottom names. Recognition depends on complete
matching artwork, not the layer name alone. Unknown, incomplete, flipped,
unaligned, hidden or ambiguous patterns remain on their original layer.

Trees and object posts share `lower_visual_depth_sorting.gd` for matching,
layer settings and draw order. Their supported families and generated-layer
metadata remain separate. The evergreen hashes and tree coverage are unchanged.

## Validation

- `object_lower_depth_check`: layer aliases, complete posts, both jail sides,
  overlapping bars, preserved stairs/grass, transforms, material/animation
  resources, repeat calls and unsupported/ambiguous cases.
- Eight existing focused checks passed: `tree_lower_depth_check`,
  `mount_world_depth_check`, `rayquaza_mount_check`,
  `viridian_visual_jail_check`, `players_house_visual_depth_check`,
  `tall_grass_character_depth_check`, `viridian_forest_depth_order_check`
  and `map_depth_lookup_check`.
- Audited initial and repeated world normalization across 89 generated visual
  scenes. There are 123 complete supported posts in nine scenes, moving 246
  lower cells. All visual cells, source depth/transform/material settings and
  unrelated layers are preserved. The existing tree correction still covers
  20,672 lower cells.
- Viridian City has 18 matching posts, including both jail sides. Its 36 lower
  post cells are corrected; the jail's walkable cells `(47,44)`, `(47,45)`,
  `(45,45)` and `(52,45)` remain in the original bottom layer.
- Compared 1,024 before/after render pairs with local and remote shiny
  Rayquaza and Shadow Lugia. Samples cover four walk frames, four facings,
  hover phases, walkable tile centers and between-tile positions near lanterns
  and the jail, under day and night lighting. Map materials/animations were
  frozen for deterministic comparison. Scenery-only renders at those sample
  positions are pixel-identical before and after in both lighting states.
  The changed mounted pixels show the shafts/feet covering silhouettes that
  previously protruded through them. Actor ground Z stays unchanged.

This is a correction for the explicitly supported post artwork. It does not
raise entire mixed bottom layers or certify every other object family. Full
release verification and deployment are separate from these focused checks.
