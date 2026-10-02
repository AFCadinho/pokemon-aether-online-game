# Mega 3D catalog production

Updated 2026-10-02. This is a local production checkpoint; it does not approve,
activate, upload, or publish any new model.

## Catalog coverage

The Pokédex lists **97 Mega form variants across 87 base Pokémon**. Mega
Dragonite is the only one with an already-approved normal/shiny bundle.

The connected `LegendsZAPkmnModelDumpWithDLC.rar` contains matching model
resources for **72 variants**. Mega Dragonite is already approved, so the
production run produced **71 additional normal/shiny candidate pairs**. This
includes Mega Hawlucha (`pm0701_11_00`), which was initially missed because its
model uses an alternate resource code. The remaining **25 variants across 21
Pokémon** have no matching Mega resource in this dump:

- Chesnaught, Delphox, Greninja, Pyroar, Floette, Meowstic (male and female),
  Malamar, Barbaracle, Dragalge, Zygarde, Crabominable, Golisopod,
  Drampa, Magearna (both forms), Zeraora, Falinks, Scovillain, Glimmora,
  Tatsugiri (all three forms), and Baxcalibur, and Diancie.

The local Scarlet/Violet dump and the attached Biochao packs were checked for
matching Mega resource identities; they do not fill this 25-form gap. Those
forms need suitable Mega-specific rigged sources before they can go through
this pipeline.

## Candidate run

The initial 72 forms each have normal and shiny GLBs and standalone Godot
scenes: **144 scenes total**. All passed the import/export and scene reload
steps. One is now held: the purported Mega Diancie source and its icon actually show
a fox with fire/stick meshes. Its generated artifacts are preserved for diagnosis,
but it is excluded from the 71-pair review.

No runtime or appearance approval has been recorded, and no Mega bundle,
catalog entry, or R2 object has been created for these candidates.

The review page is at:

`http://127.0.0.1:8795/mega-native-rest-v1/review-v5/index.html`

It displays normal and shiny side by side and lets the reviewer inspect idle,
attacks, sleep, damage, and faint poses. It is framed for appearance review;
final battle size and floor placement still require the battle review.

The first review revealed incorrect layer ordering and eye occlusion. Source
table comparison found 432 native opaque materials exported as `BLEND` in each
variant. The corrected candidates restore 435 opaque materials and one authored
alpha-cutout material per variant, preserving the two genuinely transparent or
additive materials. This changes material opacity only; mesh, skinning, UV and
animation accessors are checked against the original candidate exports. The
review includes an eye close-up control for inspecting remaining face issues.
All 144 corrected Godot scenes reload. A separate check traversed 1,412 material
bindings and confirmed the native opaque/cutout settings with zero mismatches.

Known review points from source diagnostics:

- 70 reviewable forms use their own Mega down-loop as a review-only rest pose because their banks
  lack a sleep loop. The prior base-form retarget distorted several Mega bodies
  and applied incompatible visibility; it has been removed. Mega Hawlucha has
  its own native sleep loop. The fallback is explicitly labelled on the page
  and still needs visual acceptance as a rest pose.
- 11 forms have dynamic source mesh-visibility tracks. Those tracks are
  attached to the Godot scenes and require visual inspection.
- Only 11 forms have a second physical attack selected from the source.
- 48 forms have an inherited eyelid diagnostic on at least one selected pose.
- Source material-animation tracks are not replayed in the generated GLBs.
  Static normal/shiny material tables are applied; the review page labels this
  limitation. Any form whose animated material layers matter needs follow-up.

These are candidates, not a claim that all 71 are ready to release. Review the
appearance first, resolve visible issues, then run battle-size/pose qualification
and make individual bundles only for accepted forms. The 25 source holds stay
on 2.5D until matching Mega sources are available.

The exact form-to-source map, source identity evidence, and source archive
SHA-256 are recorded in
[`catalog_mega_3d_source_intake.json`](catalog_mega_3d_source_intake.json).

## Appearance review accepted

On 2026-10-02 the user accepted the appearance of all 71 review pairs, with
Mega Steelix size left uncertain because the overview camera was distant.
The hash-pinned acceptance is in `catalog_mega_appearance_checkpoint.json`.
This is appearance acceptance only: battle and runtime approval remain false.

A focused native Godot idle check shows Mega Steelix is not undersized: scale
1.0 clips above the classic camera, whereas the review proposal 0.7 fits all
four camera/side views for normal and shiny. The user has accepted the 0.7 scale; full-pose calibration remains pending. The overview now frames visible posed
geometry rather than the unanimated mesh bounds.

## Steelix surface follow-up

The user accepted the proposed 0.7 size but reported incomplete-looking detail.
Steelix appearance was held again; the other 70 appearance acceptances
remained pinned. All seven source meshes are present. A separate review-only
recovery restores the source-masked metallic values for body_a/body_b/body_c
and the body_d crystal layer light. Geometry, UV, rig and animation signatures
are unchanged; both new standalone scenes convert and reload.

Neutral reflection lighting is identical before/after in the new diagnostic.
This is a static PBR approximation, not native view-dependent refraction parity.
The new models and accepted detail review are pinned in
`catalog_mega_steelix_surface_checkpoint.json`. The user then accepted normal and shiny with “deze zijn goed”. All 71
normal/shiny appearance pairs are accepted; full-pose battle qualification
remains outstanding. The combined, source-pinned follow-up input is
`.tmp/mega-native-rest-v1/appearance-approved-status.json`, which selects the
corrected Steelix GLBs and SCNs rather than its superseded first export.
