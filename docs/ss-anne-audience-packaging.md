# SS Anne audience delivery

The approved Quaternius passengers are core game resources, not optional
Pokemon bundles. `scripts/battle/arenas/maps/ss_anne/arena.gd` preloads the four
GLBs under `assets/models/battle/ss_anne_audience/`; Godot includes their
imported scenes and animations in the normal game export. Core desktop, web
and Android presets explicitly include the accompanying CC0 licence.

The desktop R2 workflow checks the exported Windows and Linux packs with
`tests/ss_anne_packed_runtime_check.gd` before packaging and uploading them.
The check instantiates the arena from packed resources and verifies all six
passengers, their skeletons and wave/idle playback. A loose GLB upload or a
Pokemon bundle-index update cannot deliver this arena to an older client.

For a focused local check, export and probe in an assigned task slot:

```sh
ops/worktrees/slot-env SLOT -- godot --headless --path .worktrees/SLOT/frontend \
  --export-pack "Linux Itch Build" /tmp/ss-anne-game.pck
ops/worktrees/slot-env SLOT -- godot --headless --main-pack /tmp/ss-anne-game.pck \
  --script /absolute/path/to/.worktrees/SLOT/frontend/tests/ss_anne_packed_runtime_check.gd
```

Player delivery uses the normal certified client release and R2 game-package
publication. The packaging change itself does not activate a live manifest or
publish the current development batch.
