# Shared geometry collection

This implements the first cohort from `shared-model-geometry-research.md`.
Normal and shiny have separate small scenes and appearance materials, referencing
the same exact mesh, Skin and AnimationLibrary files. Live skeleton nodes and
animation players remain independent. Geometry, UVs, weights, images, animation
keys and timing are not simplified, quantized or converted to a lossy codec.

## Qualified local result

The completed Linux build selected all **1,031** candidates and retained the
other **169** baseline pairs. Total collection size changes from 9,838,055,989 to
8,689,577,272 bytes: **1,148,478,717 bytes (11.67%) additional savings** beyond the
texture-sharing baseline. These are actual complete pack sizes, not an estimate
from uncompressed duplicate resources.

All 1,031 pairs passed cold installation, exact effective-scene comparison,
shared-resource/independent-pose checks and **50,454 animation samples**. The
focused Mobile Vulkan run on Linux / Godot 4.6.2 / NVIDIA RTX 3070 Laptop passed
**344 pixel-exact candidate frames**, **32 battles** and **128 previews** across
16 representative pairs. All 2,062 new appearances passed compiled source and
profile binding checks, including eight corrected appearances and concurrent
cold catalog lookups. Existing schema-1 and texture-collection checks also pass.
After merging current development, the real presenter checks passed again for
all 16 pairs (32 battles and 128 previews); the geometry implementation,
installer and render comparator were unchanged.

The real launcher/game installation check passed 17 pairs (the GPU selection
plus Mega Dragonite's required base pair), decoding all 34 scenes. It exercised
interrupted staging/resume, rejection of partial publication, corruption repair
that requests only the damaged pack, restart and opt-in guards. Evidence is
retained under `installation-v3`; prior failed fixtures are retained separately.

The committed receipt is `release/shared_model_geometry_collection.json`.
Detailed build and GPU evidence remain in the assigned slot under
`.tmp/shared-geometry-collection/full-v2` and `gpu-v1`, pinned by SHA-256 in that
receipt. Build implementation commit: `52c38ec93b9fb40d634db90ff7ace68dd7bfd1aa`.

This is a debug opt-in collection. Its immutable R2 staging and cleanup of the
superseded test upload are recorded in `shared-model-geometry-r2-staging.md`.
No player release was changed.
Native Windows, macOS and physical Android tests were unavailable. The GPU run
covers the stated 16 pairs; the structural and sampled-motion checks cover every
selected pair. These results do not claim exhaustive visual coverage of every
animation time or certification on other platforms.

## Package contract and activation

The container remains `model-pair-pck-v1`; its inner manifest now has an explicitly
versioned **schema 2**. Schema 1 retains its texture-only dependency graph. Schema 2
allows `textures/<hash>.res`, `meshes/<hash>.res`, `skins/<hash>.res` and
`libraries/<hash>.res`. Only the two model scenes may reference these leaves;
leaves cannot import any other file. Every leaf must be referenced. Existing
physical pack hash, manifest equality, member checksum, path, decoded-size,
compression and file-count bounds still apply. Cache admission budgets include
all shared leaves and retain the qualified source-model floor.

The launcher and game use byte-identical pack validators and catalog helpers.
The new compiled catalog is selected only in a debug build with
`POKEAETHER_SHARED_MODEL_GEOMETRY_TEST=1`. Its compact index stays within the
existing 1 MiB download limit. Without this flag, existing pilot/qualified modes
and the player release continue to use their existing collections. Metadata from
an external catalog cannot supply an uncompiled model/source binding.

## Cohort selection and build

`build_shared_geometry_collection.py` starts from the pinned 1,200-pair research
receipt and the staged texture-sharing collection. The first cohort contains
1,031 pairs with exact hierarchy/resource bindings and no material/mesh/method
animation tracks. Resource-name exceptions and sensitive tracks are deferred.
Both existing PCK sources and retained v11 ZIP sources are supported. Pairs that
do not produce a smaller complete PCK retain their baseline asset.

All native payloads use Zstd level 9 and 262,144-byte blocks with a byte-exact
compression round trip. The recipe/source hash selects a fresh private resource
namespace. Effective material bindings move from mesh surfaces to each scene's
surface overrides. Unreachable old material textures are omitted; the saved
scenes' exact dependency closure determines the included payloads.

For every candidate, the builder checks:

- exact instantiated properties, normalized only for mesh/material placement;
- every animation, including RESET, at 0%, 50% and 99.9%, with exact authored node
  transforms, visibility, bone poses and blendshape values;
- actual installation and physical PCK inspection in a separate process;
- cold candidate-only loading and the same effective properties/motion;
- shared resource identities, separate skeletons, independent animation and pose
  state, and survival of one appearance after the other is retired.

Godot creates internal PhysicalBoneSimulator3D nodes with per-process generated
names. The motion comparison excludes only those unowned internal nodes; authored
nodes and their bones remain in the comparison. Temporary actor teardown holds
material references until node deletion finishes, matching the ownership
precaution already used by the presentation code. This also prevents the dummy
renderer from inspecting prematurely freed material RIDs.

Batches pin their implementation and input hashes and retain logs, checkpoints,
source derivations and packs under `.tmp`. Resume requires exactly matching
configuration and independently rehashes retained candidate packs. On failure or
interruption, queued jobs and owned child processes are canceled before restoring
the assigned project configuration. No existing cache, source archive or release
pack is rewritten.

## Validation tools

`shared_geometry_contract_check.gd` exercises JSON schema validation, schema-1
compatibility, allowed paths, forbidden cross-resource edges, cache budgets and
launcher parity. `shared_geometry_catalog_check.gd` checks every new appearance's
compiled source binding and reviewed/corrected profile, rejects forged bindings,
and verifies that opt-in is required. `shared_geometry_install_check.gd` exercises
the real launcher adapter and game catalog reader, including corruption repair,
restart and activation guards.

`qualify_shared_geometry_collection.py` uses the existing corrected Mobile Vulkan
renderer and real threaded battle/pokedex/summary presenters. Its default 16-pair
selection includes all four corrected rigs, old ZIP models, teardown regressions,
previously uncompressed sources, large multipart rigs and common normal/shiny
models. Source controls come from the original approved v11 ZIPs. Each GPU frame
has a repeated-source control; a pixel mismatch remains a failed comparison.
`--all` requests the complete generated selection rather than the focused cohort.

## Reproduction

From the workspace, with the slot assigned to this task and fresh output paths:

```sh
ops/worktrees/slot-env slot-b -- python3 \
  .worktrees/slot-b/frontend/tools/build_shared_geometry_collection.py \
  --audit .worktrees/slot-b/frontend/.tmp/shared-geometry/full-v2/report.json \
  --sources .worktrees/slot-b/frontend/.tmp/shared-model-readiness/full-v4/input.json \
  --output .worktrees/slot-b/frontend/.tmp/shared-geometry-collection/full-v2 --workers 2

ops/worktrees/slot-env slot-b -- python3 \
  .worktrees/slot-b/frontend/tools/qualify_shared_geometry_collection.py \
  --collection .worktrees/slot-b/frontend/.tmp/shared-geometry-collection/full-v2 \
  --sources .worktrees/slot-b/frontend/.tmp/shared-model-readiness/full-v4/input.json \
  --output .worktrees/slot-b/frontend/.tmp/shared-geometry-collection/gpu-v1
```

`finalize_shared_geometry_catalog.py --collection PATH` compiles the verified
build into `model_pair_geometry_catalog.json` and `model_pair_geometry.json` in
both game and launcher. It constructs fresh evidence headers, pins the build and
baseline index, and never carries old texture-only qualification claims forward.
An explicit `--hold ASSET_ID` retains that whole pair from the baseline. Qualification requires the checked-in data to match its candidate packs.
Run generation and GPU checks sequentially: the generator temporarily omits
autoloads under the diagnostic project lock, then restores the exact project file.
The GPU presenter check uses the real autoload configuration.
