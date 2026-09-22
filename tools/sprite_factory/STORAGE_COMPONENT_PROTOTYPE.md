# Lossless component storage prototype — 2026-09-22

## Decision: STOP, not qualified

The isolated prototype was built from six existing approved normal/shiny pairs.
It reduces actual package bytes by **38.19%**, but does **not** pass the visual
gate. Do not migrate, activate, distribute, or treat this as a production format.
No source SCN, approved catalog, renderer, launcher, player setting or approval
hash was changed. Only offline tools, tests and this evidence are integrated.

The initial broad comparison examined 51 images before stopping: 50 match in
every RGBA byte; Dragonite normal `faint_start:0.999` differs at **one pixel**
of 512×512, position (265, 308), maximum channel differences RGBA (16,10,4,0).
This is a failure, not a tolerance-based pass. The cleaned-up harness repeats
the same failure.

Node transforms, all bone poses, blendshape values, visibility and posed mesh
bounds match at these samples. Source-vs-restored stored semantics pass for all
12 models, including complete animation track/key/timing data and materials.
Thus no changed motion payload or geometry has been demonstrated.

An isolated Dragonite A/A/A' control is pixel-exact for all 21 poses, both
original-vs-original and original-vs-prototype. The discrepancy is dependent on
the longer render/resource sequence. That is not sufficient to dismiss it.

The broad sequence also reports Godot Forward+ `Parameter "material" is null`
RID/dependency errors when freeing an original Articuno instance during a
material-response eligibility check. Articuno's original does not have that
response profile. Moving the check before scene attachment and using deferred
cleanup does not eliminate the broad-sequence failure. A separate three-repeat
**original-only** instantiate/free test is clean.

**Root cause is not yet isolated.** Current evidence points toward a
sequence-dependent render/resource lifetime interaction rather than changed
asset values. It does not establish whether the fault is in Godot, the harness,
or shared-resource ownership. Do not claim a proven engine bug or safe prototype.
Per the requested stop condition, no broad performance/lifecycle qualification
or further format iteration was pursued after these diagnostic reproductions.

## Sample and provenance

Articuno, Dragonite, Lucario, Pikachu, Roaring Moon and Snorlax: the same six
older reviewed control pairs used in STORAGE_AUDIT.md, not six shiny variants
of the newer screened 75-model set. The input is slot-c's existing
`.tmp/response-launcher-test/installed/376cadff72bd7a08201db737bacb0d26c7cf08726cc1bd3c5ad811b5e3313238/catalog.json`.
Inputs are read in place, not copied between slots.

Each source hash is checked against both the manifest and the checked-in reviewed
registry before conversion, and rechecked after serialization. All twelve pass.
Excluded Arcanine is not used. Source hashes are retained in
`storage_components_results.json` and the local prototype manifest.

## Implemented layout

- One shared PackedScene per species: exact node hierarchy, skeleton/rest data,
  mesh geometry, bindings, and animation libraries.
- One appearance Resource for each normal/shiny variant, assigning effective
  surface materials/material overrides by stable node path.
- Content-addressed external Godot resources: meshes without materials, Skin,
  Animation, AnimationLibrary, materials and exact ImageTexture components.
- A prototype manifest records semantic hashes, actual file hashes, component
  dependencies, source identity and source hashes.

Image identity includes dimensions, format, all image bytes including mipmaps,
and stored texture properties. There is no similarity metric or resampling.
Resource identifiers/names and resource paths are excluded from content identity;
all other stored properties, including local-to-scene flags and metadata, are
included. NodePath/StringName identity is compared by typed string content.
Scene reuse additionally requires exact normalized node-property equality;
PackedScene's internal variant-table ordering alone is not a semantic identity.

Serialization roundtrips must reproduce the component semantic fingerprint.
Reassembled actors must reproduce the original normalized node properties,
geometry and effective material values. All six pairs share their complete
seven-animation library (42 pairwise matching clips), geometry, bindings and
skeleton hierarchy/rest poses. Exact textures and materials are shared where
their fingerprints match. Each instantiated actor gets its own top-level
material objects; texture/endpoints and geometry are treated as immutable.
This ownership policy is **not runtime-qualified yet**.

All storage is Godot's existing compressed resource format. No texture or mesh
quality setting, codec quality, animation key, frame rate, source model or
material-response value was edited. There is no new production loader hook.

## Measured bytes

MiB below means 1,048,576 bytes. Component rows exclude the small global
manifest; the package total includes it. No image-diff evidence is counted as
shipping content.

| Species | Old normal | Old shiny | New normal-only | New complete pair | Extra shiny |
|---|---:|---:|---:|---:|---:|
| Articuno | 7.750 | 7.476 | 7.682 | 9.915 | 2.233 |
| Dragonite | 11.725 | 11.696 | 11.535 | 18.147 | 6.612 |
| Lucario | 11.501 | 11.217 | 8.162 | 11.247 | 3.085 |
| Pikachu | 11.688 | 11.843 | 11.492 | 16.274 | 4.783 |
| Roaring Moon | 24.242 | 23.320 | 16.878 | 26.008 | 9.130 |
| Snorlax | 4.513 | 4.431 | 4.514 | 5.677 | 1.163 |

- Old twelve SCNs: **148,271,770 bytes / 141.403 MiB**.
- New referenced components + manifest: **91,646,193 bytes / 87.401 MiB**.
- Saving: **56,625,577 bytes / 54.002 MiB / 38.19%**.
- 206 unique component files; manifest: 141,842 bytes.
- Six normals only: **71.420 → 60.260 MiB**; new mean **10.043 MiB/species**.
- Both appearances: **14.544 MiB/species**, excluding manifest overhead.

Do not divide the pair figure by two and present 7.27 MiB/appearance as meeting
the audit's 7.28 MiB/**normal species** target. They have different denominators.
The audit target was an independently compressed payload proxy for 75 different
normal models. This six-pair native-resource prototype does **not demonstrate**
7.28 MiB/species. It also does not disprove that a different lossless container
could approach that target. No further codec/container experiment was performed.

For completeness, arithmetic extrapolations from this small, older sample
(not qualified release budgets; exclude manifest overhead):

| Species count | Normal-only GiB | Normal + shiny GiB |
|---|---:|---:|
| 151 | 1.48 | 2.14 |
| 500 | 4.90 | 7.10 |
| 1,000 | 9.81 | 14.20 |

## Validation coverage and missing measurements

Passed: 12 source admissions/hash checks; all source/restored actor semantics;
resource serialization semantics; exact-pixel Articuno normal/shiny standard
poses; the examined Dragonite poses except the one stated above; isolated
Dragonite 21-pose A/A/A' comparison; unit fixtures detecting changed pixel alpha,
mipmaps, animation timing/visibility keys, and skin bindings; basic top-level
material ownership; byte-accounting test including orphan-component rejection.

Not qualified: full six-pair rendered sweep, Roaring Moon golden renders,
two-pass material-response parity, long-lived material ownership, actual
normal↔shiny gameplay switching, cache eviction/unload/reload, multiple battle
cycles, load/switch latency, process RAM or GPU memory.

The runner contains an **unexecuted** three-cycle/two-entry-cache diagnostic for
later use. Its presence is not test evidence. No RAM/VRAM or performance numbers
are inferred from file size. Even after that harness passes, the real battle
presenter/cache integration would remain a separate gate.

## Reproduction

Run through `ops/worktrees/slot-env slot-b --` using the slot frontend as Godot
project. Build: `--headless --script res://tools/sprite_factory/storage_components_build.gd`,
with `STORAGE_COMPONENT_SOURCE` pointing to the input manifest and
`STORAGE_COMPONENT_OUTPUT` to a fresh absolute directory.

The completed local package is slot-b/frontend/`.tmp/storage-components-04`.
Attempts 01–03 are incomplete development outputs, not accepted evidence.
No output is registered with the game's catalog.

Check: `--rendering-method forward_plus --script res://tools/sprite_factory/storage_components_check.gd`,
with the same output directory, `STORAGE_COMPONENT_MODE=visual`, and a separate
absolute `STORAGE_COMPONENT_REPORT`. Modes `diagnostic` and `original_release`
reproduce the scoped controls. Renderer: Godot 4.6.2, NVIDIA RTX 3070 Laptop,
Forward+, 512×512, MSAA 4×, fixed neutral lights/camera, no asset tuning.

Local reports: `storage-components-04-visual.json`,
`storage-components-04-visual-cleanup.json`, `storage-components-04-diagnostic.json`,
and `storage-components-04-original-release.json` under slot-b/frontend/.tmp.
The two mismatch PNGs remain inside the isolated output folder.
Unit checks: `tests/storage_components_check.gd` and
`python3 -m unittest discover -s tools/sprite_factory -p test_storage_components_report.py`.
`storage_components_report.py OUTPUT_DIR REPORT_JSON` reproduces the byte table.

## Before a production-format proposal

First isolate the sequence-dependent RID/pixel failure with a smaller resource
ownership fixture. Keep the golden comparison strict. Only after that passes
should the deferred complete visual/response sweep and independent old/new
lifecycle/performance processes run. Those timings need explicit distinction
between engine-resource-cold and filesystem-cold loads.

Later work would include immutable-resource ownership rules, thread-safe
appearance assembly, lifetime-aware cache accounting across shared dependencies,
portable relative references, integrity checks on transitive resources, format
versioning, reviewed identity admission for the assembled result, and integration
with the actual battle presenter. None is approved or automatically activated
by this experiment. Distribution/launcher work is outside this prototype.
