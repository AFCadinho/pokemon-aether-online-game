# Model release v15

This release prepares the 111 smaller complete pair packs measured by
`release/new_pair_geometry_study_v14.json`. The collection retains all 1,420
pairs / 2,840 appearances. The other 1,309 bundles remain exactly unchanged,
including the 109 new-cohort pairs held for material-sensitive animation.

| Collection | Download bytes |
| --- | ---: |
| v14 | 8,993,498,070 |
| v15 | 8,795,326,138 |
| Additional saving | 198,171,932 |

These are selected collection/download totals. Publishing new immutable objects
temporarily increases R2 storage while the previous versions remain available
for rollback. They are not the billed bucket total.

## Frozen input and approval

`package_approved_3d_release_v15.py` rechecks the committed study's source/code
pins and retained report sizes/hashes, independently decodes its 240 PNG controls
and candidates, then reopens all 111 candidate PCKs. It preserves each source
identity, qualification source digest, cache budget, species/form and dependency
contract. Each changed archive has an incremented immutable version and a fresh
resource namespace, preventing old/candidate native resource cache collisions.
The reviewed model registry and every placement/animation profile stay unchanged.

The study already qualifies all 111 pairs for exact effective geometry/material
state, 5,274 stored clip samples, independent actors and 2,537 decoded native
members. Its GPU receipt accepts only exact complete candidate frames matching
either the first or repeated source; the two differing source-control frames
are retained and no pixel tolerance is introduced.

Game and launcher compile identical v15 descriptors, compact index and trusted
catalog. Exact v14 and v13 metadata remain accepted. Mutable diagnostic revision
selection uses separate catalog/lookup cache keys; a mixed revision/hash/size/key
tuple or forged compact reference still fails closed. Experimental Android also
selects v15; its arena and texture quality stay unchanged.

## Client qualification

Run the tools through the assigned slot environment (or release environment).
Retained model packs are read in place; no caches, installed user data or archives
are copied between worktrees.

```sh
python3 tools/package_approved_3d_release_v15.py \
  --study-root /absolute/retained/study/frontend \
  --previous-sources /absolute/retained/v14/sources.json \
  --output .tmp/model-release-v15
python3 tools/qualify_approved_3d_release_v15.py \
  --work .tmp/model-release-v15 \
  --previous-sources /absolute/retained/v14/sources.json
python3 tools/seal_approved_3d_release_v15.py --work .tmp/model-release-v15 \
  --launcher-log /absolute/retained/launcher-binding.log
```

Admission checks resolve all 2,840 appearances against compiled profiles and
validate both client pins and historical metadata. The standalone launcher
project additionally runs `launcher/tests/model_release_v15_binding_check.gd`.

Upgrade controls install 11 original v14 pairs, restart and load all 22
appearances, install v15, restart and load them again, then roll back to v14 and
repeat. They cover seven replacements plus unchanged Hydreigon, Tyranitar,
Landorus Therian and Rapid Strike Urshifu. A deliberately missing pack in a batch
must preserve the active generation, and every successful phase must plan zero
redownloads for the installed controls.

The actual threaded battle presenter, Pokédex preview and summary preview compare
all 111 changed pairs against their original v14 scenes, including normal/shiny
swaps and actor retirement: 222 battles and 888 preview loads. Placement, action
families, authored clip signatures, sampled poses, scale and preview camera must
match exactly. Candidate cache budgets remain enforced.

Qualification uses Linux Godot 4.6.2 and the real Compatibility renderer, with
Dummy audio to avoid the host PulseAudio issue. Empty instantiate-test viewports
use a synchronous forced draw followed by a process frame, without waiting for
an optional subsequent draw signal. Failed/stopped harness attempts are retained
and do not grant approval. There is no new native Windows/macOS or physical
Android GPU certification.

`approved_3d_v15_binding.json` starts unapproved. The sealer accepts only complete
admission, all six upgrade/restart/rollback phases and all 111 presenter records,
with error-free logs; it pins reports, fixtures and the release code before
allowing immutable publication.

## Publication and activation

`publish_approved_3d_index_v15.py` validates the qualified binding and compiled
parity locally without network access unless `--apply` is explicitly requested.
When publishing with `--sources`, only the 111 changed packs need fresh upload
and public GET hash verification. The other 1,309 packs reuse exact historical
v14 GET receipts after a fresh public HEAD size check. The new immutable index
also receives GET/SHA and HEAD verification. Active platform manifest snapshots
must stay unchanged throughout upload. Previous objects are retained.

Desktop CI selects `approved_3d_release=v15`, requires a rebuilt launcher and a
complete local publication receipt, rechecks all 1,420 public object sizes and
verifies the index before packaging. Experimental Android preflight uses the
same v15 index and all 1,420 model objects. The paired release freeze,
certification and authorized promotion/build/publication remain separate steps;
this preparation does not activate player manifests or clean up R2 objects.

## Completed local preparation

All 111 pairs passed actual presenter equality: 222 source/candidate battles and
888 preview loads. All six upgrade/restart/rollback phases passed with 11 pairs
and 22 appearances. The failed batch preserved its active generation and each
successful installation planned no repeat download. Compiled v15 admission
resolved all 2,840 appearances; v14 admission and the standalone launcher also
passed. Android revision selection, launcher update, chooser sizes, compact
references and geometry/cache contract checks passed. The last contract check
compares release/catalog semantics because game aliases and Android eligibility
intentionally differ from the desktop launcher; its old byte-equality assertion
was already invalid before v15.

The four v15 Python checks, three historical v14 checks and 14 Android
asset/release checks passed. Workflow YAML/Python syntax and whitespace checks
passed. The local publication validator succeeds without credentials or network
access. No R2 upload, manifest activation, GitHub build, main promotion or full
paired certification has been performed for v15.

Successful retained client artifacts are in the assigned slot-c frontend's
`.tmp/model-release-v15-qualified-v3/`; standalone launcher evidence is in
`.tmp/model-release-v15-qualified-v2/launcher-binding.log`. Initial prepared
source metadata is in `.tmp/model-release-v15/`. Earlier stopped draw-wait
attempts remain retained and do not contribute to the sealed approval.
