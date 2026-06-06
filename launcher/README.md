# Pokemon Aether Launcher

Small Godot launcher project for Pokemon Aether Online.

## Current flow

1. Downloads `manifest.json`.
2. Compares remote versions with `user://versions.json`.
3. Downloads missing or outdated zip files.
4. Extracts them into `user://game`.
5. Starts the configured game executable.

## Configure

Update `config/launcher_config.json`.

The manifest shape is documented in `config/manifest.example.json`.

## Local Test

Start the local test server from the `launcher/test_server` folder:

```bash
cd launcher/test_server
python3 -m http.server 8000
```

Then run the launcher scene and click `Check updates`.

If the launcher shows a 404 for `manifest.json`, the server is usually running from the wrong folder.

The default launcher config points at:

```text
http://127.0.0.1:8000/manifest.json
```

## Package A Real Build

First export the game with the existing Godot export presets. Then package the exported files:

```bash
python3 tools/package_launcher_release.py \
  --version 0.1.0 \
  --base-url http://127.0.0.1:8000 \
  --output-dir launcher/test_server \
  --default-platform linux
```

This writes launcher-ready files such as:

```text
launcher/test_server/game-0.1.0-linux.zip
launcher/test_server/manifest-linux.json
launcher/test_server/manifest.json
```

For a public release, use the real hosted URL as `--base-url`.

## Notes

- This is intentionally a first-pass launcher.
- Launcher self-update is not implemented yet.
- Delta patching is not implemented yet.
