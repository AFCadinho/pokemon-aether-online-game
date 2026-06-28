# Updating Music Assets

Music assets are intentionally not stored in git because the files can become large. Keep the local folders under:

```text
assets/music/
```

Use `.ogg` files for music. The upload script rejects other packaged music formats so MP3s do not accidentally end up in launcher asset packs.

## One-Time Setup

Create `.env` in the repository root:

```bash
R2_ACCOUNT_ID=...
R2_BUCKET=...
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
```

Do not commit `.env`. It is ignored by `.gitignore`.

## Convert Music To Ogg

For new MP3 source files, convert them locally before uploading:

```bash
ffmpeg -i "input.mp3" -c:a libvorbis -q:a 5 "output.ogg"
```

Keep only the `.ogg` files under `assets/music/`.

## Update The Music Pack

From the repository root:

```bash
set -a
source .env
set +a

python3 tools/upload_music_asset_packs.py
```

The script:

- scans `assets/music`
- computes a content hash for the music pack
- skips the pack when its hash version is already in `.github/workflows/deploy-desktop-r2.yml`
- creates a zip file in `builds/asset-packs`
- uploads the changed pack to R2 under `assets/`
- updates `.github/workflows/deploy-desktop-r2.yml` with the new version and size

## Publish The New Manifest

After the script finishes, check the diff:

```bash
git status
git diff -- .github/workflows/deploy-desktop-r2.yml
```

If the workflow changed, commit and push:

```bash
git add .github/workflows/deploy-desktop-r2.yml
git commit -m "Update music asset pack version"
git push
```

Pushing `main` runs GitHub Actions. The deploy workflow publishes launcher manifests that point to the R2 zip uploaded by the local script.

If the script prints `No music asset pack changes detected.`, there is nothing to commit or push.

## Launcher Behavior

The launcher downloads the music pack when:

- the manifest version for `music` changes
- the local `assets/music` folder is missing

The launcher does not download individual music files. The smallest update unit is the `music` pack.
