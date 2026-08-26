# PokeAether Launcher

Small Godot launcher project for PokeAether.

## Current flow

1. Downloads `manifest.json`.
2. Compares remote versions with `user://versions.json`.
3. Downloads files of at least 8 MiB over four bounded HTTP byte ranges in parallel.
4. Keeps each segment in a persistent partial file so interrupted parallel downloads resume safely.
5. Falls back to the single-connection downloader when an origin does not honor bounded ranges.
6. Resumes interrupted downloads with validated HTTP byte ranges and bounded retries.
7. Verifies every completed zip against its manifest size and SHA-256.
8. Extracts into a staging folder and only replaces the installed game or asset pack after extraction succeeds.
9. Starts the configured game executable.

The launcher records periodic speed samples, stalls, reconnects, resume offsets,
HTTP range responses, and the Cloudflare edge code in its local diagnostics log.
It never uploads diagnostics automatically. URL query values and local userdata
paths are redacted before logs are displayed or copied.

Every published game also has an immutable `game.buildId`. CI derives it from
the Git commit, workflow run, and run attempt, stamps it into the exported game,
and writes the same value to the launcher manifest. The launcher compares this build ID,
so a new build is downloaded even when the human-readable release version was
left unchanged. The gateway consumes the same manifest to reject obsolete
clients during authentication and new realtime handshakes.

Asset packs marked with `"optional": true` are skipped by the normal update flow. For Gen 5 animated Pokemon sprites, set `"autoUpdateIfInstalled": true` in the manifest when a user already has the Gen 5 folder installed; then the launcher will auto-update those packs on startup while still keeping the manual install button hidden when the folder is already present.

The default install folder is `user://game`. Players can choose a custom install folder from the launcher Game Folder button; that choice is saved in `user://launcher_settings.json`.

Launcher news is loaded separately from the update manifest through `newsUrl`
in `config/launcher_config.json`. The expected shape is documented in
`config/news.example.json`.

The production feed at `data/news.json` is generated from public topics in the
Discourse `Official Announcements` category (category ID 17). A signed
Discourse topic webhook asks the Cloudflare Worker in
`infrastructure/forum-news-worker` to rebuild the feed immediately. The Worker
uses its direct R2 binding, preserves the previous valid object as
`data/news.previous.json`, and publishes only when the content changed. A daily
Cloudflare Cron Trigger reconciles missed webhook deliveries; there is no
scheduled GitHub Actions polling job. Invalid, private, or empty category data
fails without replacing the current feed.

## Configure

Update `config/launcher_config.json`.

`statusUrl` points to the public game-login availability endpoint (normally
`https://pokeaether.com/auth/status`). This is separate from infrastructure
health so planned maintenance can show its player-facing message and disable
Play without marking the gateway itself unhealthy. `healthUrl` remains a
legacy configuration fallback.

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

Run the automated interrupted-download and resume checks with:

```bash
python3 launcher/tests/run_resumable_download_check.py
```

The default launcher config points at:

```text
http://127.0.0.1:8000/manifest.json
```

## Package A Real Build

First export the game with the existing Godot export presets. Then package the exported files:

```bash
python3 tools/package_launcher_release.py \
  --version 0.1.0 \
  --build-id "$(git rev-parse HEAD)" \
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

When `--build-id` differs from the display version, the immutable build ID is
included in the game ZIP name. Rebuilding display version `0.1.0` therefore
creates a new object instead of overwriting a cached release.

For a public release, use the real hosted URL as `--base-url` and the production URL prefixes:

```bash
python3 tools/package_launcher_release.py \
  --version 0.1.0 \
  --build-id "$(git rev-parse HEAD)" \
  --base-url https://updates.pokeaether.com \
  --game-prefix game \
  --asset-prefix assets \
  --include-launcher \
  --launcher-prefix "launcher/0.1.0-$(git rev-parse HEAD)" \
  --output-dir builds/launcher \
  --default-platform linux
```

The production R2 bucket uses this layout:

```text
manifest.json
manifest-linux.json
manifest-macos.json
manifest-windows.json
data/news.json
data/news.previous.json
launcher/latest/PokeAetherLauncher-linux.zip
launcher/latest/PokeAetherLauncher-macos.zip
launcher/latest/PokeAetherLauncher-windows.zip
launcher/0.1.0-<build-id>/PokeAetherLauncher-linux.zip
launcher/0.1.0-<build-id>/PokeAetherLauncher-macos.zip
launcher/0.1.0-<build-id>/PokeAetherLauncher-windows.zip
game/game-0.1.0-<build-id>-linux.zip
game/game-0.1.0-<build-id>-macos.zip
game/game-0.1.0-<build-id>-windows.zip
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
export R2_BUCKET="pokemon-aether-updates"
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

The production workflow performs this automatically. It uploads uniquely named
artifacts first, verifies their public sizes, and publishes the stable manifest
URLs last. R2 prefixes are object names rather than folders, so no bucket
directory setup or migration is required.

After the stable manifests are published, the workflow also prunes obsolete
immutable objects under `game/` and `assets/`. The cleanup reads both the newly
generated and live manifests, retains every referenced object plus one previous
version per game platform or asset pack, and never deletes objects younger than
24 hours. Unknown object names and stable aliases such as `game/latest/` are
outside the deletion allowlist. Set the workflow's `cleanup_r2` input to false
to skip cleanup for an exceptional release.

The cleanup tool defaults to a dry-run when used locally:

```bash
python3 tools/prune_r2_release_objects.py builds/launcher
```

Actual deletion additionally requires `--apply`; use the workflow for normal
production cleanup so publication and pruning retain their safe ordering.

## Upload Sprite Asset Packs

Pokemon sprite packs are intentionally kept out of git. When sprite files change, package and upload them from a local checkout that has `assets/sprites/pokemon` populated:

```bash
python3 tools/upload_sprite_asset_packs.py
```

This writes zip files to `builds/asset-packs`, uploads them to R2 under `assets/`, and updates `.github/workflows/deploy-desktop-r2.yml` with the new asset versions, sizes, and zip SHA-256 values. Commit and push that workflow change so the launcher manifests reference the new packs. The launcher downloads a pack again when its manifest `version` changes, and also redownloads required packs when the local asset folder is missing.

The script uses content hashes for versions and skips packs whose computed version is already in the workflow. That means unchanged packs are not uploaded again and users do not redownload them.

For the Mega Champions Phase 3 audit, all 49 catalog forms have complete exact
battle sprite sets. Fifteen mappings are pinned to Generation 9 Pack 3.3.6 in
`data/mega_champions_sprite_imports.generated.json`: the twelve formerly
missing mappings plus corrected form indexes for Floette, regular Magearna,
and Zygarde. Credits and source hashes are recorded in
`assets/sprites/README.md`; the source bundle does not declare a license.

Release publication fails when any artifact is missing a valid SHA-256 or exact
size, or when its public URL does not return a correct `206 Partial Content`
response for a one-byte Range request. Stable manifests are still uploaded last.

To upload only one changed pack:

```bash
python3 tools/upload_sprite_asset_packs.py --pack pokemon-front
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
