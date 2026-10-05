# Regional model production batch

## Scope and status

This batch covers the 58 missing entries from `tools/sprite_factory/regional_model_coverage_audit.json`:
54 ordinary regional forms, Galarian Darmanitan Zen, two Alolan Totems and
Pikachu with the Alola cap. It produces 116 normal/shiny candidates. The three
previously accepted Galarian birds are outside this batch.

Candidates are **not runtime approved**. Registry admission, bundle generation,
performance qualification and R2 publication remain separate steps after the
combined visual review. No release index or runtime registry is changed here.

## Reproducible inputs and tooling

- `tools/sprite_factory/regional_model_batch_inputs.json`: the 58-entry source
  scan, 20 legacy intake rows, own-rig action mappings and ZA archive members.
- `regional_model_source_intake.json`: native input files and hashes, including
  shared Pikachu textures. Source paths refer to the mounted external disk.
- `regional_model_production.py`: source intake, native export and material pass.
- `regional_legacy_candidates.py` / `regional_legacy_variants.py`: the legacy
  source route, own-rig animation export and normal/shiny material candidates.
- `regional_visual_repairs.py`: explicit material and source-atlas eye repairs.
- `regional_weezing_smoke.py`: compact chimney plumes for Galarian Weezing.
- `regional_battle_prepare.py`: geometry-bound native measurements and proposed
  size, grounding and hover profiles.
- `regional_finish_review.py` / `regional_review_page.py`: checked evidence
  aggregation and a single lazy-loading normal/shiny appearance/battle gallery.

Generated source exports, receipts, scenes, rendered images and measurement
reports live in `.tmp/regional-production-v1/` in the assigned worktree. They
must remain available until acceptance and bundle admission. They are not
copied into an integration checkout or committed as runtime assets.

## Review limitations and explicit proposals

- Native routes: 31 SCVI regional entries, six entries from five ZA resources,
  and the Alola-cap Pikachu; 20 entries use the legacy dump.
- Eleven legacy shiny candidates use matched normal/shiny sprite references.
  Palette registration and geometry/alpha parity are checked, but this still
  requires visual colour approval. Other pairs use native variant materials.
- Alola-cap Pikachu has identical parsed normal/rare source material tables.
  Identical colours are recorded explicitly instead of inventing a variant.
- Alolan Vulpix has no suitable battle attacks in its source archive. Its
  attack candidates use its own source gestures, with explicit action timing.
- Galarian Darmanitan Zen uses a source rest proposal because its source has no
  sleep clip. Corsola keeps its native open-eyed rest expression.
- Closed-eye atlas frames were explicitly inspected for nine legacy pairs;
  arbitrary dark texture cells are not treated as closed eyes.
- Galarian Weezing had excessively stretched animated smoke tubes. The two
  smoke meshes are compressed, given source-noise surface variation and bound
  to their own chimney joints. Body meshes, rig and animation clips are
  unchanged. This effect adjustment requires the same final visual review.
- Totem sizes are proposed relative to the corresponding base forms, bounded
  by battle framing. Geodude, Raichu and Weezing have explicit hover proposals.

## Verification

- 48 focused existing Python checks passed (18 export/visibility/eye/parity,
  30 materials/variants/effects). Existing thresholds were not relaxed.
- All 116 standalone runtime candidates converted successfully.
- All 116 final appearance entries have no load or animation-switch errors.
- Full source-clock 60 Hz geometry measurements cover every candidate. Where
  only materials changed, reuse requires identical geometry, skin and motion
  signatures; the modified Weezing geometry was measured again.
- Independent 120 Hz measurements check actual packed runtime scenes, plus
  captured poses in both cameras and on both sides. Corrections must pass the
  existing qualification gate before the combined page is presented.
- The battle harness uses HUD proxies. Full game UI, arena collision and
  performance qualification are not implied by these geometry checks.

## Current review checkpoint

All 116 variants pass the unchanged independent 120 Hz battle qualification.
The initial report held 18 variants on floor-clearance samples; explicit local
vertical-envelope refinements were remeasured in fresh packed scenes. All
failed reports and refinement provenance are retained. Camera/HUD checks pass.
`regional_model_candidate_review.json` pins the current candidate and report
hashes; `regional_clearance_refine.py` records the correction process.

The combined review is `.tmp/regional-production-v1/review-v1/index.html`.
The normal checkout and runtime registries remain unchanged. Keep slot-a and
its generated artifacts for the final review, performance check and admission.
User visual approval is still required before building approved bundles.

## Eye review follow-up

The user accepted the bodies generally, but reported blank/missing eye details,
especially Zorua, Slowpoke and Arcanine. Visual contact sheets cover all 58
normal/shiny pairs. An audit of the native UV domain across source eye clips
found 21 pairs whose repeat samplers had been replaced by clamp during eye
animation packing. The base eye now retains native repeat; separate lid passes
still clamp. This restores idle eyes and details lost during other expressions.

Arcanine additionally receives source-mask metallic/roughness layers on its
two eye materials, and opaque rendering of its fully opaque eye texture. No
body materials, vertices, bones or skeletal animation data changed.
`regional_eye_followup.py` records source sampler evidence and exact geometry
parity. All 44 revised runtime scenes load and switch poses without errors;
matched runtime pose bounds differ by less than 0.00001 m.

Current 116-entry runtime report: `.tmp/regional-production-v1/runtime-final-v3.json`.
Current placement: `eyes-followup-v2/placement.json` in that artifact root.
The prior geometric battle qualification is retained with explicit parity
provenance; no new performance or full game certification is claimed.
Current combined eye comparison: `eyes-review-v1/index.html` (22 revised pairs
by default, all 58 selectable). Visual acceptance remains pending.

## Pikachu and Typhlosion follow-up

The user subsequently reported Alola-cap Pikachu and Hisuian Typhlosion.
Pikachu's native Eye shader requests a white fifth highlight layer; no explicit
highlight bitmap exists in that source. The review candidate uses a small
static specular lobe baked from its authored convex eye normal map. This is
an explicitly proposed portable approximation, not an exact native shader
translation. The dark/brown eye colours and closed-eye expressions remain.

Typhlosion's imported idle UV offsets moved the iris behind the narrow eyelids.
Neutral and negated-offset diagnostic renders are retained in `eye-last-two-v1`.
The proposed correction uses the material's neutral default gaze in idle only;
attack, damage, sleep and faint eye tracks remain unchanged.

`regional_last_eye_followup.py` prepares these four variants.
`regional_last_eye_review.py` verifies hashes, exact GLB geometry/skin/skeletal
motion parity and fresh runtime pose bounds, then records the candidate set.
All four runtime scenes load and switch poses without errors; all sampled
bounds remain within 0.00001 m of the previous revision. Six focused existing
eye-motion and geometry-parity tests pass. No performance admission is implied.

Current runtime report: `runtime-final-v4.json`; placement and technical proof:
`eye-last-two-v2/placement.json` and `eye-last-two-v2/geometry-proof.json`.
The new comparison is `eyes-last-two-review-v1/index.html`, with eye close-ups
and all captured attack/sleep/faint poses. Both pairs still require visual
approval. The previous comparison remains as historical evidence.
