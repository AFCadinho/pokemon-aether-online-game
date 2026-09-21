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
