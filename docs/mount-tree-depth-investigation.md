# Mount/tree depth investigation

Investigated on 2026-10-06 against frontend development
`369b38b1261cbf42c38e7c1bfbfb03d8de6d8f78`. This report records a scratch
prototype and focused checks; it does not introduce a gameplay correction.

## Cause and unsafe approaches

Viridian City's `TreeBottom` visual layer stays at relative Z 2. Its tree
crowns live in `StructureTop`, which world normalization splits into connected
groups with absolute depth. A southern group has Z 2051. An actor at ground
Z 2032 therefore renders behind that crown but ahead of the lower tree pixels.
Large mounts make this split visible. Mount and rider already share ground
depth, and hovering does not change that depth.

Moving the entire bottom layer is unsuitable: Viridian City's bottom layers
also contain other details, and Route 22 mixes 253 grass cells into
`TreeBottom`. Rebuilding every tree around a new ground-depth boundary would
also change existing crown occlusion. Some current crown groups are large:
Viridian City's eastern group spans rows 16–63, while another southern group
spans rows 40–63. These groups cannot be treated as individual trees.

## Narrower correction tested

The prototype recognized complete examples of the existing two-column,
four-row evergreen artwork. Only its four lower cells moved to replacement
layers, using the **existing corresponding crown group's depth**. Original
crown cells, crown boundaries, unrelated bottom cells, grass rows and actor
sorting remained unchanged.

Replacement bottom layers must render before the crown groups at equal Z.
An initial prototype appended them after the crowns, which changed how
vertically overlapping trees cover one another. Inserting the lower layers
before the crown groups removed that background regression.

Recognition in this experiment used exact tile-image signatures and a
complete eight-cell pattern. This is a diagnostic scope restriction, not an
implementation contract for every tree type. A production correction should
identify supported tree families explicitly, preserve the original layer's
render properties, and leave incomplete or ambiguous patterns unchanged.

## Evidence

- Audited the 89 generated visual scenes. The complete evergreen pattern was
  present in 24 of them.
- Checked the candidate on those 24 scenes plus Viridian Forest and Cerulean
  City: 5,169 complete trees and 20,676 moved cells. No cells were lost or
  duplicated; original layer properties and all remaining original cells
  were preserved. Crown, grass and other non-bottom layers were unchanged.
- Viridian City: 329 trees, 1,316 lower cells, 10 replacement depth layers.
- Route 22: all 253 legacy grass cells remained in their existing grass depth
  rows. Its 135 recognized trees were handled separately.
- Viridian Forest and Cerulean City had no matching complete pattern, so the
  prototype made no changes there. This does not certify other tree artwork.

Rendered comparisons used real Godot local/remote avatar rigs at eight
collision-free tile centers near the southern Viridian City trees, with four
facings per case. Static map materials and atlas animations were frozen to
exclude unrelated time-dependent pixels. The main matrix compared 448
before/after pairs:

| Subject | Pairs | Changed pairs |
| --- | ---: | ---: |
| Local player on foot | 32 | 0 |
| Remote player on foot | 32 | 0 |
| Pikachu follower | 32 | 0 |
| Rayquaza, local / remote | 32 / 32 | 10 / 10 |
| Shiny Rayquaza, local / remote | 32 / 32 | 10 / 10 |
| Shadow Lugia, local / remote | 32 / 32 | 8 / 8 |
| Primal Kyogre, local / remote | 32 / 32 | 8 / 8 |
| Cyclizar, local / remote | 32 / 32 | 2 / 2 |
| NPC artwork at ground depth | 32 | 1 |

The changed Rayquaza samples remove pixels protruding through the lower
foliage. This also affects other mounts where their silhouettes intersect the
same tree pixels; it is not specific to Rayquaza's sprite size.

The NPC difference was then repeated with the actual initialized
`DialogueNPC` scene and its normal depth calculation: 1 of 32 pairs changed.
At `(1456, 2032)`, facing left, 16 pixels along the sprite's right edge become
covered by the adjacent tree's lower foliage. Inspection shows the same
occlusion correction, rather than a changed actor depth or missing sprite.
Nevertheless, a map-layer correction necessarily applies to NPCs too.

Six existing focused checks passed on the unchanged gameplay source:
`mount_world_depth_check`, `rayquaza_mount_check`,
`tall_grass_character_depth_check`, `viridian_forest_depth_order_check`,
`map_depth_lookup_check`, and `mount_switch_rider_check`. These establish the
baseline; the scratch candidate was validated separately as described above.

## Recommendation and limits

Extend supported tree lower parts to their existing crown depth, preserving
the bottom-before-crown tie order. Keep changes to tree identification and
map visuals; avoid changing mount depth, collision, grass sorting, or the
existing crown-group boundaries as part of this correction.

The investigation supports this narrower approach but is not release
certification. The render matrix sampled idle poses, one follower species,
one NPC appearance and one area. Moving frames, interpolation, all cosmetic
combinations, transformed layers and other tree families still need relevant
checks when a production implementation is made. No runtime fix, promotion,
push or deployment was performed during this investigation.

## Implemented correction

The follow-up implementation adds `scripts/world/tree_lower_depth_sorting.gd`
to world normalization after each crown layer's final depth groups are built.
It explicitly supports the investigated evergreen family using eight RGBA
artwork hashes. It does not instantiate a reference map or depend on map GIDs
at runtime. Tile identification and image caches last only for the current
construction pass.

Only complete, unflipped trees with an aligned, unambiguous bottom layer and
one shared crown depth group are moved. Lower layers retain the original
layer settings and shared tile/animation resources and draw before the crown
groups at equal depth. Existing actor depth, crown boundaries, grass cells
and collision rules are unchanged.

The production helper and initial/repeated normalization were checked on the
same 26 maps. They move 20,672 cells from 5,168 supported trees, preserving
all visual cells. Compared with the scratch prototype, one tree at `(22, 57)`
on Route 2 is deliberately excluded: its crown is duplicated in `Objects`,
so ownership is ambiguous. Viridian City still corrects all 329 recognized
trees. Viridian Forest and Cerulean City's other artwork remains unchanged.

The seven focused checks pass, including the new `tree_lower_depth_check`.
It covers mixed grass, layer settings, translated/scaled maps, repeat calls,
incomplete/unknown/flipped patterns, duplicate crowns/bottoms, custom layers
and six actual map assets. The production render comparisons reproduce the
448-pair investigation matrix. A further 288 pairs cover local and remote
Rayquaza, shiny Rayquaza and Shadow Lugia using all four walk frames and
facings, hover phases, and a midpoint between walkable tiles. Ground depth
stays fixed to the actor's world position throughout those cases.

The measured extra construction time was approximately 21 ms for Viridian
City and at most 28 ms across these map checks on this workstation; this work
runs at map construction, not each frame. These focused checks are not a full
release certificate. Unknown tree families remain outside this correction.
