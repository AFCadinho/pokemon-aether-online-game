# Lossless renderer lifetime and reference validation

Task `lossless-material-reference-fix`, slot-a, based on development
`004ae6d01`. No model bytes, admission hashes, release pins or production assets
are changed. Earlier failures remain retained; this document corrects their
interpretation using new controlled probes.

## Archen was a fixture teardown failure

The prior full catalog fixture instantiated a scene and immediately called
`free()` on the detached actor. The new diagnostic labels creation and teardown
separately. The original Archen actor instantiates successfully; null-material
errors arise at immediate teardown. A standard scene-tree lifecycle (attach,
process/render frame, `queue_free`, process cleanup frames, release PackedScene)
passes for all four original/candidate normal/shiny Archen files, without
changing any material or suppressing errors.

The full 2,400-candidate scan now hashes every file, checks zero external
resources, loads independently using `CACHE_MODE_IGNORE_DEEP`, instantiates,
attaches it to the scene tree, waits for rendering-server frames, queues teardown
and proves its PackedScene weak reference is released. Every scene passes with
zero engine/script errors. This is a load/lifetime test, not a visual inspection
of every Pokémon: the root has no comparison camera. Actual image rendering is
covered by the separate 512×512 comparator below.

The complete-install fixture uses that same lifecycle helper. Its old failed
reports are not rewritten or retrospectively marked passed. The latest full
runtime scan uses retained immutable candidate objects, independently checked
against their recorded hashes, even though nine active control pairs were
rolled back in the previous task.

Godot's [material implementation](https://github.com/godotengine/godot/blob/4.6/scene/resources/material.cpp)
contains deferred initialization and RID ownership. The diagnostic demonstrates
the premature-teardown condition; it does not claim a source material is faulty
or that waiting two frames is an engine-wide fix for arbitrary renderer bugs.

## Strict paired image reference

Reusing only the world, camera and lighting does not fix the earlier Dragonite
A/A mismatch. That fresh-actor control reproduces the exact one-pixel difference
at `(265,308)` and response pose `faint_start:0.999`. Both untouched originals
remain byte-identical. The old failed control stays failed.

The new comparator keeps two independently loaded PackedScenes and actors
alive together for a pair, showing only one at a time. It compares A/B/A at
every animation except RESET and fractions 0, 0.5, 0.999. Stored semantic
fingerprints, posed transforms/bounds, complete RGBA bytes and the repeated A
capture must match exactly. Actors are neither repacked nor shared; both source
and candidate files are hashed and both scene references must be released after
cleanup. Both ordinary materials and supported two-pass response are checked.
Unsupported response is rejected symmetrically and explicitly reported as a
skip, matching the existing comparator's admission.

Camera placement/FOV/far plane, 512×512 dimensions, MSAA4, neutral lights,
shaders, textures, geometry and material priorities are unchanged. There is no
pixel threshold, cropped comparison, replacement reference image or hidden
surface workaround. Hiding the inactive independent actor prevents drawing both
models on top of one another; their internal mesh visibility is not altered.

The two known problem models, Dragonite and Roaring Moon, pass this paired
comparison, including original-only control and reversed candidate load order.
However a 22-appearance original-only *warm sequence* still fails at Roaring
Moon `damage:0.0`. The earlier allocations are relevant even with stable actor
lifetimes for the current pair. Geometry/material/skeleton allocation and opaque
surface ordering remain candidates; no specific GPU sort-key cause is proven.

A separate runner starts a fresh renderer for each appearance and for each of
original-only, candidate and candidate-first phases. This gives the byte-exact
comparison a bounded, reproducible starting state. It does **not** establish
repeatability across arbitrary warm multi-model battle histories. The warm
reference issue remains a rollout hold rather than being silently replaced by
the narrower cold gate.

## Retained evidence and next work

Outputs are under `.tmp/lossless-material-v1/`, including failed probes,
`archen-four/`, `full-lifetime/`, `reference-aa/`, `paired-22-aa-v2/` and
`isolated-22/`. Model inputs and immutable installations are read in place;
projects own their caches and link only source. No caches/userdata are copied.
Condensed receipts: `tools/sprite_factory/native_material_reference_results.json`.

Next work remains the warm reference allocation/overlap investigation,
Windows/macOS load/update/rollback qualification and streaming launcher
collection integration. These are not covered by the cold Linux image test.
Publishing is still a separate authorized step. The measured 35% storage saving
and exact decoded streams remain unchanged.

## Measured result

All 2,400 scenes pass the complete lifetime scan. The cold image test completes
for 22 appearances × three load/control phases, with 2178 exact A/B/A pose/pass
comparisons. Unsupported response skips are explicit in each phase receipt.
This clears the fixture-lifetime blocker and qualifies the bounded cold image
reference. The original-only warm-sequence failure remains open; global runtime
qualification and production approval are still false.
