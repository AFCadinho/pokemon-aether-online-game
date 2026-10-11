# Shared-model R2 rollout

The existing public desktop manifests select `approved-pokemon-3d-v11`.
Changing its immutable ZIPs or index in place would invalidate the hashes
compiled into installed games and launchers. The qualified PCK collection also
requires the shared-model consumer code; the current local implementation
accepts it only through a debug opt-in.

## Completed staging, 11 October 2026

The [publication receipt](../release/shared_model_collection_r2_receipt.json)
records all **1,200 payloads and the exact compact index** passing full public
GET SHA-256 and HEAD size checks. **1,082 PCKs were uploaded and 118 existing
v11 ZIPs were reused.** The new uploaded payloads total 9,592,362,316 bytes;
the new index is 236,908 bytes. The seven known manifest paths were compared
before/after; six exist, one is absent, and all states remained unchanged.
Current desktop version **0.3.105 / v11** continues using its existing collection.
The [preflight](../release/shared_model_collection_r2_receipt.preflight.json)
pins the operation's source commit and the exact immutable object plan.

The [actual download check](../release/shared_model_public_download_checks.json)
passed on Linux/Godot 4.6.2 using the game's unmodified HTTP downloader and
the launcher release adapter, starting from an empty owned store. It fetched
the public compact index, accepted/planned all 1,200 entries, fetched/installed
Abomasnow and Mega Garchomp PCKs plus the retained Greninja/Inkay ZIPs, and
decoded all eight normal/shiny scenes after checked pack mounting. The
completed receipt and shutdown log contain no captured engine/script errors.
This check uses the debug opt-in; it is not a production-build/platform test.

Eight focused Python publication/receipt tests pass, including refusing an
existing bad key, changed upload inputs, incomplete/duplicate ID sets, wrong
payload/index hashes and forged activation flags. Offline full receipt
reconciliation and GDScript parse checks also pass. No full paired release
gate, main promotion, push, new build publication or player activation ran.

The original public manifest bytes are retained in the task's owned
`.tmp/shared-model-r2-rollout/previous-manifests/` evidence directory, matching
the preflight hashes. Raw HTTP test stores/logs remain owned by that task;
they were not copied to another checkout. Old R2 objects were not deleted.
This staging operation added **9,592,599,224 bytes** of R2 objects.
This is the temporary cost of retaining the existing collection;
it is not yet the final active-collection or account-storage saving.

## Immutable staging

`tools/publish_shared_model_collection.py` reads the retained readiness source
map and every physical payload in place. It reconciles all 1,200 entries with
the exact committed selection, renderer qualification and Linux readiness
record, then rehashes every input before any network access.

Its default mode is offline. Explicit `--apply` adds only missing immutable
objects to the existing update bucket. Existing objects with unavailable or
different public bytes are rejected; they are never replaced. Every PCK/ZIP
and the small compact index must pass a full public GET SHA-256 and HEAD size
check. The exact debug index is staged at its existing hash-pinned pilot key;
this does not make it an approved production descriptor.

The tool writes a preflight record before the first mutation, including the
source commit, object plan and hashes of all known public game/platform
manifests. Its final receipt is written only after all 1,200 payloads and the
index pass and the manifest snapshots remain unchanged. Credentials are read
from the existing authorized file in place and are never copied or recorded.
Interrupted staging leaves immutable additions available for a later retry;
it does not activate players or prove that queued uploads stopped instantly.
Use a fresh receipt path for retries so earlier preflight evidence survives.

`tools/verify_shared_model_publication.py` independently reconciles the completed
receipt's full ID set, immutable payload/index pins and public verification
outcomes. Its default mode is offline. `--remote` repeats all full public GET
hashes and HEAD checks without credentials or writes; it checks the manifests
for changes during that read-only run. An older manifest snapshot in a staged
receipt is historical evidence, not a requirement that the game never updates.

```sh
python3 tools/publish_shared_model_collection.py \
  --sources /absolute/retained-readiness/input.json

# Only for explicitly authorized R2 publication:
python3 tools/publish_shared_model_collection.py \
  --sources /absolute/retained-readiness/input.json \
  --credentials /absolute/existing/credentials --apply
```

## Player activation

Staging is a prerequisite, not a live migration. A production release must:

1. Bind exactly the same 1,082 qualified pairs and 118 v11 originals to a new
   immutable production revision in both game and launcher. Preserve the
   existing v11 pins, acceptance rules and model profiles for rollback.
2. Add release-build support for the qualified pair bindings and compact
   references. Do not expose the broader unqualified diagnostic catalog.
3. Exercise release-mode descriptor, download, installation, handoff and
   rollback behavior with those actual production bindings. Existing Linux
   renderer/session evidence remains valid only if the payloads and model
   behavior stay identical.
4. Publish and verify the new production index, then freeze/certify/promote
   the intended paired release through `ops/integration`. Build an updated
   game and launcher selecting that production revision before activating
   their public manifests. A model-file upload alone cannot update clients.
5. Check actual public manifest/archive/index downloads after activation and
   watch for installation/repair failures, missing normal/shiny appearances
   and newly reported crashes. Native Windows/macOS and physical Android
   smoke checks remain pending; do not call them completed Linux tests.

The user's decision to proceed on Linux evidence accepts the remaining
platform uncertainty. It does not change the historical evidence record's
`production_approved: false` or turn the diagnostic index into a release.
Android's current 2D production workflow remains a separate release path.

## Rollback and storage accounting

Retain the existing game/launcher archives, v11 index and its payloads while
the new release is observed. Rollback must restore compatible game/launcher
manifests and the previous index together. An old client cannot safely be
pointed at an index whose format/hashes it does not accept.

The new active collection has 9,844,999,677 bytes of installed model objects,
saving 3,011,912,272 bytes (23.43%). Its download payloads total 9,838,055,989
bytes, of which 9,592,362,316 bytes are shared PCKs and 245,693,673 bytes are
retained v11 ZIPs. These are distinct from total billed R2 storage.

Retaining old objects for rollback makes total R2 storage temporarily larger.
Do not delete old model objects simply because they are absent from the new
index: retained releases and already installed older clients may still request
them. Cleanup needs a separate reviewed reference/compatibility plan after
the new release is accepted. No model-object deletion is part of staging.

See [Linux readiness](shared-model-final-readiness.md),
[existing v11 release procedure](lossless-model-release-binding.md), and
[worktree/release rules](../AGENTS.md).
