# Godot editor startup messages

## Beacon editor initialization

The beacon animates in the editor without calling runtime localization autoloads.
Its editor label is `Aether Beacon`; in the game it uses the active language.
Run the focused regression from the workspace root:

```sh
ops/worktrees/slot-env slot-a -- godot --headless \
  --path .worktrees/slot-a/frontend --editor \
  res://tests/aether_beacon_editor_check.tscn --quit-after 600 \
  -- --beacon-editor-check
```

Require the `Aether Beacon editor initialization passed.` message and no errors.
The scene runs this check only with the explicit command-line flag.

## Duplicate Pokemon sprite UIDs

Sprite packs and aliases can contain copied `.import` metadata with the same UID.
Close Godot before repairing local generated metadata:

```sh
python3 tools/repair_sprite_import_uids.py
python3 tools/repair_sprite_import_uids.py --apply
```

The first command previews changes. The second removes only repeated UID lines;
it preserves the images, import settings, and the first UID in each group.
Reopen Godot so it generates a fresh UID for each repaired import. This metadata
is machine-local and ignored by Git. Do not copy `.godot` caches between projects.

## Android build-tools directory

The editor's Android SDK path must point to an installed SDK containing
`build-tools` and `platform-tools`. This is a local editor setting, not a project
setting. For Godot 4.6 the standard build-tools package is `35.0.1`. Follow the
[Godot Android setup instructions](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html)
for the full export requirements. Installing build-tools alone does not certify
an Android release.

## Nested launcher project

`Detected another project.godot at res://launcher` is informational. The launcher
is intentionally a separate project; Godot skips it when opening the game.
Open `launcher/project.godot` directly to edit the launcher. Godot 4.6 checks for
a nested project before `.gdignore`, so adding `.gdignore` cannot suppress this
message. Keep the launcher in its existing location to preserve build tools.
