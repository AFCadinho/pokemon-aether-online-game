# PokeAether Workflow

This project separates source-code pushes from playable client releases.

## Daily Development

Use normal Git pushes for code changes:

```bash
git push origin main
```

A normal push updates the repository only. It does not build Windows, Linux, or macOS clients, it does not publish new launcher manifests, and players do not receive an update.

This keeps small commits, typo fixes, and work-in-progress changes from becoming public game updates.

## Local Checks

Run all current headless project checks from the repository root:

```bash
godot --headless --path . --script res://tests/run_project_checks.gd
```

This runs the standalone `tests/*_check.gd` scripts, including the PokeAether TMX importer fixture check. The TMX importer check generates only fixture output under `res://generated/maps/` and cleans it up before exiting. Per-check Godot logs are written to `/tmp/pokeaether_project_checks/`.

## Publish A New Client Build

When you want players to receive a new build:

1. Push the code you want to release to `main`.
2. Open GitHub.
3. Go to **Actions**.
4. Select **Deploy Desktop Builds to R2**.
5. Click **Run workflow**.
6. Fill in `release_version`, for example `0.2.0`.
7. Set `build_launcher` to `true` only when the launcher app itself changed.
8. Set `announce_discord` to `true` if this release should be posted to Discord.
9. Optionally fill in `release_notes`.
10. Wait until the workflow finishes successfully.

After a successful run, the workflow uploads the new game zips and launcher manifests to R2. The launcher then sees the new manifest version and downloads the update.

## Changelog

Keep release notes in `CHANGELOG.md`.

The changelog is for players. Write entries in clear, non-technical language that explains what changed in the game experience. Avoid implementation details, internal filenames, API names, and developer-only wording.

The changelog uses Discord-friendly Markdown on purpose:

```md
**Added**
- Added a new feature.

**Fixed**
- Fixed a reported bug.

**Changed**
- Changed an existing behavior.
```

During development, add finished changes under `## Unreleased`. When publishing a release, rename the current `## Unreleased` section to the new version, for example `## 0.2.1 - 2026-06-28`, then add a new empty `## Unreleased` section above it.

For Discord, copy the release section contents from `CHANGELOG.md` into the workflow's `release_notes` field and add `Open the launcher to update.` at the end.

## GitHub CLI

The same release workflow can be started from the terminal:

```bash
gh workflow run deploy-desktop-r2.yml \
  --ref main \
  -f release_version=0.2.0 \
  -f build_launcher=false \
  -f announce_discord=true \
  -f release_notes="Open de launcher om de nieuwste build te downloaden."
```

Use `build_launcher=true` when files under `launcher/`, launcher export settings, or launcher packaging changed.

## Discord And Website Updates

Discord announcements are release announcements, not commit announcements.

The old per-push Discord workflow has been removed because a normal push no longer means a playable build exists.

For public releases:

1. Run the deploy workflow.
2. Let the workflow post to Discord with `announce_discord=true`, or post manually after the workflow succeeds.
3. Update website or launcher news with the same release notes when needed.

## Versioning

Use plain game versions for `release_version`, such as:

```text
0.2.0
0.2.1
0.3.0
```

The release version is written into the launcher manifest and into the generated game zip names.

## Private Repository Notes

Public repositories can use standard GitHub-hosted Actions runners without consuming paid minutes. Private repositories use the account's included Actions minutes and storage first, then billing or limits apply depending on the account settings.

Because this repo no longer builds all three desktop platforms on every push, switching the repo back to private should be much easier to keep within the free included Actions usage. Still check GitHub's billing page after the first few manual releases, because full Godot exports for three platforms can use a meaningful amount of runner time.
