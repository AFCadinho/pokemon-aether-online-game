# PokeAether workflow

This page points to the current procedures. Work from the paired `game/`
workspace, where the frontend and backend `development` branches are integrated
together.

## Development

- Read this repository's `AGENTS.md` and the workspace's `AGENTS.md` first.
- Reserve a paired slot with `ops/worktrees/list-slots` and
  `ops/worktrees/prepare-task`. Make frontend changes only in its assigned
  worktree.
- Run focused checks in that slot. Use `ops/worktrees/slot-env` for Godot.
- Commit the task, merge it into local `development` with
  `ops/integration/merge-task`, then release the slot with
  `ops/worktrees/finish-task`.

The detailed procedures are in `game/ops/worktrees/README.md` and
`game/ops/integration/README.md`. The complete paired verification gate is for
an explicitly requested certification or the final check before promotion.

## Release

Promotion to `main`, pushing, publishing, deployment, and production access
each require explicit authorization. Follow the current integration procedure
before promotion. For an authorized release, consult the current workflow
definitions under `.github/workflows/` for their actual inputs and sequence;
do not use old release commands copied from notes or chat.

Keep player-facing notes in `CHANGELOG.md`. Add completed changes under
`## Unreleased` during development, then prepare the release section as part of
the approved release work.

Sprite and music package procedures are in `update_assets.md` and
`update_music.md`. Their upload steps are production actions and require the
same explicit authorization.
