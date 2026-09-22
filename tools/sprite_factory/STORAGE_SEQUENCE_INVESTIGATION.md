# Component-sharing sequence investigation — 2026-09-22

**Closed by user decision: promising but not production-safe.** Retain this
investigation, prototype code and results. Its remaining diagnostic proposals
are deferred, not current tasks. Catalog production resumes with standalone
models; sharing/deduplication/codec research stays closed until catalog size
becomes a practical problem. See [production direction](CATALOG_PRODUCTION_STATUS.md).

## Decision: still not qualified; diagnosis only

The existing `storage-components-04` artifact and all approved sources were
read in place and hash-checked. No component build, compression, catalog change,
new species, source edit, runtime integration, activation or deployment occurred.
Only the offline diagnostic harness and evidence are changed.

The observations separate **material lifetime** from **pixel determinism**.
Unchanged stored resources do not by themselves guarantee identical rendering.
Godot Resources are mutable objects: the prototype uses an ownership convention,
not a runtime-enforced immutable type.

## 1. Proven material-lifetime failure

Three repetitions of the same Articuno instantiate/free probe give:

| Instance/free policy | Renderer errors per repetition | Materials alive after node free |
|---|---:|---:|
| Original PackedScene instance | 0 | 4 |
| Prototype, private materials unpinned | 8 | 0 |
| Prototype, private materials held through destruction | 0 | 4 |
| Prototype, overrides detached before destruction | 0 | 0 |

The original scene owns its materials after the instance disappears. The
prototype's shallow material copies are owned only by the MeshInstance3D after
assembly returns. Releasing that last reference during node destruction can
leave renderer dependency teardown consulting a freed material RID. Holding the
copies through destruction, or detaching the overrides first, removes the error
without changing any shared component value. This is a lifetime bug, not a
texture or animation mutation. The early report's attribution to an *original*
Articuno free was incorrect; the same source line also handled the prototype's
unsupported-response branch.

Godot's destruction structure is consistent with that explanation:
[MeshInstance3D destructor](https://github.com/godotengine/godot/blob/4.6/scene/3d/mesh_instance_3d.cpp)
and [VisualInstance3D renderer-instance cleanup](https://github.com/godotengine/godot/blob/4.6/scene/3d/visual_instance_3d.cpp).
The measured intervention is stronger evidence than inferring an engine bug from
those sources alone. No production cleanup policy has been implemented here.

## 2. Dragonite: isolated pass is not a sequence guarantee

The isolated A/A/A′ control checks all seven clips at 0, 0.5 and 0.999: 21 poses,
both original/original and original/components pixel-exact. Longer sequences
reproduce the one-pixel difference at `faint_start:0.999`, (265,308), including an
original-only A/A sequence. A pinned-material run with deterministic material
priority assignments also reproduces it in the material-response pass.

For that reproduction, original/component comparisons additionally verify:

- complete posed mesh arrays, not just bounding boxes (including normals and
  the arrays returned by Godot's skeleton bake);
- active material properties and response shader uniforms (the dynamic light-map
  texture itself is tested through rendered pixels);
- animation selection/time/play state, bone poses, transforms, blendshapes,
  visibility, posed bounds and actual camera transform/projection;
- original PackedScene and component scene/appearance semantic fingerprints
  before and after playback, including stored animation and texture data.

These CPU-visible values match despite the pixel difference. The pixel is at a
head/antenna surface intersection. A CPU ray through MSAA sample (0.125,0.625)
finds body surface 1 triangle 2184 at distance 6.160164833 and surface 0 triangle
2512 at 6.160181522: only about 0.00001669 units apart. This supports a
depth/rasterization-order sensitivity hypothesis, **not yet a proof of the
precise GPU operation**. Disabling MSAA removed the Dragonite difference in an
ablation, but that changes the reference renderer and is not an acceptance fix.
The mismatch also occurs without shadows; shadows alone do not explain it.
With MSAA4 retained, changing only the diagnostic camera near plane from 0.05
to 0.5 also makes the stable-priority 42-comparison Dragonite run pass. This is
additional evidence for depth precision at the intersection, not permission to
alter the reference camera or claim golden parity.

## 3. Roaring Moon: overlapping wing geometry is a causal trigger

Shiny alone passes 42 comparisons (standard + response). Normal followed by
shiny can fail immediately at shiny `damage:0.0`. Original-only A/A sequences
also fail, in the response comparison. Disabling shadows, skipping response,
retaining all scene/appearance resources, duplicating the mesh per actor, and
keeping the viewport/camera/lights alive do not establish pixel parity.

The two wing meshes contain **516 byte-exact coincident posed triangles** at
damage time zero (184 in surface 0 and 332 in surface 1), after sorting each
triangle's three position vectors. Additional near-overlaps are not counted.
This compares positions only, not UVs, normals or material identity; it is an
overlap diagnostic, never a deduplication rule. Hiding `wing_b_mesh`
**in diagnostic instances only**, after each pose seek, changes the same
normal→shiny comparison from a failure into **84/84 exact** comparisons across
both modes. Source/component fingerprints remain unchanged throughout. This
implicates competing wing surfaces/draw ordering; it is not evidence of mutated
shiny textures. The hidden-mesh output is deliberately different from the golden
reference and therefore cannot qualify the artifact. No mesh was hidden in a
source, catalog, or game client.

## Reset, cleanup and scope of the evidence

The final unchanged-geometry warm-cache run repeats Dragonite normal, Dragonite
shiny, Roaring Moon normal, Roaring Moon shiny **three times**, in standard and
response modes. Private materials are leased through teardown; MSAA and lights
remain at the reference settings. Results:

- **504 paired pose comparisons: 333 exact, 171 nonexact.** All samples were
  collected, and the process correctly exited 2 (failed visual gate).
- **48 before/after resource snapshots: zero mutations.** All 24 capture pairs
  also match the traced posed arrays, material values and animation state.
- **48 loads: 24 cache hits, 24 misses**, with two-entry eviction across variants
  and species. All watched scene/appearance roots are gone after final clear
  and settling. This is not a measurement of every GPU allocation.
- **Zero renderer errors** with the diagnostic material leases.
- Mismatching comparisons: Dragonite normal standard 2; Dragonite shiny response
  1; Roaring Moon normal response 42; Roaring Moon shiny standard 63 and response
  63. The original/component data remains unchanged in these failing cases.

See [machine-readable evidence](storage_sequence_results.json) for run hashes,
flags, comparison groups, failures and captured engine errors. Full local traces
remain in `.tmp/sequence-*.json`; no success is inferred from a run merely
finishing or from a diagnostic ablation passing.

Every capture creates an independent actor. Pose sampling stops the player,
resets bone poses, seeks the chosen clip with immediate update, and forces bone
transforms. Rendering waits three process frames plus `frame_post_draw` per pose.
This protocol is unchanged from the initial control; the new tracing observes
it rather than changing animation data or reset semantics.

The optional material lease is held by the capture's local load record until
after node teardown and render settling. Original and component cache entries
now have separate keys, necessary to prevent an A/A′ warm-cache test from
silently returning the other representation. A two-entry cache exercises hits
within an appearance and eviction across species/variants. Weak references
observe resource release after the final explicit clear.

The diagnostic runner also now returns a failed comparison to its outer runner
before requesting process exit. Requesting exit inside the comparison while the
tracing subclass still awaited cleanup produced exit-time leaked-state warnings.
Cleanup is awaited first; this does not turn a pixel failure into a pass.

This is an offline renderer sequence, not a claim of real battle-client lifecycle
qualification, GPU-memory leak certification, or identical results on other
drivers. No lossy comparison threshold is used. Any nonidentical pixel remains a
failure, including in the optional collect-all diagnostic mode.

## Reproduction

Use `ops/worktrees/slot-env slot-b -- env ... godot --path
.worktrees/slot-b/frontend --rendering-method forward_plus --script
res://tools/sprite_factory/storage_sequence_trace.gd` from the workspace root.
Set `STORAGE_COMPONENT_OUTPUT` to the existing absolute
`slot-b/frontend/.tmp/storage-components-04` directory, `STORAGE_COMPONENT_REPORT`
to a separate report file, and `STORAGE_COMPONENT_MODE=visual` unless noted.
Renderer: Godot 4.6.2, Forward+, RTX 3070 Laptop, 512×512, MSAA4, fixed lights.

Useful independent-process controls:

- Isolated Dragonite A/A/A′: `STORAGE_COMPONENT_MODE=diagnostic`.
- Lifetime probe: `STORAGE_COMPONENT_MODE=lease_probe` (expected renderer errors
  are captured by Logger, not ignored).
- Unchanged mixed baseline: `TRACE_ONLY=dragonite,dragonite@shiny,roaring-moon,roaring-moon@shiny`.
- Resource/state tracing: `TRACE_HASH=1 TRACE_RUNTIME=1`.
- Original-only A/A: `TRACE_ORIGINAL_ONLY=1`.
- Material lifetime intervention: `TRACE_PIN_MATERIALS=1`.
- Repeated two-entry-cache test: `TRACE_REPEAT=3 TRACE_WARM_CACHE=1 TRACE_COLLECT=1`.
- Diagnostic wing control: `TRACE_ONLY=roaring-moon,roaring-moon@shiny
  TRACE_HIDE_NODE=pm1089_00_00_wing_b_mesh TRACE_PIN_MATERIALS=1`.
- Triangle inventory: `TRACE_GEOMETRY=1`; head pixel rays: `TRACE_RAYS=1`.

Other ablation flags are explicitly recorded in each report. They are not game
settings. Reports with hidden geometry, changed lighting/MSAA/material priorities,
or other diagnostic alterations must never be promoted to approval evidence.

## Remaining decision

The source/component data can be reused without an observed semantic mutation
in these tests, but **fully safe, pixel-exact reuse is not proven**. The existing
prototype fails the combined requirement. Before any format rollout, a separate
authorized correction would need an explicit material lease/destruction contract
and a justified deterministic treatment of the existing rasterization/overlap
cases, followed by the unchanged golden-render tests. Do not address this by
optimizing storage, relaxing comparisons, or silently changing approved models.
