# Active route flower animation audit

The registered Godot world scenes use Routes 1–15, 21, 22, 24 and 25, plus Viridian Forest. The original rollout contained 828 flower tiles; the reference-refresh section below records later authored changes. Route 8 already had the correct Lavender frames; the other 19 flower visuals were updated.

Both Saffron connection sources are active and contain no flowers. `Route 15 copy.tmx` is unused. The authoring Lavender north stub and Route 12 west exterior are not referenced by active generated visuals; Godot uses its existing transitions and gate template.

| Tiled source | Active Godot visual | Flower tiles | Status |
|---|---|---:|---|
| Route 2.tmx | `kanto_route_2` | 153 | Updated |
| Route 22.tmx | `kanto_route_22` | 61 | Updated |
| Route 1.tmx | `route_1` | 146 | Updated |
| Route 10.tmx | `route_10` | 8 | Updated |
| Route 11.tmx | `route_11` | 10 | Updated |
| Route 12.tmx | `route_12` | 27 | Updated |
| Route 13.tmx | `route_13` | 22 | Updated |
| Route 14.tmx | `route_14` | 22 | Updated |
| Route 15.tmx | `route_15` | 29 | Updated |
| Route 21.tmx | `route_21` | 6 | Updated |
| Route 24.tmx | `route_24` | 35 | Updated |
| Route 25.tmx | `route_25` | 38 | Updated |
| Route 3.tmx | `route_3` | 26 | Updated |
| Route 4.tmx | `route_4` | 49 | Updated |
| Route 5.tmx | `route_5` | 24 | Updated |
| Route 6.tmx | `route_6` | 12 | Updated |
| Route 7.tmx | `route_7` | 18 | Updated |
| Route 8.tmx | `route_8` | 81 | Already correct |
| Route 9.tmx | `route_9` | 14 | Updated |
| Saffron City - north.tmx | `saffron_city_north` | 0 | No flowers |
| Saffron City - south.tmx | `saffron_city_south` | 0 | No flowers |
| Viridian Forest.tmx | `viridian_forest` | 47 | Updated |

The exact town/Lavender frames are shared by colour, with 48 frames of 70 ms (3.36 seconds). No new flowers, pickups or gameplay objects were placed. The authoring source edits preserve terrain, sprites, cell flips, layer settings and connection metadata.

The Godot TMX importer imports the flower library into an isolated staging directory. Its lossless atlas compactor applies those native frames to matching flower artwork in the existing playable visuals. Each map is staged and checked before any canonical output is replaced. Original static fingerprints, TileData, transforms, layer settings and non-flower animation signatures are verified unchanged. This also preserves the current gameplay scenes.

Evidence and exact native frame contracts: `route_flower_rollout_intake.json`, `route_flower_rollout_report.json`, and `tests/route_flower_animation_check.gd`.

After a future source update, refresh the audited intake and run through the assigned slot:

```sh
ops/worktrees/slot-env SLOT -- godot --headless --path .worktrees/SLOT/frontend --script res://tools/route_flower_rollout.gd -- --apply
```

An unchanged rerun preserves the existing report and generated resources.

Validation: eight focused Godot checks passed, including all 2,976 authored frame samples, original fingerprints and non-flower timelines. Tiled renders passed for all 20 flower maps at 0, 840 and 2,520 ms; frame zero is identical and changed pixels are confined to flower tiles. An unchanged rerun preserved every generated resource and the existing report. The aggregate decoded atlas allowance increases by 7.98 MiB across the reviewed maps.

## v0.3.111 reference refresh

Seven subsequently reimported route visuals (5–11) use the current shared
artist tilesets. Their complete static fingerprints, TileData, flower placement
and native animation timelines were compared with isolated fresh imports of the
current TMX sources. Route 9 retains its accepted empty Doors layer; only that
empty layer and the resulting render-order offset were normalized for comparison.
No map, source art or generated visual was changed for this reference refresh.

The report preserves the historical rollout records and adds explicit
`current_*` references and per-atlas flower timeline pins for these seven maps.
The current total is 901 flowers. Tests retain the original 48-frame
contract for untouched maps and verify each current native flower's exact frame
count, pixels, speed and timing on the refreshed maps.
