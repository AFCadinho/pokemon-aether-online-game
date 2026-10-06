# Source visibility and stable material order

Task `lossless-source-overlap-resolution`, slot-b, based on development
`18a018e49`. These are client rendering corrections, not a compression transform.
No downloaded SCN, texture, vertex, skin, skeletal key, compression setting,
release index or catalog admission hash is changed.

## Roaring Moon's intended wing variant

The actual SCVI TRACM files contain six fixed mesh visibility tracks for every
current battle action. Wing A is visible and wing B is hidden. Equivalent clips in source motion banks 0 and 2 agree on those states, FPS,
duration and looping. Sleep has no bank-2 counterpart and uses the verified
bank-0 clip matching the runtime clock. The directional
attack has complementary framed wing changes at source frames 0, 46 and 82;
that action is not in the current seven-clip runtime and is not added here.

`resources/battle/model_visibility/roaring_moon.json` records the exact source
file hashes, clocks and six bindings for the current actions. It admits only
the two current normal/shiny scene hashes and their explicitly recorded,
byte-identical decoded container revisions. It does not admit these future
containers to the catalog or apply to unknown/new model revisions.

`reviewed_source_visibility.gd` gives each supported actor a private animation
library and uses the existing validated Boolean-track baker. RESET and clip
entry establish a full visibility state. Unsupported scene hashes are untouched;
invalid mesh bindings restore the original library. Meshes, materials, textures,
skins and existing animation keys stay intact, including the inactive wing.
The baker now lives in runtime `source_visibility_pack.gd`; the old offline path
is a compatibility wrapper. Battle, Pokédex and inherited summary previews use
the same correction. No model redownload or R2 replacement is required for it.

## Dragonite and equal-depth material ordering

Visibility alone still reproduces Dragonite's one-pixel `faint_start:0.999`
original-only failure. Ordering only newly generated response materials resolves
the response failure in early rounds, but a later unchanged standard-material
Dragonite shiny capture still differs at that pixel. Both failed reports remain
retained, as does the visibility-only 22-appearance Grimmsnarl two-pixel failure.

The shipped `material_surface_order.gd` now assigns a stable scene/surface order
to opaque StandardMaterial3D surfaces with no authored priorities. Independent
actors get the same priorities regardless of recycled renderer resource IDs.
Instance-owned shallow material copies preserve textures/properties; leases on
the actor keep these private materials through response replacement and teardown.
PackedScene materials remain unchanged. Whole-mesh material overrides are handled
as whole-mesh overrides. Transparent materials and explicit source priorities
keep their authored priorities, and more than 256 surfaces fall back safely.

Both response passes copy these same priorities, preserving authored priorities
that the old generated materials omitted. Ordinary preview materials use the
same ordering. This deliberately fixes tie handling at nearly coincident surfaces;
it is **not** a claim that every original legacy reference PNG is unchanged.
Camera, MSAA4, lights, shader math, resolution, source geometry and texture data
remain unchanged. No depth bias, near-plane alteration, lossy tolerance or
unexplained hidden-surface workaround is used.

## Measured checks

With the actual client corrections enabled, the unchanged paired comparator
still requires full RGBA byte equality, equal posed signatures/bounds, repeated
A equality and scene weak-reference release. Raw source/candidate semantic
fingerprints and file hashes remain checked before runtime correction.

- Four appearances (Dragonite and Roaring Moon normal/shiny), repeated three
  times in one warm renderer: **504 exact comparisons** per phase.
- Original-only, source/candidate and candidate-first phases: **1,512 exact
  comparisons**, zero engine/script errors.
- The broader 22-appearance source/candidate warm sequence: **726 exact
  comparisons**, zero errors. Twelve unsupported response appearances are
  explicitly skipped symmetrically; their ordinary rendering remains checked.
- Four real Roaring Moon source/container appearances pass library isolation,
  idempotence, all existing keys, bone-pose equality, complete visibility,
  original-scene fingerprint preservation and unknown/hash/binding rejection.
- Material-order checks cover independent actors, instance-only mutation,
  preserved explicit priorities, root/empty meshes and the 256/257 boundary.
- Existing visibility switch/seek/RESET/reload checks, material admission,
  response viewport ownership/pooled cleanup and battle presentation checks pass.
  The presentation check reports existing sprite UID fallback warnings, not
  errors; it is not a new real-battle performance benchmark.

I inspected normal/shiny idle before/after and corrected attack, sleep and faint
captures: full wings remain present. The 28 before/after images are retained.
This is internal visual inspection, not a new user approval.

Receipts: `tools/sprite_factory/native_source_overlap_resolution_results.json`.
Full local evidence: `.tmp/lossless-source-v1/`, including earlier failed
experiments and final-control/candidate/reverse/cohort. Scripts and shaders are
linked in place into fresh probe projects; caches/userdata are not copied.

## Remaining qualification

The known warm-reference blockers are cleared for this measured client rendering
contract, including Grimmsnarl in the wider sequence. Earlier failed reports stay
failed and are not rewritten. This is not proof of pixel determinism across all
possible GPU drivers and scene histories, nor a complete 2,400-appearance visual
or performance scan. The previous decoded-stream/lifetime checks remain separate.
Windows/macOS loader/update/rollback and launcher collection integration still
remain before native compression rollout. Nothing is pushed or published here.
