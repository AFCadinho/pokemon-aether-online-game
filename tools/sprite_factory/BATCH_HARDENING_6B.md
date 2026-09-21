# 6B — batch hardening

## Completion pass

The engineering/retest pass is complete. Diagnosed failures now have generic
fixes or explicit source/visual dispositions. This does **not** mean all 30 models
are battle-approved. No catalog activation, admission relaxation, synthetic clips,
or source-file edits were made. The first-pass record below is historical.

### Legacy mapping disposition

The second pass examined older hash-named clips and drowse families, including
20 five-pose diagnostic reviews. Recurring 166-frame hashes show rest/calibration
to battle movement, not established sleep. Other sampled hashes show movement,
attacks or uncertain stationary poses. Their semantics remain unproven; no hash
alias or generic `loop01` mapping was added.

`kw20_drowseB01` maps to sleep only with matching A-entry and C-exit clips.
Butterfree, Raticate and Parasect have that complete family. Real-source Blender
bone-matrix checks show zero first/last-pose difference and nonzero midpoint
movement for all three loops. Rendered resting poses were reviewed. This is one
naming-family rule, not three species manifests.

Native coverage limits after retest:

- Butterfree, Raticate, Parasect: `faint_loop` missing.
- Beedrill, Pidgeot, Machamp, Onix, Alakazam: `sleep`, `faint_loop` missing.
- Abra: additionally no identified `physical_attack`.

All nine have faint-start. The existing final-faint-pose hold is a runtime fallback,
not a native loop. The six missing sleeps and Abra's attack require additional
motion evidence/assets; admission rules remain unchanged.

### Effect profiles implemented, visual limits retained

The completion adds `scvi_unlit_layered_displacement_v1` (one UV, fire) alongside
the recognized NonDirectional two-UV smoke profile. These use TRMTR provenance,
source mask/displacement PNGs, native intensity/height and auxiliary TRACM loops.
The exporter requires both affine UV tracks, constant positive scales and whole
repeat cycles. Multiple banks must agree; missing/ambiguous data stays blocked.
Color-domain texture baking feeds the reconstructed unlit alpha/displacement
shader. Shader/textures are embedded in SCN with GLB/texture hash validation;
effect shells are excluded from the opaque irradiance pass. No species branches.
Normal/shiny job generation carries the auxiliary motion directory.

Fixed-pose checks at 0, 0.5 and 2 seconds show motion: Gastly changes 37,999 pixels,
Charizard's back view 219 at 0.5 seconds. Both return to **zero pixel difference**
at their two-second boundary. Event timing/audio is unchanged.

This is reconstruction, **not proven original-game shader parity**. Gastly is no
longer an opaque export, but smoke faceting and mask/body overlap remain visible:
its final visual quality is **not approved**. Charizard's fire is visible and
animated but also needs final art review. Baked color-domain and inferred
mask/displacement semantics are explicit limits, not recovered official shader
code. Legacy Blend shaders remain uncertified. No full shiny batch was run.

### Bulbasaur disposition

The dedicated `tuta` meshes are visible in the source; the seven selected base
clips have no retracting scale/visibility tracks. A separate vine-attack family
exists but is not selected. No Bulbasaur auxiliary-motion directory was found
in the supplied SCVI motion dump, so official visibility semantics remain unknown.

The correction is therefore explicitly **authored**, not a generic importer
heuristic: `reviewed_source_repairs.json` binds removal of only those two meshes
to the exact Blend SHA-256 and seven-action allowlist. Both workers apply it in
memory. Changed sources do not inherit it; new actions fail for explicit review.
Future vine attacks need visibility handling. Source files remain intact. Final
idle/back/attack/sleep/faint images show the base set without protruding vines.

### Completion results and evidence

- Exact same 30: **30 GLB exports, 30 successful Godot pose/timing checks and
  30 standalone SCN reloads without external dependencies**; zero export holds.
- **21 seven-native-clip mappings**, nine partial as listed above. Three of those
  nine now have all six core clips and lack only a native faint-loop.
- **144 captures**, all six contact sheets visually inspected. Dragonite and
  Roaring Moon's ten images are pixel-identical to the original cohort.
- **44 focused Python tests**, three real-source Blender seam checks, Godot
  `batch_material_effect_check`, `batch_material_response_check` and
  `battle_material_response_check` pass. Effect tests include invalid payloads,
  standalone roundtrip and irradiance exclusion; both temporal-loop checks pass.
- All original source hashes unchanged. No installed assets replaced.

Artifacts in slot-b `.tmp/`: `catalog-30-6b-final/` (reviews/exports),
`catalog-30-6b-final-runtime/report.json`, and
`catalog-30-6b-final-results/index.html` (gallery plus observations JSON).
Legacy evidence: `6b-legacy-clip-review/` and
`6b-final-diagnostics/drowse-loops.json`; temporal results:
`6b-effect-temporal-check.json`. Older artifacts are retained.

Auto-fit views do not certify battle scale, facing or grounding. No full gate,
live-battle stress, performance certification or activation was performed. The
next decision is visual acceptance/correction and per-model battle admission:
**30 conversions are not 30 approved models**.

## Historical first correction pass

This pass diagnoses the fixed 30-model cohort, implements evidenced generic
corrections, and reruns source review, GLB export, Godot checks and SCN conversion.
It does **not** finish shader reconstruction, certify models for battles, or
activate assets. Unresolved cases remain explicit; no synthetic sleep/faint clips
or per-species material/geometry overrides were introduced.

## Mapping diagnosis

The original ten partial mappings split into two causes:

- Blastoise and Lapras contain numeric banks `0xxxx` and `1xxxx`. Their action
  suffixes overlap. `--animation-bank 0` now selects bank zero coherently for an
  entire review. No missing action is borrowed from another bank; the old
  ambiguity behavior remains the default when the option is omitted.
- Beedrill, Pidgeot, Raticate, Abra, Machamp, Onix, Alakazam and Parasect use
  older `ba/fi/kw` names. All eight lack clearly named sleep/faint-loop clips in
  these sources; Abra also lacks an identified physical attack. Hash-named clips
  and generic `loop01` are **not** evidence of a sleep or faint animation. They
  require semantic review or additional motion provenance, not another regex.

All seven mappings are now present for Blastoise and Lapras. Numeric banks are
review choices, not an assertion that bank zero is correct in every battle mode.

## Material profile, not species exception

The old `if name == 'gastly'` conversion hold is replaced by source-semantic
profile checks with TRMTR hash provenance. The profile
`scvi_nondirectional_layered_displacement_v1` recognizes a NonDirectional,
five-layer, two-UV displacement shader with base/layer-mask/displacement textures.
The supplied source tree contains this signature for Gastly's smoke **and a
Blastoise material**, each in normal/rare files. This is not evidence that all
ghost Pokémon share it. `AlphaType=Opaque` alone is insufficient to interpret it.

This profile is recognized but **not implemented in the runtime**. Required work:
layer-mask opacity, UV2 displacement, auxiliary UV motion and NonDirectional
lighting. The older experimental opacity/displacement probes do not prove shader
parity. Export is held rather than silently producing an opaque sphere.

The same check also exposes Charizard's Unlit, one-UV displacement fire as an
unreviewed source shader. It is held separately, not forced into the smoke
profile. Existing opaque graph validation still applies to the remaining models.
Legacy Blend shaders without TRMTR provenance remain explicitly uncertified;
Blastoise in this cohort uses that legacy route, not the SCVI effect material.
Fresh SCVI normal/shiny review jobs carry material provenance; old imported
jobs without it must be regenerated. Existing installed assets are untouched.

## Butterfree: variant isolation, not composite-rig support

The source contains two independent 59-bone rigs and different `pm0012_00` /
`pm0012_01` variant textures. Combining them would produce two Pokémon.
`source_review_rigs.py` selects a unique rig whose material image identities
exclusively match the source variant. It records both the evidence and excluded
rigs, then isolates that rig **in memory** for review/export.

Ambiguous identities, cross-rig ownership, indirect parenting, constraints and
object drivers remain blocked. Arbitrary composite rigs are not supported.
Blender `.001` action copies are collapsed only when their complete simple
curve data agrees; conflicting copies remain ambiguous. Tests cover both cases.
Butterfree now exports five clips. Sleep/faint-loop remain missing; material
appearance (including wing edges) is not battle-certified.

## Bulbasaur

The source itself contains visible left/right `tuta` meshes. The inspected idle,
attack and faint skeletal actions contain no scale channels hiding those meshes.
The thin protruding vines are already present before Godot export. The evidence
does not establish whether source authoring or missing visibility/motion metadata
is responsible. No mesh was hidden or bone changed to mask the issue. Determining
that cause and whether it is generic remains open.

## Same-cohort rerun

| Measurement | Before | After |
| --- | ---: | ---: |
| Cohort | 30 | 30 |
| Complete seven-action mappings, including held materials | 19 | 21 |
| Partial mappings | 10 | 9 |
| Source rig blocked | 1 | 0 |
| Successful GLB + standalone runtime conversions | 29 | 28 |
| Material-profile holds | 0 | 2 |
| Complete mappings among exported models | 19 | 19 |

The lower export count is intentional: Gastly and Charizard no longer count as
successful opaque approximations. Butterfree is newly exported but partial.
All 28 exported models pass the available-clip Godot pose/timing checks; all 28
SCNs reload without external resource dependencies. 131 square review captures
were generated. Dragonite/Roaring Moon's ten comparison images are pixel-identical
to the previous batch. Other captures are not claimed universally deterministic:
Beedrill's wing raster differs although its GLB is byte-identical; several other
captures differ by isolated pixels. This is retained as a rendering observation.

Focused evidence: 38 Python unit tests; Blender isolation/ambiguity/action-copy
fixtures; Godot pose/timing checks for 28 models; 28 runtime reload/hash checks.
The Godot batch exit is nonzero because its report retains two held/blocked rows,
not because the 28 exported models failed. No full development gate, shiny batch,
live-battle stress, performance certification or activation was performed.

Local artifacts are in slot-b `.tmp/catalog-30-hardening*`; original observation
artifacts remain unchanged. `catalog-30-hardening-results/index.html` is the new
gallery, with per-species JSON alongside it. Source hashes match the earlier
cohort. Baseline: `512450ac011b5a84bc559d15b3913d94178d6bc7`.

## Work left at the first-pass checkpoint (disposition above)

1. Identify unknown legacy motions without relabeling unrelated loops as faint.
2. Implement and visually validate the recognized effect profiles; recognition
   and fail-closed export are not a visual fix.
3. Trace Bulbasaur's source visibility semantics before choosing a correction.
4. Repeat the unchanged cohort after those corrections. Only then consider
   battle admission/scale/grounding and shiny testing.
