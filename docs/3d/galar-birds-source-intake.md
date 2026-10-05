# Galarian legendary birds: source investigation

2026-10-05, task `galar-birds-source-review`, frontend slot-c.

## Result

All three Galar forms have identifiable local source models, official normal
and rare material tables, textures, skeletal clips and material-animation
files. They can enter candidate production without finding another source.
They are not yet approved runtime models or uploaded bundles. The ordinary
Articuno, Zapdos and Moltres models are different forms and must not substitute
for these species.

`tools/sprite_factory/catalog_galar_birds_source_intake.json` pins the archive
members, source SHA-256 values, SCVI resources, material changes, selected raw
motions and local preview evidence. All approval flags remain false. This task
changes documentation and intake evidence only.

| Species | Biochao `Gen1.zip` member | SCVI resource | Source clips | Meshes |
| --- | --- | --- | ---: | ---: |
| articuno-galar | pm0144_31.blend | pm0144_00_31 | 55 | 2 |
| zapdos-galar | pm0145_31.blend | pm0145_00_31 | 43 | 3 |
| moltres-galar | pm0146_31.blend | pm0146_00_31 | 57 | 5 |

Each archive member contains one rig. Identity was also checked visually
against the matching SCVI model icon. The model dump supplies geometry and
material data; the matching `SV Every File/romfs/pokemon/data/pm####/...`
directories supply 55, 43 and 57 `.tranm` files respectively, with equal
numbers of `.tracm` files. An empty animation search in the model-only dump
does not mean that motions are missing.

## Proposed animation mapping

The JSON records full action names, including the `.gfbanm` suffix. Each
selected action is present in the Blend file and has corresponding raw
skeletal and material files.

- **Articuno:** bank 2 `20000_defaultwait01_loop` for the floating battle
  pose, two physical attacks, special attack, damage and faint start/loop.
- **Zapdos:** bank 0 `00001_battlewait01_loop` for its standing battle pose;
  both physical attacks, special, damage, sleep and faint are in that bank.
- **Moltres:** bank 2 `20001_battlewait01_loop` for flight, two physical
  attacks, special, damage and faint start/loop.
- **Articuno and Moltres sleep:** only the grounded bank 0
  `00281_sleep01_loop` is available in these sources. This is an explicit
  cross-bank candidate, not an automatically approved transition. Full pose
  channels, floor clearance and return to flight need Godot verification.

The mapping deliberately excludes optional additional source clips. Native
attack motion does not by itself supply move VFX such as beams or impacts.

## Materials and shiny requirements

The existing material-profile parser recognizes every material, but reports
`existing_graph_validation_required` for ordinary body/eye graphs. Recognition
is not proof of correct Godot output.

- **Articuno:** two distinct rare body textures. The compared eye parameters
  are unchanged between normal and rare.
- **Zapdos:** two rare body textures **and six eye-colour parameter changes**
  across both eyes. These include base and emission layers. A texture-only
  substitution would retain incorrect normal eye colours.
- **Moltres:** four rare textures (two body, two eyelid) **and nine flame-colour
  changes** across `fire_a_00`, `fire_a_01` and `fire_b`. The fire profiles
  require layered opacity, displacement using the second UV set, material UV
  animation and unlit rendering. The existing pipeline recognizes
  `scvi_unlit_layered_displacement_uv2_v1`; its effect payload must accompany
  the exported model. A plain static material export is insufficient.

The existing `catalog_shiny_production.replacements()` validator accepts all
three official normal/rare comparisons with review mode, material scoping and
float/colour checks enabled. It finds eight changed texture pairs, fifteen
colour overrides and no changed float overrides. This confirms available
source data; shiny candidates have **not** been rendered or visually approved
in this investigation.

## Source preview evidence and limits

Local evidence remains under
`.tmp/galar-birds-source-review/{articuno-galar,zapdos-galar,moltres-galar}/`:

- `probe.json`: isolated rig, mesh/material counts and all action names.
- `review-job.json`, `normal/review.json`: explicit action mapping and eleven
  320px captures per species: idle front/back, three samples of each physical
  attack, special attack, sleep and faint endpoint.
- `portrait-job.json`, `portrait/review.json`: two 768px idle captures per
  species, fitted to idle rather than the larger union of attack bounds.
- Moltres also has `face-job.json` and `face/review.json`: two lateral 768px
  views at mid-idle, exposing the face behind the flame surfaces.
- Source files were hash-verified before loading, never saved, and opened
  with embedded scripts disabled and network access removed.

The normal source renders show the expected purple Articuno, orange/black
Zapdos and black/pink Moltres. Articuno's narrow blue eye regions and Zapdos'
yellow eye region are visible in the close views. Moltres' blue eye region is
visible in the lateral view; its wing and tail fire surfaces are present.
Static captures cannot qualify animated opacity,
shader displacement, closed-eye expressions or fine facial details in the
game renderer. These remain required checks during production.

The first portrait attempt failed to write output because its own temporary
directory was accidentally granted read-only access. Correcting that sandbox
argument produced all six portraits. No source asset repair was made.

## Reproduction and next work

The intake JSON contains sufficient source identities and action mappings to
recreate jobs for existing `catalog_remaining_legacy_worker.py` and
`phase5_source_review_worker.py`. Set `source` to the extracted, hash-verified
member, `source_sha256` and `actions` from the intake, and `output` to a new
evidence directory. Run Blender with `--factory-startup --disable-autoexec
--python-exit-code 1`, offline and with access restricted to that evidence
directory and the trusted worker directory. The disposable portrait worker
only changes resolution from 320 to 768 and the Python import path; its jobs
select idle only. Its digest is preserved in the intake.
The additional Moltres face worker uses mid-idle and lateral camera vectors
`(7, -3, 1)` and `(-7, -3, 1)`; its digest is also recorded.

Recommended production order: Articuno and Zapdos together, then Moltres with
its effect payload. Produce six normal/shiny candidates, verify eye layers
and source rare parameters, check all motion transitions and battle scale in
both cameras, then request visual review. After approval: runtime form
resolution/preloading, performance checks, individual bundles and separately
authorized R2 publication. Do not add these records directly to an approved
catalog from this source-intake report.

Focused evidence checks passed: all three archive hashes, 24 selected action
names and their 48 raw motion files, recognized material profiles, official
rare comparisons and all 41 expected source images. There are no runtime code
changes, so no Godot gameplay tests or full release gate were run.
