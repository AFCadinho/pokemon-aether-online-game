# Primal Kyogre Surf mount

Based on the approved v3 preview. `source.png` contains the supplied four-direction
art. The 4x4 runtime sheets use 192x224 frames; all source pixels and the original
64x64 seated player poses retain their size. Padding anchors the front waterline
at world Y +12, matching Lapras with the existing player Look offset.

The rider stays above the forehead in front. Side seats follow the source torso's
18px shift between swimming poses. The mask exactly follows the foreground's alpha:
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
The item is not consumable or tradeable. No box or shop entry is included.
