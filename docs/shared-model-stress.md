# Shared-model pilot: session and interruption checks

Local Linux qualification of the existing 16-pair pilot, on Godot 4.6.2 and an
NVIDIA RTX 3070 Laptop GPU with Mobile Vulkan. The public v11 catalog and all
qualified model/texture bytes are unchanged. The debug pilot remains disabled
by default. These focused checks are not release certification.

## Session measurements

`shared_model_stress_check.gd` runs the actual battle presenter, threaded model
verification/loading, Pokédex and summary previews in one process. It installs
the qualified local collection, including the legacy Dragonite dependency, and
then changes encounter order between six complete sweeps of all 16 pairs.

- 96 battles, each loading normal and shiny, swapping appearances, applying
  sleep and retiring one actor while its counterpart remains available.
- 384 loaded previews and six canceled asynchronous preview selections.
- 2,940 texture weak-reference checks expire after actors, previews and the
  prepared-scene cache release their references. Duplicate references to the
  same shared texture are counted as checks, not distinct images.
- Two-entry / 64 MiB source-admission cache limits hold during loading. Idle
  checkpoints explicitly clear that cache to distinguish live ownership from
  allowed retained scenes.
- Exactly 16 mounted packs, namespaces and checked dependency closures remain
  through every sweep. Their serialized registry size stays at 8,375 bytes;
  this measures the three application registries, not Godot's native PCK index.
- Idle resource/node/orphan counts remain 792 / 400 / 0. GPU texture and buffer
  monitors remain 167,753,728 / 11,010,460 bytes after the first sweep.
- Godot debug static allocations grow 3,619,444 bytes (3.45 MiB) between the
  first and sixth sweep, below the predeclared 16 MiB diagnostic bound. This is
  a bounded observation, not a claim of zero allocation growth.
- Linux RSS fluctuates between 773,214,208 and 1,351,704,576 bytes at post-warm-up
  checkpoints and finishes below the first warm checkpoint. RSS includes native
  allocator/driver behavior and is not interchangeable with Godot's static or
  GPU monitors.

The workload takes 333.41 seconds and captures no engine/script errors. The
graphics harness focuses its visible window before each battle; production
render-warm gates and timeouts are unchanged. Performance monitor checkpoints
wait at least 1.1 seconds because Godot documents a possible one-second update
delay in its [monitor API](https://docs.godotengine.org/en/4.6/classes/class_performance.html).

An independent headless `shared_model_mount_budget_check.gd` checks all 379
declared PCK members without creating actors or shaders. After the first
verified mount, the next 15 packs add 419,576 bytes to the debug static monitor,
including diagnostic bookkeeping and native dependency/path caches. Five more
sweeps (80 mount requests) add 852 bytes, keep resource counts unchanged and
retain exactly 16 indices/closures. Its registries serialize to 7,575 bytes;
physical path lengths differ from the installed session fixture. The large
first-use allocation delta is recorded separately in the raw receipt and must
not be treated as a uniform per-pack cost or extrapolated to 1,200 pairs.

## Interrupted installation and updates

The new Linux runner builds a test-only `LD_PRELOAD` library and starts fresh
Godot processes with separate task-owned userdata/config/cache/log paths. It
injects actual SIGKILL at scoped file-copy/rename boundaries. The library is
never linked into, preloaded by or exported with the game or launcher.

The 20 interruption cases cover both byte-identical installer copies:

- New install: during the first MiB copy, after verified staging but before
  publication, and immediately after publication, for both game and launcher.
- Corrupt owned-pack repair: those three points plus the gap after the previous
  object is quarantined, for both installer copies.
- Launcher update: copying, completed staging, object publication, generation
  publication, moving the active pointer to its previous pointer and publishing
  the new active pointer. All six restart with a complete old or new catalog,
  finish the update, explicitly roll back to the prior generation, reactivate
  the completed update and run safe garbage collection.

Before the fix, all 20 kills were injected as intended, but 12 new-install or
repair restarts retained staged/quarantined model copies. After the fix, all
63 worker invocations pass, including all 20 kills and their restarted checks.
New-install/repair stores contain exactly one verified object after recovery.
Update fixtures derive a new metadata/versioned pack from checked original
members; they do not replace any checked-in pilot or public asset bindings.

Installation now records the complete trusted ownership metadata before copying
the large pack and includes the creator PID in staging/quarantine names. A retry
verifies its input first, recognizes artifacts of terminated processes only,
reuses a completely verified staged pack and removes owned abandoned copies
after successful publication. If both publication and restoring the previous
directory fail, it retains both recoverable copies for the next retry.

Recovery skips live PIDs, mounted files, linked entries, extra/unknown contents
and older pilot artifact names without process ownership evidence. Ownership
metadata remains until its potentially large payload is deleted. Cleanup is
best effort if filesystem permissions prevent removal. A game lease also defers
recovery of a quarantined object until restart. Cross-process checks follow the
existing lease implementation; Godot's
[child-process check](https://docs.godotengine.org/en/4.6/classes/class_os.html#class-os-method-is-process-running)
alone cannot identify an unrelated active installer.

`shared_model_recovery_ownership_check.gd` verifies invalid-source isolation,
dead-process cleanup, complete-stage reuse, preservation of the current process
and an unrelated live parent, links and their targets, unknown files, deferred
quarantine recovery, unknown destinations and corrupt mounted-pack protection.
Game/launcher validator byte parity also remains checked.

## Reproduction and evidence

Use an assigned frontend slot and run every Godot/Python command through
`ops/worktrees/slot-env SLOT --`. Input packs may be read in place from the
retained qualified preparation; tests create their own stores and derived
fixtures. Do not copy another slot's caches, userdata or configuration.

```sh
godot --log-file /absolute/task/stress.engine.log --rendering-method mobile \
  --path /absolute/assigned/frontend \
  --script res://tests/shared_model_stress_check.gd -- \
  /absolute/qualified/packs /absolute/task/stress.json 6

godot --log-file /absolute/task/mount.engine.log --headless \
  --path /absolute/assigned/frontend \
  --script res://tests/shared_model_mount_budget_check.gd -- \
  /absolute/qualified/packs /absolute/task/mount.json

python3 tools/run_shared_model_crash_checks.py \
  --packs /absolute/qualified/packs --output /absolute/assigned/frontend/.tmp/FRESH-CRASH-CHECK

godot --log-file /absolute/task/ownership.engine.log --headless \
  --path /absolute/assigned/frontend \
  --script res://tests/shared_model_recovery_ownership_check.gd -- /absolute/qualified/packs
```

The installation fixture also expects the retained v11 dependency archives
beside the original preparation. Existing 16-pair installation/semantic checks,
independent launcher release checks and the legacy bundle-store regression are
rerun. Evidence hashes, host limits and the workload summary are committed in
`data/shared_model_stress_checks.json`; detailed receipts/logs remain in the task
slot's `.tmp/shared-model-stress-v1` directory.

## Remaining qualification

These checks bound repeated use of the 16 qualified pairs. They do not measure
the full catalog's storage saving, native index growth across 1,200 distinct
pairs, physical phone RAM, player FPS or an overnight session. Native
Windows/macOS installation, repair, update, cleanup and process detection still
need qualification. SIGKILL tests cover process interruption, not filesystem
durability after power loss. Broader catalog bindings/quality checks and the
separately authorized release gate remain required before player activation.
