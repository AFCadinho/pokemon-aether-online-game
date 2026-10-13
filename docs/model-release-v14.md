# Model release v14 and game/launcher 0.3.108

The coordinated release adds 220 normal/shiny pairs to the 1,200-pair v13
collection, including the Therian trio and Rapid Strike Urshifu. The original
229-form gap audit is complete: 216 newly packaged pairs and 13 verified shared
forms, plus the four separately repaired Therian/Urshifu pairs. Existing alias,
scale, sleep, visibility and source qualification receipts remain historical
checkpoints and are retained unchanged.

The active collection contains 1,420 pairs / 2,840 appearances: 1,365 shared PCKs
and 55 ZIPs, totalling 8,993,498,070 bytes (8.99 GB). Recompressing the existing
1,200 pairs saves 1,029,628,070 bytes without changing decoded native resource
bytes. The new 220 pairs add 1,334,349,732 bytes. Download payload is therefore
larger than the previous 1,200-pair collection, while each existing pair is
smaller. This is the selected payload size, not the R2 billed total; previous
immutable objects remain available for rollback.

## Binding and upgrade

Game and launcher compile identical v14 descriptors, wire index and trusted
PCK catalog. Compact references expand only against compiled, hash-pinned
metadata. The exact v13 descriptor/index and its trusted PCK metadata remain
accepted for historical installations. A mixed revision/hash/ID tuple or a
forged compact reference is rejected. The launcher is rebuilt for the new set.

All 1,200 recompressed bundles receive an incremented immutable version and a
new hash-named object key. Only the outer bundle manifest version is changed
when repacking the measured compression candidates. Every native member stays
byte-identical, and the repacker reopens and compares the persisted container.
Resource namespaces remain unchanged; native model loading across an update
happens in a fresh game process. Existing same-version/different-hash rejection
is retained.

The 55 ZIP pairs add their exact new compressed scene hashes to reviewed hash
history. Their current source identity and every existing profile stay intact.
`release/approved_3d_v14_binding.json` binds the previous and approved model
records, decoded-byte proof, source qualification pins, complete catalog,
upgrade reports and release code. Historical regressions restore only these
explicit, bounded hash-history additions and still compare their original
checkpoints exactly.

The actual compiled pin check covers all 1,420 pairs and resolves all 2,840
appearances. Upgrade controls install seven old pairs (geometry-sharing,
texture-sharing and ZIPs, including Hydreigon, Tyranitar and repaired Mega
Hawlucha), update them and install four new pairs, then restart and load all 22
appearances. The four new controls are Landorus Therian, Rapid Strike Urshifu,
Ash-Greninja and Rock Star Pikachu. A failed batch preserves the active
generation, a restart requests no installed objects again, and a separate
rollback process restores and loads all 14 original control appearances.

These installation/instantiate checks use Linux Godot 4.6.2 and Compatibility
rendering. The initial Dummy/headless original-scene instantiation produced
material lifetime errors; it is retained as a failed harness run and grants no
qualification. The successful original/update/rollback checks use the real
renderer and wait for frame completion before releasing actors. Existing
whole-collection native decoding and isolated engine qualification remain
pinned by `release/v13_full_compression_audit.json`. This release adds no native
Windows/macOS or physical Android GPU certification.

## Publication and builds

`publish_approved_3d_index_v14.py` reads retained archives in place, uses fresh
immutable keys, verifies public GET SHA-256 and HEAD size, then publishes the
index. It checks that desktop/Android/browser manifest snapshots did not change
while uploading. `release/approved_3d_bundles_v14_r2_receipt.json` is the complete
publication authority. CI verifies that receipt, rechecks every payload HEAD
and publishes/verifies the exact index before packaging the desktop manifest.

Desktop workflow inputs select `approved_3d_release=v14`, rebuild the launcher,
include the intended desktop platforms and keep model cleanup disabled for this
rollout. The usual paired certification, synchronization and certified
promotion apply to the dedicated `release/v0.3.108` worktrees. The new desktop
manifest is activated only after immutable model publication. Browser/Android
continue their existing platform workflows; v14 is the desktop 3D collection.

Retained local artifacts are under the release frontend's
`.tmp/model-release-v14/`: source paths, versioned packs, binding and upgrade
reports/logs, failed attempts and publication checkpoints. No credentials,
Godot caches, installed userdata or generated model packs are committed or
copied into CI.
