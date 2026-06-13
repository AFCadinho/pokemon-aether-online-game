# Battle Move Animations

Move animations are routed through `BattleAnimationRouter` and configured in `res://data/battle_move_animations.json`.

The scalable path is:

1. Put move-specific assets in `res://assets/battles/animations/<move_key>/`.
2. Add one entry to `data/battle_move_animations.json`.
3. Use normalized move keys: lowercase, no spaces, hyphens or underscores. Example: `Moon Blast`, `MOONBLAST` and `moon_blast` all resolve to `moonblast`.

Example entry:

```json
"moonblast": {
  "template": "imported_sheet",
  "category": "beam",
  "data_path": "res://assets/battles/animations/moonblast/moonblast.json",
  "sheet_path": "res://assets/battles/animations/moonblast/PRAS- Moonblast.png",
  "speed_scale": 1.35,
  "show_pink_visual": true,
  "visual_color": [1.0, 0.2, 0.75, 1.0],
  "sprite_tint": [1.0, 0.78, 1.0, 1.0],
  "overlay_peak_alpha": 0.2,
  "sparkle_count": 14,
  "sound_paths": {
    "PRSFX- Moonblast1.wav": "res://assets/battles/animations/moonblast/PRSFX- Moonblast1.wav"
  }
}
```

`template` and `category` are metadata for grouping future animations, such as `beam`, `projectile`, `punch`, `slash`, `status_buff`, `status_debuff`, `heal` and `field`. The current player supports imported RPG Maker-style sheet JSON.

The router loads the catalog only when a move animation is requested, then caches move configs. Assets are loaded by the spawned `MoveAnimationPlayer`, so adding more catalog entries does not preload every animation at battle startup.

Importer smoke test from the source animation pack:

```bash
cd /home/adinho/Documents/move_animation
python3 tools/import_move_animation.py MOONBLAST --project-root /home/adinho/Desktop/pokemonaetheronline/pokemon-aether-online
```

The importer preserves existing visual tuning keys in `battle_move_animations.json` while refreshing generated JSON and copied assets.
