# Lossless model release binding

Task `lossless-model-release-binding`, slot-a, 2026-10-06. The complete smaller
collection is now bound to the actual game and launcher approvals as
`approved-pokemon-3d-v11`. This is local release preparation, not R2 publication
or player-manifest activation.

## Immutable artifacts and compatibility

- 1,200 bundles / 2,400 appearances; 1,198 new immutable bundle versions.
- Download: 19,863,374,075 → 12,857,317,549 bytes, saving 35.27%.
- Mega Dragonite and Toucannon reuse their original uncompressed RSRC bundles.
- Every prepared ZIP was rehashed. Every candidate scene was rehashed and
  decoded again against its original verified stream receipt. All 2,400 pass.
- `release/approved_3d_lossless_binding.json` binds each new digest to the
  original v10 digest, exact decoded digest, encoded size and original cache
  cost, plus the earlier preparation, rendering and native-platform evidence.
- Game and launcher admission are identical. The original reviewed profiles
  retain their original serialized bytes. All 2,400 old/new resolved profiles
  match, including placement, timing, correction libraries and cache cost.
- Original digests and earlier approved digests remain admitted for v10 and
  rollback. Historical v9/v10 packagers use that existing reviewed-history
  policy. Their immutable index, pin and metadata outputs remain byte-identical.
- The latest launcher accepts v10 and v11 independently by complete revision,
  ID set, index size/hash and object key. Mixed or corrupt tuples are rejected.

`package_approved_3d_release_v11.py` prepares from the retained verified inputs
or validates the committed bindings entirely offline. All affected release
artifacts, runtime approvals and both compiled pin files are checked.

## Actual runtime checks

`tests/approved_3d_release_v11_check.gd` uses the real checked-in pins and
approvals, with no generated approval replacement. It checks all 2,400 profiles,
both full catalogs, full planning and invalid revision/hash/ID tuples. Its core
metadata mode is included in the normal project gate; full asset checks are
optional through `LOSSLESS_PREPARATION_REPORT` and a fresh
`LOSSLESS_CHECK_OUTPUT`.

The 11-pair local asset run covers corrected poses, the large cache cases,
base/regional/Mega models and the unchanged Toucannon bundle. It installs the
originals, plans the complete update (only unchanged installed objects are
reused), installs 22 smaller scenes, hashes and deserializes all 22, reuses them
through on-demand without HTTP, restarts the adapter, and restores all 22
original hashes/generation without downloading. Selecting v11 rejects cached
old Gliscor bytes as a current v11 hit; selecting v10 still accepts them. Thus
retaining old approval does not prevent actual model updates.

Native Windows x64, Linux x64, macOS Intel and macOS ARM installer/file checks
remain the earlier recorded 11-pair qualification. This binding step validates
real complete pins locally; it is not a new four-platform GPU or full-collection
performance certification.

## Selection and displayed size

The launcher-supplied v11 index selects v11 in the game. Old launcher indexes
still select their exact old revision. Until immutable v11 publication is done,
an editor without an explicit v11 index continues to select published v10;
merging preparation code must not cause editor encounters to request unpublished
URLs. For a local v11 test, set `POKEAETHER_MODEL_INDEX` to the verified local
v11 index and use an installed verified v11 catalog. Once the matching verified
publication receipt is present, editor selection automatically prefers v11.
That switch passed an isolated synthetic-receipt check with no HTTP access;
the synthetic receipt exists only in the temporary test project.

The first-run chooser uses the selected revision's measured active-collection
size: approximately 13 GB for v11 and 20 GB for v10. The sprite collection pins
and measured 2D total are unchanged. Counts exclude game/arena files and
retained old generations; an update retains old objects for rollback and does
not immediately free all of the nominal saving.

The chooser tests pass for both selected versions. Their historical 19 GB
expectation was stale: the measured v10 total rounds to 20 GB. The test now
checks 20 GB for v10 and 13 GB for v11, while retaining the 470 MB sprite
expectation and the original choice/save/locale/platform tests. The legacy
full-project run has a two-resource shutdown diagnostic, reproduced with the
original chooser, service and size data restored temporarily. The v11 chooser
run and isolated binding/installation runs have no engine/script errors.
Earlier stale-size and reused-test-store failures are retained as failures.

## Remaining release procedure

The immutable bundles must be published before building/activating v11. The
explicit publication tool reads existing archives in place and verifies full
public GET SHA-256 and HEAD size for every bundle and the index. It does not
activate a player manifest. Run from the assigned release worktree after release
publication authorization, with credentials read in place:

```sh
python3 tools/publish_approved_3d_index_v11.py \
  --archives-report /ABSOLUTE/PATH/TO/RETAINED/prepared/report.json \
  --credentials /ABSOLUTE/PATH/TO/EXISTING/credentials --apply
```

Without `--apply` validation is offline. Without the archive input, `--apply`
requires the matching full immutable publication receipt. It rejects missing
publication before network access. The resulting
`release/approved_3d_bundles_v11_r2_receipt.json` must be included in the approved
release so GitHub can reverify already published bundles and publish/verify the
index. No archives, credentials, caches or userdata are copied into CI.

After the usual paired release certification/promotion and publication
approval, use the desktop workflow with `approved_3d_release=v11` and
`build_launcher=true` (and the intended macOS/version choices). It refuses v11
without the full matching immutable publication receipt and publicly available
objects, then packages the exact compiled v11 descriptor. Browser/Android
remain governed by their existing 2D release workflows.
