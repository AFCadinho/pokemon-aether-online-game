# Route 1 tall-grass wind trial — approved

An isolated copy of Route 1 animates only its northwestern grass patch: 37 cells at x=7..15, y=13..17. The user approved this trial; the standard is documented in `tall_grass_standard.md`.

```sh
godot --path /home/adinho/Desktop/pokemonaetheronline/game/pokemon-aether-online --rendering-method gl_compatibility --script res://tools/preview_tall_grass.gd
```

- Space: tall grass animation on/off. Trees, flowers and water keep their existing animation.
- Tab: close-up, surrounding route, whole-map view.
- WASD: pan. +/−: zoom. Esc: close.

The preview command now opens canonical Route 1. Add `-- route1_tall_grass_test` to view the preserved original 37-cell trial. The canonical Route 1 visual and the live Tiled sources retain their original hashes. No encounter settings or character interactions are changed. Walking-triggered rustling is outside this wind trial.

## Artwork and timing

Native TSX animation, using the existing grass artwork from Route 1's tileset. Each cell keeps its roots (bottom ten pixels) and outer two columns exactly fixed. Only the upper part bends with subpixel interpolation, at less than one pixel of maximum actual displacement. Four variants offset movement in groups of approximately 2×2 cells. Each 7.56-second cycle has 3.36 seconds of gentle right/left movement and 4.2 seconds of rest distributed before and after it.

Authoring files and reproducible generator:
`/home/adinho/Documents/tiled_pokeaether/kanto/artist/exterior/routes/animation_tests/route1_tall_grass/`

- `Route 1 - Tall Grass Wind.tmx`
- `Tall Grass Wind.tsx` / `.png`
- `build_preview.py`
- `manifest.json`: source hashes, affected cells, frame hashes and timing.
- `Tall Grass - Preview.gif`: crop recorded from Godot.

## Verification

- First-frame fingerprint matches the complete original Route 1 image/layout/TileData.
- Exactly 37 grass cells animate, using four native atlas sources.
- All 200 timeline frames preserve roots and tile edges; each cycle is 7.56 seconds.
- Saved compact atlas layout passes validation.
- Live Godot captures vary during animation; paused grass crops are identical.
- Source map, source TSX files and source PNG hashes are unchanged.

Performance was not benchmarked on mobile or browser. This small trial adds four compact grass animation strips, approximately 1.13 MiB decoded, to its isolated map.
