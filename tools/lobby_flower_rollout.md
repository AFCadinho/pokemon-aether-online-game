# Aether Clash lobby flower sway

All 60 existing pink flower tiles (30 two-tile sprites) use the exact 48 frames
at 70 ms per frame from the shared town/route flower library. This replaces the
older animation with its 810 ms opening pause. Colours, first-frame artwork,
flower placements, layer order, TileData and map connections remain identical.

The artist map references
`../routes/animation_assets/route_flowers/Route Flowers.tsx`.
`aether_clash/animation_assets/lobby_flowers/build.py` remaps only matching flower
artwork. The fountain generator retains its existing GID bank and reference
position when rebuilt alongside the flower bank. Both generators are idempotent.

`tools/lobby_flower_rollout.gd -- --apply` reuses the existing route flower
rollout's native TMX library importer, staged validation and lossless compactor.
All non-flower timelines, including both fountain streams, are preserved. Its
intake/report record the source hash, exact frame hashes and backup location.
The shared flower rollout keeps its original route defaults.

Verification covers the exact native frames/timing on all 60 cells, the original
static fingerprint, fountain continuity in every frame, existing non-flower
timelines and atlas layout. Native Tiled renders have identical frame zero; at
840 ms, all differences from the older animation are confined to flower cells.
The live Godot preview shows moving flowers and identical paused captures.
The route rollout's read-only check still reviews all 22 sources with no changes.

The decoded lobby atlas budget stays at 7,133,184 bytes. No runtime animation
scripts or gameplay scenes are added.
