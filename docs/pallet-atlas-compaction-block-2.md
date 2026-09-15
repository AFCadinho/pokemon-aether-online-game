# Pallet atlas — block 2 prototype

Pallet's gameplay scene now references a separate compact generated visual.
The original generated visual and atlas are retained unchanged as the comparison
reference. No importer, backend, battle preparation, cache limit or artwork
scaling was changed. This is a Pallet-only prototype, not general rollout.

## Result

- All 4,376 placed cells and 325 distinct tiles retained.
- Seven used atlas sources retained with their original source IDs.
- New coordinates assigned within each source; original cell transform values retained.
- Every used 32 × 32 region is RGBA-byte-identical to the original decoded texture.
- All stored TileData and layer properties retained, except the intended atlas
  coordinates, texture/TileSet references and cell serialization.
- PortableCompressedTexture2D uses lossless serialization, with browser-safe sizes.
- Atlas region margins are 2 pixels, separation 4 pixels, in 36-pixel slots.
  Texture padding remains enabled as before; no texture-filter policy changed.

Original base-RGBA estimate: 50,790,400 bytes (48.4375 MiB).
Compact base-RGBA estimate: 1,843,200 bytes (1.7578125 MiB).
Difference: 46.6796875 MiB of logical base-RGBA atlas data. This is **not yet a
measured browser/desktop RAM or GPU saving**; renderer tile padding, resource
lifecycle, allocator and driver overhead must be covered by block 3.

The original atlas files remain in the repository/export pipeline for comparison.
Therefore this prototype does not claim a smaller initial browser download:
the pack may still contain the originals as well as the small new resources.
Source cleanup and importer automation belong to a later accepted phase.

## Verification

`pallet_compact_atlas_check.gd` loads both real saved visual scenes, iterates all
cells, verifies exact unique tile pixels, stored tile/layer properties, flips,
cell positions/order, retained IDs and lossless dimensions. It also invokes the
real door animator's splitting helper on all three door cells with a partial
24-pixel moving panel, checking piece counts, placement and decoded piece pixels.
The gameplay scene is checked to use the compact visual. The regression is
registered for future project CI/full verification, which was not run here.

Focused runs pass:

- `pallet_compact_atlas_check.gd`, including door-piece comparison.
- `map_depth_lookup_check.gd`, checking layer lookup/depth semantics.
- `pallet_town_encounter_check.gd`, checking encounter behavior.
- Godot UID sidecar validation and Git whitespace checks.

The full Pallet scene's only modification is the visual PackedScene path. Its
content normalized back to the original path retains SHA-256
`cceebaa4da8e5d9ce0dbae52b84a2809752a22e6545bbe2c4326627cc8762669`.
Collision, water, stairs, signs, warps and NPC configuration are unchanged.
Existing generic depth tests plus identical visual cell properties are focused
evidence, not a replacement for rendered tree/grass/door gameplay review.

Prototype generation initially hit Godot's requirement that tile creation needs
a texture with valid dimensions. The generator now supplies a correctly sized
temporary texture before creating tiles and uses the final compressed image for
saved resources. Final generation and saved-resource regressions succeed; no
original files were overwritten by that failed attempt. Editor launcher/Unown
case-UID warnings remain unrelated and visible.

## Block 3, if approved

Build and test the rendered browser/desktop candidate, comparing map appearance,
doors/depth/collisions, map transitions and actual texture counters against the
retained control. Use separate audit-on residency and audit-off timing runs.
Keep battle entry/prefetch unchanged; reject the candidate if gameplay or speed
regresses. Local backend interruptions for disposable runtime tests need a new
approval. No such interruption or rendered-browser comparison occurred in block 2.

Run focused comparison from slot-C frontend:

```sh
/home/adinho/Desktop/pokemonaetheronline/game/ops/worktrees/slot-env slot-c -- \
  godot --headless --path . --script tests/pallet_compact_atlas_check.gd
```

Manual Pallet-only generation (not an importer hook):

```sh
/home/adinho/Desktop/pokemonaetheronline/game/ops/worktrees/slot-env slot-c -- \
  godot --headless --path . --script tools/build_pallet_compact_prototype.gd -- --build
```
