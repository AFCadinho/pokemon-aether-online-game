# Normal/shiny geometry and animation sharing research

This is an offline follow-up to `shared-model-r2-rollout.md`. The staged
collection shares identical textures; it still stores meshes and animation
libraries inside separate normal and shiny scenes. This experiment measures the
remaining exact duplication and constructs a private example pack. It does not
change the accepted catalog, downloader, launcher, runtime loader, or R2.

## Results

The complete 1,200-pair comparison finished successfully. Evidence and exact input
hashes are in `release/shared_model_geometry_research.json`.

| Exact comparison | Matching pairs |
| --- | ---: |
| Geometry including stored mesh metadata | 1,159 / 1,200 |
| Geometry excluding only the `resource_name` label | 1,200 / 1,200 |
| Authored skeleton properties and skin bind data | 1,200 / 1,200 |
| Complete animation libraries at corresponding nodes | 1,168 / 1,200 |
| Entire non-material structure/resources under strict comparison | 1,127 / 1,200 |

All 41 strict mesh exceptions differ only in `resource_name`. No vertex, UV,
normal, weight, blendshape or other stored mesh-property difference remains after
excluding that label. This is an audit observation, not permission to discard
metadata silently. There are 149 pairs with material/mesh/method-sensitive
animation tracks; 1,031 pairs pass the strict full comparison without such tracks.
These are implementation candidates, not automatically runtime-qualified pairs.

The conservative standalone duplicate-component indicator is **1,313,859,851
bytes (1.314 decimal GB)**: meshes 141,436,884; skins 4,509,170; animation libraries
1,167,913,797. Animations account for most of the remaining opportunity.

The **118 retained v11 ZIP pairs also have an opportunity**: all 118 have the same
geometry after accounting for five mesh-name differences, all have matching
skeleton/bind data, and 116 have matching complete animation libraries. Their
standalone duplicate indicator is 66,203,823 bytes. The earlier texture-sharing
result does not rule out geometry/animation sharing for these pairs.

The final Abomasnow prototype is **11,897,936 bytes**, down from **12,867,864** in
the already texture-shared staging PCK: **969,928 bytes / 7.5376% extra saving**.
This includes a private prototype manifest; a production manifest can differ.
Both appearances passed cold candidate-only loading, exact effective-resource
comparison, dependency closure and independent pose checks. All 20 candidate
frames matched their source pixels exactly, and all 20 repeated-source frames
matched too (60 rendered images in total).

Recommended next implementation: first support shared geometry/skin/animation
resources for exact matches with straightforward tracks. Preserve variant-specific
materials and separate actor poses. Measure real packs for the full cohort, then
address the named exceptions and sensitive tracks separately. Existing staging
files remain usable while a new format is qualified.

## Method

`tools/audit_shared_geometry.py` checks the complete qualified index against the
committed staging receipt, verifies each retained input pack hash, and opens both
appearances in headless Godot. ArrayMesh keys cover all stored geometry data,
including vertex/UV/normal/weight/blendshape data, while excluding only the surface
material references. Other stored metadata and local-to-scene flags remain in the
comparison. Skin bind data, authored Skeleton3D properties, and AnimationLibrary
contents use exact semantic signatures. Node paths and resource bindings are
compared too: the primary comparison uses no approximate geometry or name
normalization. `shared_geometry_name_probe.gd` then checks all 41 mesh exceptions
again, excluding only the top-level resource name.

The size indicator saves one copy of each exact cross-variant duplicate component
as a native resource, using Zstd level 9 and 262,144-byte blocks. It excludes
local-to-scene resources and resources with external dependencies from that size
indicator. In particular, some animation libraries refer to appearance-specific
materials/textures. The indicator is **not an exact whole-collection saving or a
lower bound**: inline compression, dependencies, scene wrappers and pack metadata
change the eventual size. All pairs remain in the comparison regardless.

The first full diagnostic run exposed libraries with texture dependencies. The
final run records those dependencies instead of treating such libraries as
self-contained. Earlier failed/smoke runs are retained locally; the evidence
summary identifies the successful full run.

## Private prototype

`tools/run_shared_geometry_prototype.py` builds one diagnostic PCK from a checked
texture-sharing PCK. It retains compressed texture bytes, externalizes mesh data
without materials, and keeps each appearance's materials as MeshInstance3D surface
overrides. Exact Skin and AnimationLibrary resources share one file. It rejects
local-to-scene resources and animation tracks targeting materials/meshes or calling
methods. Normal and shiny keep separate small scene wrappers.

The producer compares the complete instantiated property tree, normalizing only
mesh/material placement into exact geometry plus effective material signatures.
After compression and packing, a new headless process mounts **only** the candidate,
checks every payload hash and dependency closure, and repeats that comparison.
It verifies shared mesh/skin/library object identities, distinct live Skeleton3D
nodes, and independent animation/pose state. Each actor needs its own live skeleton
and animation player; sharing a live mutable pose would be incorrect.

The optional GPU check uses the existing Mobile Vulkan texture probe: both
appearances, front/back, five poses (idle, physical attack, special attack, sleep,
faint), with a repeated source control. This establishes a focused Linux rendering
proof, not a complete battle/presenter or cross-platform qualification. Production
reviewed corrections and all clips are outside this render sample. Existing
reviewed visibility, flight, standing and breath corrections duplicate libraries
before changing them; the prototype does not modify those runtime paths.

## Reproduction

Run from the workspace through the assigned slot (use fresh output directories):

```sh
ops/worktrees/slot-env slot-b -- python3 \
  .worktrees/slot-b/frontend/tools/audit_shared_geometry.py \
  --sources .worktrees/slot-b/frontend/.tmp/shared-model-readiness/full-v4/input.json \
  --output .worktrees/slot-b/frontend/.tmp/shared-geometry/full-v2 --workers 2

ops/worktrees/slot-env slot-b -- python3 \
  .worktrees/slot-b/frontend/tools/run_shared_geometry_prototype.py \
  --input .worktrees/slot-b/frontend/.tmp/shared-geometry/smoke-v3/batch-0000/input.json \
  --output .worktrees/slot-b/frontend/.tmp/shared-geometry/prototype-v3 \
  --audit-report .worktrees/slot-b/frontend/.tmp/shared-geometry/full-v2/report.json --render
```

The runners acquire the diagnostic project lock and temporarily omit autoloads and
editor plugins in this assigned slot, restoring the exact project file in `finally`.
Do not run them together. The full audit pins source files and the source commit;
the prototype report pins its producer/audit/render scripts. Both retain logs and
reports under the slot's ignored `.tmp/shared-geometry` directory. Focused invariant
checks are in `tests/shared_geometry_audit_check.gd` (material-only equivalence,
UV changes, resource ownership, animation timing/library bindings, sensitive tracks
and skin bind poses).

## Follow-up boundary

Use a new pack-format/manifest contract for mesh, skin and animation dependencies.
The current production pair loader intentionally accepts the texture-only resource
graph; this research does not relax it. A rollout needs measured candidate packs,
per-appearance semantic checks, corrected presenter/battle checks, independent
actor tests, and the release process. Do not extrapolate the Abomasnow percentage
to every pair. Retain variant-specific resources wherever equality is not proven;
sharing only a subset of components is still useful.
