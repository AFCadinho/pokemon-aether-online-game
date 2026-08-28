# PokeAether frontend instructions

## Assigned worktree required

- Agents may develop only in an explicitly assigned frontend worktree under
  `game/.worktrees/slot-a`, `slot-b`, or `slot-c`.
- Never edit the normal `pokemon-aether-online` checkout. It is reserved
  for integration, final tests, releases, comparison, review, and recovery.
- A task that also changes the backend must use the backend worktree from the
  same assigned slot. One slot belongs exclusively to one task or agent.
- Do not touch the legacy worktrees `main-quest-oaks-parcel` or
  `pvp-turn-sync` unless the user explicitly creates a separate recovery task
  for one of them.

## Local Godot state and assets

- Do not generally copy or synchronize untracked or ignored files. Use only
  `game/ops/worktrees/bootstrap-slot` and its reviewed allowlist.
- Never copy, share, synchronize, or remove `.godot` or `launcher/.godot`.
  Each frontend worktree owns its permanent import caches.
- Never copy `.env` files, credentials, secrets, sessions, userdata, builds,
  logs, local databases, or machine-specific configuration between checkouts.
- Run Godot commands through `game/ops/worktrees/slot-env SLOT -- COMMAND` so
  userdata, configuration, cache, and test logs remain local to the slot.
- Run only the directly relevant Godot check scripts while developing a task.
  Reserve `tests/run_project_checks.gd` for the complete development batch or
  an explicitly useful full verification.

## Branches and handoff

- Task branches start from the current local `development`, never from
  `origin/main`. They are merged back into `development` as part of the next
  complete release batch.
- Do not merge into `main`, push `main`, publish builds, or trigger releases
  unless the user explicitly requests it.
- Commit all intended changes, or clearly identify deliberately uncommitted
  work.
- At handoff report commit IDs, changed repositories, tests run, and remaining
  risks.
- Worktrees remain after the task. Delete a feature branch only after its
  integration status has been checked and deletion is explicitly intended.
