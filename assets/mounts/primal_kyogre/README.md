# Primal Kyogre Surf mount

Based on the approved v3 preview. `source.png` contains the supplied four-direction
art. The 4x4 runtime sheets use 192x224 frames; all source pixels and the original
64x64 seated player poses retain their size. Padding anchors the front waterline
at world Y +12, matching Lapras with the existing player Look offset.

The rider stays above the forehead in front. Side views anchor the hull to the
occupied water tile, rather than using the lower fin tip as the waterline. The
whole side-facing rig sits 32px lower than the initial integration. Packing
compensates the source torso's 18px shift between swimming poses, keeping the
hull and seat steady while the fins move. The mask exactly follows the foreground's alpha:
only the head and nearby fin can cover the player. Tail and far fin stay behind.
Both player models and clothing layers use the normal shared avatar renderer.

The Surf-fishing pose has its own seat adjustments and uses the same anatomical
foreground, instead of drawing the full creature over the fishing player.

Rebuild with `python tools/build_primal_kyogre_mount.py` (Pillow required).
Render both player models and all swimming/fishing directions with:

```
ops/worktrees/slot-env SLOT -- godot --path .worktrees/SLOT/frontend \
  --rendering-method gl_compatibility \
  --script res://tools/preview_primal_kyogre_mount.gd -- --output=/absolute/output
```

Grant `primal-kyogre-mount` through the existing administration reward controls.
It permanently unlocks Primal Kyogre in the Surf selector. Existing Surf access
requirements still apply; a saved selection without the item falls back to Lapras.
The item is not consumable or tradeable. The Gift Store Surf tab sells the
Primal Kyogre Mount Box for 1,000 Gems, with the existing 50–80% mount-box pity.
The shiny assets in `../primal_kyogre_shiny` reuse the exact same alpha, rider
mask and positioning; the builder recolours the source using the existing
Shiny Primal Kyogre reference (charcoal, pale gold and rose fin tips).
