# Offline trainer dialogue preview

From the frontend project directory:

```sh
godot --path . --script res://tests/battle_dialogue_preview.gd
```

The preview starts in 2.5D with Dragonite and Roaring Moon. Use **Left speaks**,
**Right speaks**, or **Both speak**. An empty text field uses sample move calls;
enter your own text to test longer dialogue. **Clear** dismisses both speakers.
The local appearance available to PlayerSave is used on both sides (default
appearance if none is loaded).

Select **3D** and an arena, then **Load preview**. It reuses the configured local
3D catalog and forest manifest. Optionally provide the catalog using
`POKEAETHER_3D_STAGE_REPORT`. Missing assets produce the normal loading/fallback
message; the preview does not download assets. Arena selection applies to 3D.
Drag the free arena to rotate the 3D camera.

This is a development-only launch script, not a production battle mode. It uses
the real battle host, UI, trainer art and callouts, but never creates a server
battle. Normal battle action buttons are disabled. Preview settings are assigned
in memory and are not saved; teams, rewards and server state are untouched.

Focused check: append `-- --smoke` to exercise both speakers and their lifetime.

## Forced Freeze review

Launch the same harness through the assigned slot with `-- --freeze`:

```sh
ops/worktrees/slot-env slot-b -- godot --path .worktrees/slot-b/frontend --script res://tests/battle_dialogue_preview.gd -- --freeze
```

It selects 3D, shows Dragonite and Pikachu, and immediately freezes Pikachu.
Use **Bevries links**, **Bevries rechts**, and **Ontdooi alles**. Freeze uses
only a tint and paused idle. **Aanval geblokkeerd (rechts)** forces a failed
action with a short ice burst on Pikachu through the real event renderer. Drag the arena
to rotate the camera. The controls force only the native visual status, frozen
idle and HUD indicator; no gameplay status, party, save, or server battle changes.
Without an explicit `POKEAETHER_3D_STAGE_REPORT`, this mode uses the normal pinned
model downloader and the assigned slot's own asset cache. Settings remain in memory.

Append `--smoke-freeze` to test freezing/thawing both sides and exit. With a display,
`POKEAETHER_STAGE_OUTPUT` also writes `freeze-preview.png` before thawing.
Freeze is approved with tint-only idle and a short ice burst/sound on blocked actions.
