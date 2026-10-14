# Lossless model release v16

The complete collection contains 1,420 model pairs (2,840 normal/shiny
appearances), plus one shared texture archive. Its payloads total
**6,989,696,054 bytes**, down from v15's 8,795,326,138 bytes: a saving of
**1,805,630,084 bytes (20.53%)**. The immutable content index is additional.
This is the active collection size, not total billed R2 storage while older
releases remain available for rollback.

The release uses the already measured strict lossless texture encodings.
Decoded pixels, authored mip levels, texture metadata, scene properties and
animations must match the approved v15 sources. Unsupported higher-precision
or compressed source images stay unchanged. The 55 ZIP pairs stay byte exact.
The eight Minior pairs use the previously qualified shared texture archive;
other pairs retain their own exact resources. Native resource bodies remain
unchanged when assigning fresh archive namespaces. Historical absolute main
resource names are preserved, without treating them as external dependencies.

The game and launcher default to v16 and retain the v15, v14 and v13 compiled
bindings. Contract 3 binds every shared texture dependency to its complete
immutable metadata. Pools install and mount before their consumers. Failed
downloads cannot publish partial model catalogs; damaged pools are revalidated
and repaired, and mounted archives remain protected from removal.

## Qualification and publication

`package_approved_3d_release_v16.py` reads the retained hash-bound studies in
place and writes new archives only under the assigned slot. The full native
qualification compares every repackaged normal/shiny scene and its deep
duplicate with v15, including animation poses. Each concurrent test process
owns a separate minimal project, import cache and userdata namespace.

The runtime qualification uses the full compiled v16 index with loopback HTTP.
It checks failed and damaged pool downloads, transactional launcher staging,
game handoff, actual battle/preview loading, eviction and a fresh-process restart.
`seal_approved_3d_release_v16.py` binds these results and standalone launcher
admission to the exact source hashes. Linux results do not certify native
Windows/macOS execution or a physical Android device.

The completed native receipt covers all 1,365 PCK model pairs, 2,730
appearances and 66,969 animation samples. Complete scene states and deep
duplicates match v15. The runtime receipt records 16 battles and 32 preview
appearances across cold and restart processes, including injected HTTP failure,
pool corruption repair and zero restart downloads. These receipts are
`release/approved_3d_v16_native_qualification.json` and
`release/approved_3d_v16_runtime_qualification.json`.

The R2 publisher defaults to offline validation. With explicitly authorized
`--apply`, it prehashes every retained source, uploads immutable objects and
verifies full public GET hashes and HEAD sizes. It records the object plan and
manifest snapshots before mutation and refuses to overwrite a mismatching key.
Active manifests must remain unchanged throughout this upload.

Freeze the paired game release, publish the immutable model collection from
the release worktree, commit its publication receipt, sync release fixes and
run the final paired certification before promotion. The desktop workflow must
use `approved_3d_release=v16` and `build_launcher=true`. Android must use
`experimental_3d=true`; it keeps the player's 2D/3D choice and defaults to 2D
until the player chooses. Publish Android only after its signed candidate passes.

Keep the previous compatible game/launcher manifests and model objects for
rollback. This release does not delete old model objects. Retirement requires
a separate reviewed reference and compatibility plan after observation.

## Release export and public delivery checks

The actual Linux release template selects v16 with diagnostic environment
flags disabled by the release build. The game owns its index helper under
`scripts/services/asset_bundle_index.gd`; its bytes match the launcher helper.
Keeping this dependency inside the game project fixes the exporter omission
caused by the nested launcher project. The full compiled-index cold/restart
checks passed again after this consumer-only fix. The existing full native
model proof remains valid because the payloads and native reader stayed exact.

All 1,421 archives and the immutable index passed public GET hashes and HEAD
sizes. Their publication receipt was rebound to the qualified consumer fix
only after checking the retained committed binding, unchanged payload pins and
native proof, fresh public HEAD checks and an exact index GET. Live manifests
remained unchanged. A separate real HTTP check loaded eight appearances for
Hydreigon, Tyranitar and two pooled Minior forms, and verified cached reuse.
Two missing historical Garchomp fixtures in the owned QA cache triggered
conservative history-retention warnings; all requested new models verified.
