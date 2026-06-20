# PokeAether Launcher

Small Godot launcher project for PokeAether.

## Current flow

1. Downloads `manifest.json`.
2. Compares remote versions with `user://versions.json`.
3. Downloads missing or outdated zip files.
4. Extracts the game build into `user://game/game`.
5. Extracts asset packs into `user://game/assets`.
6. Replaces `user://game/game` on each game update while keeping unchanged asset packs.
7. Starts the configured game executable.

Asset packs marked with `"optional": true` are skipped by the normal update flow. For Gen 5 animated Pokemon sprites, set `"autoUpdateIfInstalled": true` in the manifest when a user already has the Gen 5 folder installed; then the launcher will auto-update those packs on startup while still keeping the manual install button hidden when the folder is already present.

The default install folder is `user://game`. Players can choose a custom install folder from the launcher Game Folder button; that choice is saved in `user://launcher_settings.json`.

Launcher news is loaded separately from the update manifest through `newsUrl` in `config/launcher_config.json`. The expected shape is documented in `config/news.example.json`.

## Configure

Update `config/launcher_config.json`.

The manifest shape is documented in `config/manifest.example.json`.

The launcher can pick a manifest per OS:

```json
{
  "manifestUrls": {
    "Windows": "https://updates.pokeaether.com/manifest-windows.json",
    "Linux": "https://updates.pokeaether.com/manifest-linux.json",
    "macOS": "https://updates.pokeaether.com/manifest-macos.json"
  }
}
```

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
launcher/test_server/PokeAetherLauncher-linux.zip (with --include-launcher)
launcher/test_server/manifest-linux.json
launcher/test_server/manifest.json
```

For a public release, use the real hosted URL as `--base-url` and the production URL prefixes:

```bash
python3 tools/package_launcher_release.py \
  --version 0.1.0 \
  --base-url https://updates.pokeaether.com \
  --game-prefix game \
  --asset-prefix assets \
  --include-launcher \
  --launcher-prefix launcher/latest \
  --output-dir builds/launcher \
  --default-platform linux
```

The production R2 bucket uses this layout:

```text
manifest.json
manifest-linux.json
manifest-macos.json
manifest-windows.json
launcher/latest/PokeAetherLauncher-linux.zip
launcher/latest/PokeAetherLauncher-macos.zip
launcher/latest/PokeAetherLauncher-windows.zip
launcher/0.1.0/PokeAetherLauncher-linux.zip
launcher/0.1.0/PokeAetherLauncher-macos.zip
launcher/0.1.0/PokeAetherLauncher-windows.zip
game/game-0.1.0-linux.zip
game/game-0.1.0-macos.zip
game/game-0.1.0-windows.zip
assets/pokemon-front-v1.zip
assets/pokemon-back-v1.zip
assets/pokemon-shiny-front-v1.zip
assets/pokemon-shiny-back-v1.zip
assets/pokemon-home-v1.zip
assets/pokemon-gen5-front-v2.zip
assets/pokemon-gen5-back-v2.zip
assets/pokemon-gen5-shiny-front-v2.zip
assets/pokemon-gen5-shiny-back-v2.zip
```

The gen5 packs should extract into these folders:

```text
assets/sprites/pokemon/gen5/front
assets/sprites/pokemon/gen5/back
assets/sprites/pokemon/gen5/shiny_front
assets/sprites/pokemon/gen5/shiny_back
```

## Upload To R2

Set R2 credentials in your shell:

```bash
export R2_ACCOUNT_ID="64ea7ddcb5e97df8500c33b8cb48f921"
export R2_BUCKET="pokeaether-updates"
export R2_ACCESS_KEY_ID="..."
export R2_SECRET_ACCESS_KEY="..."
```

Then upload the generated release files:

```bash
python3 tools/upload_launcher_release.py builds/launcher
```

For the production bucket layout, upload with:

```bash
python3 tools/upload_launcher_release.py builds/launcher --layout updates
```

The CI workflow also uploads launcher app downloads to stable public URLs:

```text
https://updates.pokeaether.com/launcher/latest/PokeAetherLauncher-windows.zip
https://updates.pokeaether.com/launcher/latest/PokeAetherLauncher-linux.zip
```

GitHub Actions can upload to R2 automatically when these repository secrets are configured:

```text
R2_ACCOUNT_ID
R2_BUCKET
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
```

## Notes

- This is intentionally a first-pass launcher.
- Launcher self-update is implemented via launcher metadata in the manifest.
- Delta patching is not implemented yet.
