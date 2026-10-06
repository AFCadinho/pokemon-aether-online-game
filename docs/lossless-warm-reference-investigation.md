# Warm renderer reference investigation

Task `lossless-warm-reference-fix`, based on local development `7b98be2e4`.
This step changes diagnostics only. Model files, renderer quality, admission
hashes, release pins and production assets remain unchanged.

## Roaring Moon: overlapping original wing meshes

The unchanged 22-appearance original-only sequence reproduces its first failure
at Roaring Moon `damage:0.0`, ordinary materials. The two independently loaded
originals differ at **2,912 RGBA pixels**, with maximum channel deltas
`[33,39,39,0]`. Alpha is identical, and the repeated first actor is byte-exact.
The earlier “one pixel” description applies to Dragonite, not this failure.

Waiting 180 additional frames leaves the same two image hashes. Mesh, surface,
draw and specialization compilation counters remain unchanged. Disabling
shadows leaves 2,910 differing pixels; additionally disabling normal maps leaves
2,876. Those are isolation probes, not acceptable replacement image references.

The wing isolation probe supplies these exact mesh names explicitly:

- `pm1089_00_00_wing_a_mesh`
- `pm1089_00_00_wing_b_mesh`

With either wing mesh temporarily hidden in both actors, independently captured
images match **exactly**. Restoring both meshes restores all 2,912 differences
and the original two hashes. A CPU ray at `(223.5,220.5)` intersects surface 1 of
both meshes at exactly the same distance, `19.6232051849365`, in both actors.
The materials and geometry have distinct runtime RIDs. This demonstrates that
the coincident wing layers are necessary for this observed original-only image
variation. Neither wing is removed from the approved model or the strict test.

Godot's [Forward+ render-list implementation](https://github.com/godotengine/godot/blob/4.6/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.h)
sorts using shader, material and geometry IDs, among other fields. That makes
allocation-dependent ordering of coincident surfaces a plausible mechanism.
This investigation does not trace the GPU draw list or prove which sort key
changes; the controlled mesh isolation establishes the overlap, not that last
engine implementation detail.

## Dragonite remains separately open

The older one-pixel response mismatch at `(265,308)` and
`faint_start:0.999` is not reclassified as fixed. CPU rays at the four MSAA
sample positions show nearby surfaces in the original body; at one sample their
distances differ by approximately `0.00001621`. This is proximity evidence,
not a demonstrated explanation of that response-pass pixel. The paired cold
Dragonite and Roaring Moon source/candidate check still passes all 84 comparisons.

## Reproducible tools and acceptance

`native_paired_reference_check.gd` now saves original, candidate and repeat PNGs
on its first strict mismatch, plus changed-pixel count, alpha changes, channel
maxima and up to 16 coordinate/value samples. Successful comparisons still
require full RGBA equality, posed signatures/bounds and repeat equality.

`native_warm_reference_diagnostic.gd` adds isolation probes **only after** that
strict comparison has failed. Set `NATIVE_DIAGNOSTIC_MESHES` to a comma-separated
list of exact mesh names. It waits, records pipeline counters, hides/restores
each named mesh, then temporarily tests shadows and normal maps. It restores
material/light settings. Its report remains incomplete and the process exits
**2** even when a modified diagnostic image pair matches. There is no tolerance
increase or successful gate based on hidden geometry.

`native_surface_overlap_diagnostic.gd` independently loads the same original
twice, checks its required SHA-256, poses it, and records the nearest CPU ray
triangle intersections and runtime RIDs. Inputs are `NATIVE_OVERLAP_SOURCE`,
`NATIVE_OVERLAP_SOURCE_SHA256`, `NATIVE_OVERLAP_ACTION`,
`NATIVE_OVERLAP_FRACTION`, and JSON `NATIVE_OVERLAP_PIXELS`. Its output is a
**diagnostic** receipt, not a rasterization or runtime quality approval.

`native_resource_probe_project.py` links all three tools into a fresh task-local
probe project with its own cache. Run all Godot probes through `slot-env`.

Evidence is retained in `.tmp/lossless-warm-v1/`: unchanged reproduction,
`tracked-diagnostic/`, strict `positive/`, `tracked-overlap.json` and earlier
isolation runs. An initial ray invocation supplied an incorrect SHA; it exited
2 before loading the scene and is retained as `invalid-source-hash.*`.
The corrected invocation uses the fixture's recorded hash. Condensed receipts
are in `tools/sprite_factory/native_warm_reference_results.json`.

## Decision

This completes the overlap investigation for the Roaring Moon warm failure.
It does **not** clear the strict warm-renderer rollout hold, change an approved
model, or authorize publication. The existing 35.27% storage saving and exact
decoded model streams stand. Next work is a source-verified solution for the
coincident wing layers and the separate Dragonite response reference, followed
by the outstanding Windows/macOS and launcher collection qualification.
