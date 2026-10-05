# 3D terrain and Trick Room

The four terrains and Trick Room use the existing displayed field state and event
order. Terrain occupies the ground around both teams; Trick Room has an independent
arena-space volume. Weather, terrain and Trick Room can coexist. Each layer ends
only when its own displayed condition ends. Gameplay and turn order remain server
controlled.

## Visual review checklist

Implemented and awaiting player review:

- [ ] Grassy Terrain — green ground patches and small drifting leaves.
- [ ] Electric Terrain — warm ground glow and brief low lightning arcs.
- [ ] Misty Terrain — pale pink ground haze and gently drifting mist patches.
- [ ] Psychic Terrain — violet ground ripples and small rising rings.
- [ ] Trick Room — translucent walls with brighter lilac grid lines, dark outlines and stronger borders for visibility in the PvP stadium; awaiting re-review.

## Offline review

Run from the game control directory through the assigned slot:

```sh
ops/worktrees/slot-env slot-b -- godot --path .worktrees/slot-b/frontend --script res://tests/battle_dialogue_preview.gd -- --terrain
```

Choose a terrain, toggle **Trick Room**, and optionally add weather. **Geen terrain**
ends only the terrain. **Terraineffecten** toggles terrain and Trick Room together,
matching the existing setting. **Pauze** stops their replay clocks, including shader
motion. Rotate the camera and use **Load preview** to switch arena or 2.5D/3D mode.
The preview does not create a server battle or change gameplay state or saved settings.

Use `-- --trick-room` to start directly with Trick Room active and no terrain.

Append `--smoke-terrain` to exercise all four terrains, Trick Room and weather
combinations, then exit. Set `POKEAETHER_STAGE_OUTPUT` to capture the five effects
on a display. The preview uses the assigned slot's own model cache/downloader.

## Rendering and lifetime

Ground meshes follow the arena's surface height and battle origin, including co-op.
Each terrain has one soft ground layer and at most 90 shadowless mesh instances.
Trick Room uses six transparent grid planes. All animation uses the battle clock;
there are no new waits in the event queue or camera movement/distortion.

These are presentation-only layers. They do not change arena materials, lighting,
weather atmosphere or Pokémon shaders. Both layers are excluded from the Pokémon
irradiance pass. Removal, fallback, arena changes and pool release synchronously
hide/stop them. Repeated snapshots preserve the active effects and their clocks.
The original 2D/2.5D presentation is retained and restored on fallback.
Existing common activation/heal audio remains on its current route; these
persistent visuals add no repeating sounds.

## Focused checks

`battle_terrain_3d_check.tscn` checks all four terrains plus Trick Room, weather
coexistence, independent ends/settings, pause/speed, camera independence, repeated
snapshots, fallback, co-op layout changes and cleanup. The real-model preview smoke
checks native visuals and hidden 2D overlays. Weather and material-response tests
cover the shared presentation and arena cleanup routes.
