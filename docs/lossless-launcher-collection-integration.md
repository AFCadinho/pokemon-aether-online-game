# Streamed complete-model downloads

Local task `lossless-launcher-collection`, slot-b, 2026-10-06. This follows
the [renderer correction](lossless-source-overlap-resolution.md) and
[collection store qualification](lossless-model-rollout-validation.md).
Published pins and approved model hashes remain unchanged. Smaller bundles
are still unpublished candidates.

## Launcher behavior

The Downloads page and opted-in model updates now stage each verified ZIP into
an immutable object, remove that completed ZIP, and activate one generation
only after all selected models pass final validation. Existing models remain
active during downloading, pausing, failure and restart. This avoids both
keeping a collection's worth of temporary ZIPs and repeatedly hashing the
entire growing installed catalog after every individual ZIP.

Planning reconstructs completed objects against the checked release index.
They are reused after a restart without trusting a separate recovery ledger.
Incomplete HTTP bodies retain the downloader's existing version/hash identity
and resume through Range requests. The Resume button replans before continuing
and cannot start a second planner while one is running. A complete staged
collection with zero remaining downloads still has an activation job in the
normal update queue.

The active-generation identity must still match the planning snapshot at final
activation. A concurrent installed-state change is rejected, rather than lost.
Final checks independently validate every requested object and manifest.
Unknown release pins and immutable-version checksum changes remain rejected.

Free space is checked on the actual download volume before each model transfer
and on the store volume against the ZIP's declared extracted sizes before
unpacking, with a 32 MiB metadata reserve. These are per-file checks, not an
exact upfront guarantee for the entire collection: indexes currently do not
declare extracted byte totals and other applications can consume disk space.
Write failures still leave the current generation active. The new player-facing
disk-space message is translated in all four launcher languages.

Old immutable objects and generations are retained for rollback. This task
does not run destructive garbage collection. The approximately 35% saving
previously measured is for active candidate models/downloads; retaining old
versions increases total disk use during and after an update. Explicit store
cleanup remains available through its existing API and is not enabled here.

## Focused evidence

Full evidence is retained in `.tmp/lossless-collection-v1/`, including failed
setup attempts. The completed HTTP run is `http-qualified/`:

- Current compiled release pins reject the unpublished candidate fixture.
- Generated future pins use the actual adapter, store, downloader and launcher
  UI/queue; no admission/checksum method is overridden.
- Eleven original bundles are installed. After the first ZIP is staged, the
  second transfer is paused at 1,048,576 bytes. No active prefix is published.
- A separate engine process recovers the staged first bundle, schedules only
  ten remaining bundles and resumes the interrupted body from 1,048,576 bytes.
- Eleven smaller 256 KiB / Zstd level 9 bundles update the same collection.
  The actual Pause/Resume handlers are exercised within the same process and
  again reuse 1,048,576 bytes of the interrupted body.
- Each completed phase independently checks all 22 installed normal/shiny
  file hashes and deserializes every SCN with `CACHE_MODE_IGNORE`. A new adapter
  plans no repeated downloads.
- Rollback uses the normal update queue, with zero network downloads, and
  restores all 22 original file hashes. Completed ZIPs do not accumulate.

The sample's original/smaller ZIP totals remain 365,356,392 / 241,229,040 bytes
(33.97% saving); this is not a new full-catalog UI measurement. The previously
prepared 1,200-bundle catalog's 35.27% saving remains a separate measurement.
The tests are on Linux/Godot 4.6.2 with localhost HTTP; they do not establish
Internet throughput or an installation speed improvement.

`asset_bundle_store_check.gd` passes stream/restart, incomplete/corrupt-member
isolation, malformed recovery metadata, post-staging tampering, rollback,
stale-generation rejection, immutable identity and simulated disk exhaustion.
Existing batch, removal and GC cases also pass. The Downloads UI check passes
including 1,139-record metadata, 2D behavior, preferences and resume guards.
The unchanged published v10 check passes for all 1,200 IDs. Python compilation
and whitespace checks pass. Cold UI fixtures retain existing scene UID fallback
warnings; the HTTP runner independently rejects all actual script/engine errors.

## Remaining rollout work

Windows and macOS native loading, updating and rollback have not been exercised
by this task. The desktop workflow exports on Ubuntu and does not provide those
native runtime checks. Wine is installed locally, but no Wine result is claimed
as native Windows qualification. No platform runner, CI workflow or publication
was triggered.

Before publication, qualify the selected immutable candidate set on supported
desktop systems and decide the retained-history cleanup policy. Release
certification and explicit publication authorization remain separate. This
launcher-only task does not alter model pixels, geometry, textures, animation,
rendering settings or cache budgets, so it does not repeat renderer/performance
qualification already recorded in the preceding tasks.

## Reproduction

With the retained source-only local fixture, run through the assigned slot:

```sh
ops/worktrees/slot-env slot-b -- python3 \
  .worktrees/slot-b/frontend/launcher/tests/run_native_compression_install_check.py \
  /ABSOLUTE/PATH/TO/fixture.json \
  .worktrees/slot-b/frontend/.tmp/FRESH-OUTPUT --streaming
```

The runner references tracked source assets/scripts in place, creates fresh
project caches and a test-specific user directory, and generates future pins
inside those projects. It never copies existing caches, builds or userdata.
