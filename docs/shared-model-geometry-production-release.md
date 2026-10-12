# Shared geometry production binding (v13)

The desktop production release selects `approved-pokemon-3d-v13`. Its immutable
index contains 1,200 model pairs: 1,145 verified shared PCKs and 55 retained ZIPs.
Normal and shiny keep separate scenes, materials and independent live poses while
sharing exact mesh, skin and animation resources inside eligible PCKs. The index
is pinned byte-for-byte in the game, launcher, package metadata and R2 receipt.

The payloads are the previously verified geometry staging collection with the
separately qualified Mega Hawlucha source repair. That one replacement PCK is
bound to the v12 repair publication proof. The new v13 index has a separate
production revision and `production_approved: true`; the old diagnostic index
remains a debug-only fixture. Existing v11/v12 pins and payloads remain present
for rollback and older clients. The v13 index was published and publicly
GET-hashed before the client manifest changed. The publication receipt is
`release/approved_3d_bundles_v13_r2_receipt.json`.

The active download collection is 8,688,776,408 bytes, versus 12,857,317,549
bytes for v11: 4,168,541,141 bytes (32.42%) less. The estimated installed size
is 8,688,757,818 bytes. R2 billed storage will not immediately fall by that
amount, because older immutable payloads remain available for rollback.

Desktop exports (Windows, Linux, macOS) select v13 without an environment flag.
The debug `POKEAETHER_SHARED_MODEL_PRODUCTION_TEST=1` flag exercises the exact
production path in editor tests; it has no effect in release exports. Android
and browser continue using their existing 2D workflows. Publication tooling
checks the pinned catalog against all 1,200 staged and repaired payload proofs,
rechecks public HEAD sizes, GET-hashes the new index and refuses a concurrent
manifest change. The desktop workflow requires a rebuilt launcher for v13.

The Linux release export launched a dedicated scene and confirmed the actual
release-mode v13 pin, exact index hash, all 1,200 pairs and 1,145 shared PCKs.
The production descriptor and installer checks used public, rehashed Abomasnow
and repaired Mega Hawlucha PCKs plus a retained Darumaka ZIP. A v11 Abomasnow
installation upgraded to v13 and returned to the original v11 ZIP successfully.
The paired release gate is recorded separately. Native Windows
and macOS runtime smoke tests and physical Android testing remain unavailable.
Rollback restores the previous game and launcher manifests as a matching pair;
the old v11/v12 index and objects are not deleted during this release.

The later, separately authorized [v11 R2 retirement](v11-model-r2-retirement.md)
archives the complete old collection outside R2 before removing the 1,145 v11
ZIPs that v13 does not reference. The 55 reused ZIPs and all v13 payloads remain
online. The original release checks above remain historical evidence; restoring
v11 after retirement requires re-uploading the archived objects first.
