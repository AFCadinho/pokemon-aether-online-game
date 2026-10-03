# Kanto Town Map artwork and layout

The illustrated map approved on 2026-10-03 is stored at
`assets/ui/maps/kanto_region_map_aether.png`. It is the original generated
1453×1082 PNG, copied without resizing or repainting. The previous
`kanto_region_map.png` remains available as the source reference.

`data/region_maps/kanto_layout.json` uses the new image's native pixel grid.
The canvas fits the entire image inside its available area while preserving
its aspect ratio. Locations, hotspots, route bends, selection rings, and the
current-location portrait all use the same fitted rectangle.

## Editing positions

- `points` contains settlements, special locations, and Routes 1 and 2.
- `routePoints` contains Routes 3–25. Registered playable routes use these
  coordinates too; they must never fall back to the center of the map.
- `connections[].waypoints` follows the bends in the painted golden network.
- `hitSize` is the square hotspot width in image pixels. It scales with the
  artwork; neighboring hotspots must remain separate.
- `markerOverlay: true` adds a blue/gold marker for locations without a circle
  in the artwork: Cerulean Cave and the southern Viridian Forest gate.
- `locationGroupIds` maps world-catalog groups to stable presentation point
  IDs. `mapIds` takes precedence for specific entrances, such as the two
  Diglett's Cave entrances and the two Underground Path entrances.
- Availability and accessible interiors come from the world-access catalog.
  A new playable route can use an existing planned point without changing
  the image or replacing its presentation ID.

The S.S. Anne shares Vermilion's harbor point. The Underground Path tunnel
uses the Route 5 point; its Route 6 entrance uses the Route 6 point.

Run the focused check through the slot environment:

```sh
ops/worktrees/slot-env SLOT -- godot --headless \
  --path .worktrees/SLOT/frontend --script res://tests/town_map_ui_check.gd
```

The check covers artwork coordinates, all Route 1–25 hotspots, playable-world
resolution, source-layout reuse, non-overlapping hotspots, route waypoints,
modal behavior, and resizing with the original aspect ratio.

## Generation record

Tool: built-in `image_gen.imagegen` (no CLI fallback).
Reference image: `assets/ui/maps/kanto_region_map.png`.
The user approved the generated concept before its integration.

Final generation prompt:

> Use case: stylized-concept. Asset type: original regional town map concept for the PokeAether online game. Input image 1 is the existing Kanto regional map, used as a geography and route-layout reference. Create a new, beautifully illustrated version of this map, landscape aspect ratio 400:297, approximately 1600x1188. Preserve the reference's recognizable Kanto coastline, central ocean bay, western narrow peninsula, northern mainland, southeast peninsula and southern offshore islands. Preserve the same placement and connections of the gold route network and blue circular markers as closely as possible. Original art direction: clean, detailed hand-painted top-down adventure atlas, jewel blue ocean with gentle water texture, bright turquoise shallow coastlines, lush emerald forests, readable soft sage green plains and terraced earthy mountains, tiny understated settlement clusters beneath the markers. Restrained refined fantasy adventure feel compatible with a classic monster-catching RPG. The geographic image must fill the entire canvas edge to edge, with no decorative frame and no surrounding interface. Keep the terrain visually subordinate to the route overlay. Routes are consistent fine warm gold strokes with a thin dark navy shadow, right-angle bends matching the reference, never random extra paths; large settlement markers have gold rings and deep blue centers, small points have gold rings and light blue centers. The new map should feel like a polished coherent original game asset, clearer and more detailed than the low-resolution reference. No labels, no text, no logo, no compass, no legend, no characters, no watermark, no invented extra islands. Avoid photorealism, tilted isometric camera, excessive glowing effects, blurry terrain and ornate decoration. This is a concept preview rather than a guaranteed pixel-aligned production replacement.
