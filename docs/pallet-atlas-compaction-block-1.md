# Pallet atlas — block 1 investigation

Decision: proceed to a **Pallet-only prototype**, after approval for block 2.
No map, atlas image, TileSet, importer or runtime behavior was modified here.
The backend was not interrupted. Findings describe estimated uncompressed RGBA
texture data, not compressed downloads, physical RAM or measured savings.

## Counts

The generated visual has five layers and 4,376 occupied cells:

| Layer | Cells |
| --- | ---: |
| Ground | 2,000 |
| GroundDetail | 1,307 |
| Objects | 832 |
| ObjectsTop | 234 |
| Doors | 3 |

There are 325 unique referenced 32 × 32 tiles, out of 12,400 defined atlas tiles
(2.62% used). The thirteen source chunks occupy 48.4375 MiB base RGBA, matching
the selected live world texture audit. Six chunks have no references in the
generated visual; those alone account for 20.4375 MiB.

| Source ID | Defined tiles | Unique used tiles |
| --- | ---: | ---: |
| 1 | 1,024 | 61 |
| 1,025 | 1,024 | 51 |
| 2,049 | 1,024 | 8 |
| 3,073 | 1,024 | 0 |
| 4,097 | 1,024 | 0 |
| 5,121 | 1,024 | 96 |
| 6,145 | 1,024 | 76 |
| 7,169 | 1,024 | 0 |
| 8,193 | 1,024 | 8 |
| 9,217 | 1,024 | 25 |
| 10,241 | 1,024 | 0 |
| 11,265 | 1,024 | 0 |
| 12,289 | 112 | 0 |

All used regions are in bounds and exactly 32 × 32. Four placed cells use a
nonzero alternative/transform value; preserve those values when remapping.
There are no animation definitions anywhere in the generated atlas, including
unused tiles.

## Independent source/dependency review

The original local artist TMX is available. Read-only XML/CSV/base64 inspection
confirms a 50 × 40 map, 32 × 32 tiles, the same five layer cell counts and exactly
325 unique GIDs. Its external tileset contains zero tile-animation definitions
and zero frames. There are no tile-objects. This independent count agrees with
Godot's actual generated TileMapLayer API rather than inferred binary cell offsets.

Only this generated visual directly references its generated TileSet; the full
Pallet scene instances the visual. Pallet also has separate Water, TownSigns,
Collision, Sand and Stair marker layers with separate TileSets. They are outside
this prototype's scope and must not be altered or included in the savings claim.

Runtime depth-row builders copy source IDs, atlas coordinates and alternatives
from existing cells; they do not expand this map's tile repertoire. The door
animator can cut sprite regions from existing cell textures and animate their
position/opacity. Therefore zero tileset animation frames does **not** mean no
door animation. Pallet configures partial door opening regions, not composite
door definitions with synthetic atlas cells. Preserve cell positions, tile-local
regions and the door behavior. No unrelated door/layer-name corrections belong
in this atlas prototype.

## Estimated options, not implemented results

| Option | Base-RGBA estimate | Potential decrease |
| --- | ---: | ---: |
| Current full atlas | 48.4375 MiB | — |
| Drop six completely unused chunks only | 28 MiB | 20.4375 MiB |
| Bounding-rectangle crop of each used chunk | 6.46875 MiB | 41.96875 MiB |
| Used tile pixels alone, without packing overhead | 1.26953 MiB | Theoretical lower bound |
| Example single 512 × 1,024 compact atlas | 2 MiB | Approximately 46.44 MiB |

The 2 MiB example has room for 325 tiles even with a 2-pixel border on each
side: 36-pixel slots, 14 columns × 28 rows = 392 slots. This is packing arithmetic,
not a tested format, allocation result or a promise of that exact memory saving.
Simple cropping still requires coordinate offsets; arbitrary repacking requires
an explicit old-source/coordinate → new-source/coordinate mapping. Maintaining
per-source layouts is also an option if it simplifies dependency preservation.

The importer currently chunks the **whole physical source grid** at 4,096 pixels
and defines every grid tile. That explains the unused generated resources.
Existing lossless PNG/portable compression reduces serialized size, not the
number of decoded texture pixels. Compaction is a distinct optimization.

## Block 2 acceptance, if approved

- Prototype Pallet only; keep the production importer unchanged until block 4.
- Preserve every referenced tile's exact RGBA pixels and transform value.
- Keep layer/cell positions, tile dimensions, local regions and depth markers.
- Verify all five layers, doors, trees/grass depth and separate collisions/warps.
- Maintain lossless serialization and browser-safe atlas dimensions; no scaling.
- Keep all existing battle/sprite preparation, limits and quality unchanged.
- Reject unsupported/dynamic dependencies rather than silently discarding them.
- Then use block 3 for rendered map/battle and desktop measurements.

## Reproducibility

Run from slot-C frontend:

```sh
/home/adinho/Desktop/pokemonaetheronline/game/ops/worktrees/slot-env slot-c -- \
  godot --headless --path . --script tools/audit_pallet_atlas_usage.gd
```

The tool instantiates only the script-free generated visual, without adding it
to the live tree. It reads real cell/source/animation regions and prints JSON;
it does not save resources or edit images. Two focused runs pass. The tool fails
on unsupported source types, missing tiles, out-of-bounds or non-32px regions.
No full project gate was run for this research block.

Unchanged input SHA-256:

- Visual: `625cac93d17901aa3c9e7cbdeada0dfde73b0f44b37d3d557169d6bd9034f501`.
- TileSet: `bd704842139867a2ba38b23e23937060a517df7132b9addeffdccbfce6b20c70`.
