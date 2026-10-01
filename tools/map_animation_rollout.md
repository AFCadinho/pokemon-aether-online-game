# Native map animations

The approved water/leaf/flower animation approach now runs in 17 existing generated visuals, including the three Mt. Moon maps. All remaining visuals were inspected; maps without matching artwork stay static. The two previous demonstration maps retain their own previews.

## Preview

```sh
godot --path /home/adinho/Desktop/pokemonaetheronline/game/pokemon-aether-online --rendering-method gl_compatibility --script res://tools/preview_animated_map.gd -- viridian_city
```

Replace `viridian_city` with `pallet_town`, `cerulean_city`, `route_1`, or `mt_moon_1f`. WASD pans, +/− zooms, Space pauses/resumes, Esc closes. This offline viewer loads the canonical generated visual; it does not start game autoloads or write resources.

## Authoring and rollback

Authoring sources: `/home/adinho/Documents/tiled_pokeaether/ANIMATED_MAPS.md`.
Static backup: `/home/adinho/Documents/tiled_pokeaether_backups/static_2026-09-27_082243/`.

The backup includes TMX, TSX, PNG and world files, a SHA-256 manifest, and a separate `godot-static-visuals.tar` from frontend commit `18684328d27b33d63336fd8d05a76dfbbaaf4d07`. Original PNGs remain unchanged; TSX files reference appended-frame `*.animated.png` copies. Restoring authoring maps requires restoring their TSX dependencies too.

29 current artist maps and 3 older shared-tileset maps contain matching animated cells. Newer authoring routes not yet imported into the game receive native animation on their next normal TMX import. Mixed TSX global ranges were remapped only as necessary to avoid appended animation frames overlapping another tileset; local IDs and map semantics are verified unchanged.

## Existing game visuals

Some generated game maps differ from current authoring layouts and retain older source paths. `map_animation_rollout.gd` therefore matches exact RGBA tile hashes and adds the animations to the current generated maps, using the existing lossless atlas compactor. It does not reconstruct map geometry from newer TMX files.

The catalog in `map_animation_assets/` contains source hashes, exact frame hashes, timings, and lossless strips. Frame 0 equals the original tile. `map_animation_rollout_report.json` records before/after fingerprints and affected cells. Static image/layout/TileData fingerprints and cell flags remain identical. The existing fixture changes only measured `baseRGBABytes`, accounting for animation frames (+45.93 MiB across all 17 visuals, not per map). Runtime memory scales with loaded maps; browser/mobile performance has not been profiled in this task.

The migration stages and verifies all affected maps before writing canonical files. It skips already animated scenes and preserves the previous report on an empty rerun. To migrate additional static visuals, run it through the assigned slot environment with `--apply`; without that argument it stages only. Keep a versioned/static backup before future migrations.

## Checks performed

- `tests/map_animation_rollout_check.gd`: 17 maps, 20,338 animated cells, 8,624 frame images/timings; original fingerprints preserved.
- `tests/migrated_visuals_check.gd`: all 33 original migration fixtures preserved, with explicit animation memory budgets.
- `tests/generated_map_atlas_layout_check.gd`: 37 compact visuals.
- `tests/generated_map_texture_storage_check.gd`: lossless portable resources.
- `tests/tmx_animation_check.gd`: native import/animation contract.
- Live Viridian City and Mt. Moon previews: frames change while enabled and two paused captures are identical. Route 10 rendered in Tiled; authoring verification covers 38 affected/dependent maps and 951,899 layer positions.

No gameplay scene/node changes, runtime shader, new NPCs, or release deployment.

## Vermilion sea water

Vermilion's current artist visual uses a different three-color sea palette.
`vermilion_water_animation.gd` builds sixteen 160 ms frames from that artwork,
using the same two-pixel horizontal motion as Cerulean. Only sea-colored pixels
move; frame 0, coastlines, map geometry, TileData and existing grass animations
are preserved. The separate `vermilion_water_animation_report.json` records
1,976 animated cells across thirteen water/shore variants and the original fingerprint.

After reimporting this static artist TMX, reapply in the assigned task slot:

```sh
ops/worktrees/slot-env SLOT -- godot --headless --path .worktrees/SLOT/frontend --script res://tools/vermilion_water_animation.gd -- --apply
```

An already animated map is left unchanged. Preview with
`tools/preview_animated_map.gd -- vermilion_city`.
