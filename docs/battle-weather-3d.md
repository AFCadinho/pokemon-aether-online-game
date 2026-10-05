# 3D battle weather

Native 3D uses the existing displayed weather state and event order. Weather is
arena-space geometry, rendered behind the HUD and independent of camera orbit.
2D and 2.5D keep the existing weather presentation, including after model fallback.
Terrain and Trick Room have a separate [3D review checklist](battle-terrain-3d.md)
and can be combined with weather.

## Visual review checklist

All eight weather conditions have been visually reviewed and approved by the player.

- [x] Rain — fine slanted rain streaks and cool haze.
- [x] Sun — soft warm shafts and light golden haze.
- [x] Sandstorm — low windblown grains and sandy haze.
- [x] Snow / Snowscape — small gently drifting flakes and cool haze.
- [x] Hail — faster ice pellets with a small ground bounce.
- [x] Primordial Sea — heavier, faster rain and darker haze.
- [x] Desolate Land — stronger amber shafts and warm haze.
- [x] Delta Stream — curved wind strands crossing the arena.

## Offline review

Use the currently assigned task slot (slot-c for the initial implementation):

```sh
ops/worktrees/slot-env slot-c -- godot --path .worktrees/slot-c/frontend --script res://tests/battle_dialogue_preview.gd -- --weather
```

Select a weather, rotate the camera, use **Pauze**, or toggle **Weereffecten**.
**Helder** ends the weather. Arena and 2.5D/3D changes use **Load preview**.
The preview only changes local presentation and in-memory settings. It does not
create a server battle or change gameplay weather. Models use the assigned
slot's own pinned asset downloader/cache unless an explicit stage report is set.

Append `--smoke-weather` to exercise all eight weather conditions and exit.
`POKEAETHER_STAGE_OUTPUT` selects a directory for screenshots on a display.

## Ownership and performance

One MultiMesh holds at most 620 low-poly, shadowless instances. Particle motion
and the brief fade-in use the replay speed/pause clock. There are no weather
waits in the event queue. Clear weather and disabled weather effects allocate
no active weather layer. Weather uses the separate weather setting, as in 2D.

Atmospheric haze uses a camera-local Environment copy; arena materials, day/night
resources and pooled worlds remain unchanged. Live ambient lighting and the
shared sky keep following the world clock. Cleanup restores the previous camera
environment before fallback, arena replacement or returning a pooled world.
Visible weather geometry is excluded from the Pokémon irradiance pass.
The existing 2D weather presentation has no dedicated weather audio cues; this
change adds no new audio loops or move sounds.

## Focused validation

`battle_weather_3d_check.tscn` exercises all conditions, particle budgets, replay
pause/speed, camera rotation, repeated snapshots, weather ending, settings,
2D/2.5D fallback, co-op layout changes and environment restoration. The offline
weather smoke exercises the real battle scene, native models and 2D-layer hiding.
