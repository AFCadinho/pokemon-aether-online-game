# 6B — batch hardening, first correction pass

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

## Remaining 6B work

1. Identify unknown legacy motions without relabeling unrelated loops as faint.
2. Implement and visually validate the recognized effect profiles; recognition
   and fail-closed export are not a visual fix.
3. Trace Bulbasaur's source visibility semantics before choosing a correction.
4. Repeat the unchanged cohort after those corrections. Only then consider
   battle admission/scale/grounding and shiny testing.
