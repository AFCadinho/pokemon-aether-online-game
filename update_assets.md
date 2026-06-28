# Updating Sprite Assets

For music assets, use `update_music.md`. This document only covers Pokemon sprite packs.

Pokemon sprite assets are intentionally not stored in git because the files are too large. Keep the local folders under:

```text
assets/sprites/pokemon/
```

When sprites change, upload the changed sprite packs from a local checkout and then push the updated launcher manifest references.

## One-Time Setup

Create `.env` in the repository root:

```bash
R2_ACCOUNT_ID=...
R2_BUCKET=...
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
```

Do not commit `.env`. It is ignored by `.gitignore`.

## Update All Changed Packs

From the repository root:

```bash
set -a
source .env
set +a

python3 tools/upload_sprite_asset_packs.py
```

The script:

- scans each sprite pack folder
- computes a content hash per pack
- skips packs whose hash version is already in `.github/workflows/deploy-desktop-r2.yml`
- creates zip files for changed packs in `builds/asset-packs`
- uploads changed packs to R2 under `assets/`
- updates `.github/workflows/deploy-desktop-r2.yml` with new versions and sizes

## Update One Pack

If you know only one folder changed, run a targeted upload:

```bash
python3 tools/upload_sprite_asset_packs.py --pack pokemon-front
```

Available pack ids:

```text
pokemon-home
pokemon-front
pokemon-back
pokemon-shiny-front
pokemon-shiny-back
pokemon-gen5-front
pokemon-gen5-back
pokemon-gen5-shiny-front
pokemon-gen5-shiny-back
```

## Publish The New Manifest

After the script finishes, check the diff:

```bash
git status
git diff -- .github/workflows/deploy-desktop-r2.yml
```

If the workflow changed, commit and push:

```bash
git add .github/workflows/deploy-desktop-r2.yml
git commit -m "Update sprite asset pack versions"
git push
```

Pushing `main` runs GitHub Actions. The deploy workflow publishes launcher manifests that point to the R2 zips uploaded by the local script.

If the script prints `No sprite asset pack changes detected.`, there is nothing to commit or push.

## Launcher Behavior

The launcher downloads a sprite pack when:

- the manifest version for that pack changes
- the local required folder for that pack is missing

The launcher does not download individual sprite files. The smallest update unit is a pack, for example `pokemon-front` or `pokemon-home`.
