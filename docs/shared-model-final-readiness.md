# Shared-model collection: compact metadata and installation readiness

This follows the [exact renderer qualification](shared-model-catalog-qualification.md).
The selection stays at **1,082 shared pairs and 118 original v11 pairs**. Normal
and shiny Greninja (base form) and Inkay retain their original complete bundles;
Mega Greninja is a separate qualified asset. No scene, texture, animation,
compression setting, pixel acceptance rule or cache admission limit changes.

This is local qualification, not a published release. The collection is enabled
only in a debug build with `POKEAETHER_SHARED_MODEL_QUALIFIED_TEST=1`. It takes
precedence over the separate historical pilot and full candidate diagnostic
flags. Release builds and default builds cannot enable these bindings.

## Compact representation

`data/model_pair_qualified.json` and its launcher mirror pin the committed
qualification receipt and exact whole-pair selection. A shared row contains
only `format: model-pair-ref-v1`, `asset_id`, and the physical pack SHA-256.
The 118 legacy rows remain byte-equivalent as JSON data to their v11 entries.
The wire index is **236,908 bytes**, down from the 6,946,595-byte expanded draft,
within the unchanged 1 MiB index/descriptor limit.

References expand only against the currently compiled, explicitly enabled
catalog. Unknown hashes, unknown IDs, added reference fields, held candidate
pairs, and disabled flags fail closed. Expansion supplies the exact existing
metadata; normal index validation and physical pack/hash/member/dependency
checks still run. The qualified set cannot be enlarged by a downloaded index.

Installed state and runtime catalogs replace repeated `pair_asset` dictionaries
with `pair_ref: {asset_id, sha256}` and serialize without indentation. Readers
expand those references before the existing identity/path/hash checks. Supplying
both representations is rejected. Existing expanded catalogs and v11 files
remain readable. Battle, Pokédex/summary, on-demand download/cleanup, launcher
handoff and complete-download planning all understand the compact representation.
Both writers check the existing 8 MiB bound before publication. Runtime catalog
validation still requires an array, including for an empty installed state.

The actual complete-state check measures about 1.50 MB per metadata file;
installed runtime size depends on the absolute installation path. This
is metadata/disk deduplication; parsed dictionary memory is measured separately.
Both physical installations contain **9,844,999,677 bytes of model objects**,
saving **3,011,912,272 bytes (23.43%)** against the recorded original collection.

Repair now compares the active/previous publication pointers captured when a
collection starts. Restoring a corrupt pack can make the existing generation
valid again without publishing anything; this must not be mistaken for another
installation. A genuinely changed pointer still rejects a stale transaction,
including a second check after member verification. The focused repair check
covers both an empty fallback and a valid previous v11 generation.

## Focused checks

- `shared_model_qualified_metadata_check.py` reconciles all 1,200 rows against
  the prior committed evidence and exact v11 originals, including negative
  cases for admitting a held pair, changing a hash/fallback, or duplicating a row.
- `shared_model_compact_catalog_check.gd` tests all 2,400 appearance round trips,
  game/launcher parity, actual pinned descriptor/cache acceptance, on-demand
  index decoding, metadata bounds, ambiguous/forged references, disabled flags,
  and malformed catalogs for empty installed states.
- `shared_model_collection_install_check.gd` exercises the actual release
  adapter with every physical asset: fresh install, interrupted collection
  resume, complete v11 upgrade, atomic publication, launcher/game handoff,
  restart with no downloads, one-pair corrupt-pack repair and verified pruning.
- `shared_model_mount_budget_check.gd` now uses the selected catalog. It mounts
  all 1,082 qualified pairs and 23,485 declared PCK members in one process,
  then performs 5,410 repeat mount requests. All three registries remain at
  1,082 entries; serialized registries remain 519,367 bytes, resource count
  remains 388, and repeat-sweep static allocation grows by 852 bytes.
- `shared_model_collection_stress_check.gd` uses the actual installed compact
  catalog in one Mobile Vulkan process. Its required workload visits all 1,082
  pairs, then revisits 128 demanding/corrected rigs twice: 1,338 battles, 5,352
  previews and three canceled selections. It requires actual qualified hashes,
  expired texture references after cache clearing, stable registries, nodes and
  resources, at most 16 MiB additional static allocations, and at most 1 MiB
  additional GPU texture/buffer ownership between the two repeated sweeps.
- Existing generic launcher-store, on-demand handoff, 16-pair launcher pilot,
  full candidate binding and historical renderer-evidence checks remain relevant
  regressions. The Linux external SIGKILL runner exercises 20 interruption
  points with 63 worker invocations.

## Completed Linux installation checks

The physical fresh and v11-upgrade checks passed with Godot 4.6.2 on Linux.
Both converge to the same installed-state generation,
`829cae552dfe4f4ded07bc10014360187a78513e5103013f1714015f14cb00e1`.
Each keeps exactly 1,200 objects and exposes all 2,400 appearances. Both resume
an interrupted collection, reject incomplete publication, restart without any
downloads, and repair exactly the deliberately corrupted Abomasnow pair.

| Installation | Bundles downloaded | State bytes | Runtime catalog bytes | Old objects removed |
| --- | ---: | ---: | ---: | ---: |
| Fresh | 1,200 | 1,499,017 | 1,460,482 | 0 |
| Complete v11 upgrade | 1,082 | 1,499,017 | 1,465,282 | 1,082 |

The different runtime catalog sizes reflect the different absolute fixture
paths. Upgrade cleanup also removes the obsolete generation. The separate
consumer check passed: an empty launcher store reuses all 1,200 game bundles,
and the on-demand service verifies all 2,400 appearances without a request.

## Completed Linux session and collected evidence

The [readiness record](../data/shared_model_readiness_checks.json) combines the
successful installation, consumer, mount, session and interruption receipts.
Its collector independently hashes 1,318 payloads in each physical installation
(1,082 PCKs and 236 retained original scenes), checks all metadata and object
identities, and validates source commits and completed logs. It retains the
unsuccessful first session's hashes and errors separately.

The successful session used Godot 4.6.2, Mobile Vulkan and the NVIDIA RTX 3070
Laptop GPU for **86 minutes 47 seconds**: all 1,082 qualified pairs, followed by
two identical 128-pair demanding/corrected cohorts. It completed **1,338 battles,
5,352 previews, three canceled selections and 42,548 expired-texture checks**,
with no captured engine/script errors. All 1,082 pack, namespace and closure
registries remain present; their serialized size stays 545,335 bytes during
revisits. Registry sizes include absolute fixture paths.

| Metric after clearing actors/previews/cache | First repeated cohort | Second repeated cohort | Change |
| --- | ---: | ---: | ---: |
| Godot static allocation, bytes | 712,839,652 | 717,669,136 | +4,829,484 |
| GPU texture ownership, bytes | 167,752,704 | 167,752,704 | 0 |
| GPU buffer ownership, bytes | 11,010,460 | 11,010,460 | 0 |
| Resources | 794 | 794 | 0 |
| Nodes / orphan nodes | 400 / 0 | 400 / 0 | 0 |

The static-allocation increase is **4.61 MiB**, within the predetermined
16 MiB comparison limit. The heap counter still rises and its cause has not
been isolated. The earlier 16-pair pilot also recorded static growth
(3,619,444 bytes over its 80 post-warm-up battles). This result establishes the
measured growth budget and stable GPU/resource ownership; phone RAM usage and
a completely flat heap remain outside this evidence. RSS is recorded separately
in the receipt.

Production inputs remained unchanged across phases. The receipt pins the
installation implementation at `9d63bc7bbeb58b9fe468f4f2b79e310a82602584`,
consumer diagnostics at `a61a831a11c116b30c19e24f0ec15a4ee2098eea`, and corrected
session diagnostics at `bd07f858d1737c13b80d8bee3b7b2fbee41d1af4`.
It also pins the collection tools, raw artifacts and phase input hashes.

## Reproduction

Use an assigned slot and `ops/worktrees/slot-env SLOT --` for every Godot run.
Read retained approved ZIPs/PCKs in place; create fresh task-owned outputs.
Never copy caches, userdata, configuration or another installation.

```sh
python3 tools/prepare_shared_model_readiness.py \
  --source-report /absolute/approved-v11/prepared/report.json \
  --packs /absolute/shared-model-catalog/full-v2/packs \
  --output /absolute/assigned/frontend/.tmp/FRESH-READINESS

python3 tools/run_shared_model_readiness_phase.py \
  --run /absolute/assigned/frontend/.tmp/FRESH-READINESS --phase installation
python3 tools/run_shared_model_readiness_phase.py \
  --run /absolute/assigned/frontend/.tmp/FRESH-READINESS --phase consumers
python3 tools/run_shared_model_readiness_phase.py \
  --run /absolute/assigned/frontend/.tmp/FRESH-READINESS --phase session
```

The preparer validates the selection against the committed receipt and source
metadata; the real installer independently hashes all physical inputs. Fresh
and upgrade stores are separate. Interrupted attempts, including externally
terminated runs, remain retained and do not constitute completed evidence.
Commit the intended implementation and diagnostics before starting a phase.
The phase runner verifies its input hashes against that commit, retains logs
and execution receipts, uses fresh per-phase runtime directories, and rejects
changed inputs or incomplete results. It does not overwrite prior phase output.
Run this wrapper through `slot-env` too; the session phase requires the real GPU.
For a corrected session diagnostic, use `--phase session --attempt session-v2`
and supply its JSON to the collector with `--session`. This retains the failed
attempt, its runtime directories, logs, inputs and receipt unchanged.

After all three phases, the full mount check and external interruption suite
have passed, `collect_shared_model_readiness.py --run RUN --mounts MOUNT_JSON
--crashes CRASH_DIRECTORY` checks their receipts and source commits, then
independently hashes both installed collections. It refuses to overwrite the
checked-in readiness record. Different diagnostic revisions may be recorded
per phase; the production inputs must remain identical throughout the run.
Earlier session receipts and their log/input hashes remain in the collected
record. The first complete-catalog attempt stopped after 200 battles because
the diagnostic incorrectly required anticipated Darmanitan Zen forms to use
shared packs too. Those forms deliberately retain their v11 originals. The
corrected diagnostic requires the requested pair to be shared and verifies the
exact compiled hash of every loaded appearance, including original anticipated
forms and canonical aliases. Both Darmanitan cases passed a focused GPU check;
the interrupted full attempt does not count as a passed session.

## Platform and release boundary

The available host is Linux, Godot 4.6.2, Mobile Vulkan, NVIDIA RTX 3070 Laptop
GPU. Native Windows/macOS installation, update, repair, cleanup and process
lease behavior require those systems. Physical Android runtime, GPU/driver
compatibility and phone memory require a connected device. The user confirmed
that only this Linux machine was available; no native Windows/macOS host or
physical Android device could be tested. Linux checks, platform-branch unit tests,
Wine and emulation cannot stand in for those native-device results.

The local Linux workloads above have successful receipts. The record explicitly
sets `production_approved: false` and lists Windows, macOS and a physical Android
device as pending. Mount-index counts, actor/resource ownership, Godot static
allocation and RSS are distinct measurements. FPS and power-loss durability were
not certified. Full paired release certification, promotion, publication and
player activation retain their separate explicit authorization requirements.
