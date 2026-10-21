# Nightlights and moving cameras

Celadon’s fixed nightlights could appear to switch off as the player moved the
camera. Their `enabled` state and day/night intensity were correct. The problem
was the renderer’s light selection for large tile batches.

Godot 4.6 Compatibility accepts 15 point lights per canvas item (the 16-slot
array also encodes its count). The default 16 × 16 tile rendering quadrant can
intersect 21 Celadon lights, or 17 Cerulean lights. Camera culling then changes
which lights enter the item’s list. See the [renderer’s selection loop](https://github.com/godotengine/godot/blob/4.6-stable/drivers/gles3/rasterizer_canvas_gles3.cpp#L778)
and [TileMapLayer quadrant documentation](https://docs.godotengine.org/en/4.6/classes/class_tilemaplayer.html#class-tilemaplayer-property-rendering-quadrant-size).

`night_light_rendering.gd` caps visible tile layers at four-tile rendering
quadrants on maps containing `NightLights`. World applies it after creating its
depth rows and crown groups, for normal loading, startup and teleports. This
changes render batching only: authored tiles, physics quadrants, hidden
collision layers, lamp placement, light settings and day/night behavior remain
unchanged. Maps without nightlights keep their existing batching.

## Evidence

The Compatibility camera probe pans a 640 × 480 viewport through 70 positions,
comparing the same stationary world pixels at different screen positions.
Before the fix, four Celadon light points changed substantially, with a maximum
RGB-channel difference of 0.459. With local batches, 69 repeatedly sampled
lights remain pixel-identical. The conservative maximum batch/light overlap is
11 in Celadon, 7 in Cerulean, 9 in Vermilion and 5 in Fuchsia.

Fuchsia uses the same night-light scene for its 23 existing street lanterns
and 21 building window light points. Its camera probe covers all 44 points
across the city; all remain pixel-identical when the camera moves. Window
lights use lower energy and a smaller radius than the street lanterns.

In the same isolated camera probe, peak 2D draw calls decreased from 402 to 200;
this is a rendering check, not a whole-game FPS or Android/browser benchmark.

`tests/night_light_camera_check.gd` exercises World’s real depth normalization,
preserves collision bytes, checks the four city batch budgets and compares
pixels when a graphics renderer is available. Headless runs perform structural
and budget checks. `--baseline` intentionally bypasses batching on the real maps
and must fail, demonstrating the regression without editing project files.

Run in the assigned slot:

```sh
ops/worktrees/slot-env SLOT -- godot --path FRONTEND \
  --rendering-method gl_compatibility --script res://tests/night_light_camera_check.gd
ops/worktrees/slot-env SLOT -- godot --headless --path FRONTEND \
  --script res://tests/night_light_check.gd
```
