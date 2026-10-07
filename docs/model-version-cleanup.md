# Local 3D model version cleanup

Production launchers enable `prune_previous_models` on their release bundle
store. After a fully verified generation activates, superseded model objects
are removed. Startup also checks existing installations, covering older model
history retained before this policy. Installation checks, approval hashes,
model contents and the atomic active-pointer switch are unchanged.

Cleanup reads the current pointer directly. Invalid current metadata or failed
replacement checks keep previous files; the previous pointer is never used as
deletion authority. Only owned Pokémon bundle directories with an older
version of an installed asset qualify. Active references and completed future
collection members remain protected. Unknown files and linked directories are
skipped. Warm starts with no superseded model objects avoid a full model hash
scan. Installation cleanup runs on the install worker; startup cleanup runs on
a separate worker while launcher actions are locked.

A game process registers a small PID marker under the launcher model store.
A later launcher recognizes live processes even when the launcher that started
them has exited. Exported games predating these markers are protected by their
process names. Cleanup is deferred while a game may use an older catalog; the
next launcher start retries it. Process-query failures also defer cleanup.
PID reuse can conservatively delay cleanup. Linux uses `/proc` for PID checks;
Windows uses `tasklist`, and macOS uses `ps`.
The game and launcher write the same lease format independently; the game has
no dependency on launcher scripts excluded from Android/browser exports.

The game's separate on-demand store prunes obsolete owned object directories
after catalog publication and during startup. It checks surviving model hashes,
protects every referenced object and every object in the selected approved
index, and leaves resumable current downloads and unrelated files untouched.
Storage work stays off the frame thread. Pending callbacks finish before the
service Node is destroyed.

Old model data is not kept solely for local rollback. Reinstalling an earlier
approved version requires its archive again. Temporary old files remain during
failed/incomplete installation or while a running game still uses them.

## Focused verification

- Launcher store: failed replacements, active-game deferral, corrupted current
  models, exact active normal/shiny hashes, resumable future objects, restart,
  and no full scan on a warm cleanup. Existing streamed installation, checksum,
  batch atomicity, low-space and metadata handoff checks remain intact.
- On-demand store: publication boundary, corruption, both surviving appearances,
  current staged downloads, unrelated files, repeat cleanup and worker execution.
- Existing bulk-download, desktop asset-storage and Pokédex contracts.
- Linux launcher PCK export and the store checks run from that packed export,
  verifying the new process-usage helper ships with the launcher.

Runtime checks are local Linux/Godot 4.6.2. Windows process-output parsing is
covered by fixtures; native Windows/macOS cleanup qualification remains part of
the next platform release checks. No production storage or release is changed
by this task.
