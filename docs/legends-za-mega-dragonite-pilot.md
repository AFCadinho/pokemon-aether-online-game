# Legends ZA Mega Dragonite: local 3D pilot

Status: **battle preview passed; not release qualified** (26 September 2026).
This experiment does not add a selected model, bundle, content index entry, or
download. All converted assets and screenshots remain outside the game tree.

## Source and conversion

- Archive: `/home/adinho/Documents/3d_models/LegendsZAPkmnModelDumpWithDLC.rar`,
  SHA-256 `1436f8d94c390a2ceb9f60a44596023c1c79ea911f10c3eacf80e7ed02223ccc`.
  The RAR integrity test passed. Its `pm0149/pm0149_51_00` directory is Mega
  Dragonite; extracted pilot files are under
  `/home/adinho/Documents/3d_models/LegendsZA-Mega-Dragonite-pilot`.
- Imported with ChicoEevee SCVI importer commit
  `b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04` and Blender 5.2. The
  prepared `.blend` SHA-256 is
  `3047b69a909e3a0244cd60216a6b054375a642f2f76c5dc93692e1c0e06cda8e`.
  Import report: `/home/adinho/Documents/3d_models/LegendsZA-Mega-Dragonite-import-test/import.json`.
- Six native source clips mapped to idle, physical attack, special attack,
  damage, faint start, and faint loop. The archive has no sleep loop for this
  model, so the **local pilot only** aliases idle to sleep.
- Direct Blender GLB export rendered with visibly incorrect red/pink materials.
  Baked albedo plus normal and roughness maps produced a plausible Godot
  appearance. The pilot GLB SHA-256 is
  `a45291d876000fdf30d595ac63a0d1249851c95f94c033c107efe9c17161d5b7`.
  The standalone Godot scene SHA-256 is
  `0a5cf0f1953997c4547372552ac13b7d8e38f63d00fa23cac0df7f30bcccc4c9`.

## Verification

- Existing `validate_battle_3d_report.py` accepted the baked GLB report.
- Existing `prepare_battle_3d_runtime.gd` produced and reloaded a standalone
  `.scn` with seven battle actions (including the sleep alias). The runtime
  report is
  `/home/adinho/Documents/3d_models/LegendsZA-Mega-Dragonite-import-test/runtime-pilot/report.json`.
- Existing Godot visual review rendered front, back, attack and faint views.
- A local battle harness loaded the scene through the actual 3D battle
  presenter. Both combatants became active without a fallback. Idle, physical
  and special attacks, sleep, damage, and faint start were invoked and captured.
  See `battle-idle.png`, `battle-attacks.png`, `battle-sleep.png`,
  `battle-damage.png`, and `battle-faint.png` in the runtime pilot directory.
  The visible idle and attack poses have coherent color and framing. This is a
  scripted battle preview, not a complete player-driven battle or Mega
  transformation test.

## Remaining qualification

- Import reports inherited eyelid pose warnings and unapplied TRACM material
  and visibility tracks. The still images do not prove every animated material
  or visibility state is correct throughout each clip.
- The baked materials do not yet reproduce source emission, alpha, or stylized
  lighting. Inspect these in motion before accepting this model.
- Produce and review the rare/shiny material variant separately. Confirm
  normal-to-Mega model switching in a real battle, along with move timing,
  sleep behavior, and faint loop over their full durations.
- Only after battle qualification, create an individual bundle and run the
  existing update/install/rollback checks before any release selection.

The screened catalog was altered temporarily for this local smoke test and
restored afterwards. No Mega model is admitted to the selected catalog.

## Normal and shiny battle qualification pass (26 September 2026)

The archive's rare material was imported separately with the same pinned
importer. Prepared shiny `.blend` SHA-256:
`f81a5645f9d26e1f92094a501b38f8088e03030a645ef456f4f7db99611d9f75`.
The baked shiny GLB passed `validate_battle_3d_report.py`, and the Godot
converter produced a standalone scene with SHA-256
`ce2f4a119f14d0d805eaa9d3ab8379bdc5869b14e8171ec49a34a4bc5a1b3a8e`.
Artifacts: `/home/adinho/Documents/3d_models/LegendsZA-Mega-Dragonite-shiny-test`.

The real battle presenter loaded a local Dragonite candidate, changed the
player's displayed species through the battle sprite/model update path to
normal Mega Dragonite, and displayed shiny Mega Dragonite on the opponent's
side. Both Mega models completed physical attack, special attack, and damage;
sleep stayed active; faint start advanced to faint loop. Godot logged no
model, pose, or timing errors. Focused existing Mega presentation and display
data checks also exited successfully.

The `before-mega.png`, `after-mega-normal-shiny.png`, `mega-physical_attack.png`,
`mega-special_attack.png`, `mega-damage.png`, `mega-sleep.png`, and
`mega-faint-loop.png` screenshots record the battle view. Normal and shiny
colors, positions, and poses look coherent in these samples. The base
Dragonite in this test is a local catalog candidate, not the released bundle.
This exercises the shared species update path but does **not** run a complete
player-driven turn or the full Mega overlay/event sequence. The live local
review window allows a human to toggle the form and replay actions.

Qualification remains pending human review in motion and a complete battle
Mega event. The sleep animation is still an explicit idle alias; source TRACM
visibility/material tracks and the full stylized shader are still unported.
The temporary screened-catalog entries are not release approval, and neither
variant has been bundled or uploaded.

## Faint floor intersection found in human review

The live review exposed both tails passing through the platform during faint.
A rendered 60 Hz pose sweep measured a minimum Y of about **-1.18** in the
source faint loop for both variants; idle requires only **+0.046** grounding.
Applying a whole-actor clearance offset keeps the tails visible but makes the
fainted body float noticeably. That attempt was rejected.

The local replacement preserves the start of the native faint animation
through source frame 104 of 120 (about 1.75 s), before the intentional sinking
phase. Its faint loop reuses source frames 104–105 as a short held pose. The
existing clearance baker then covers the remaining shallow contacts. Fresh
Godot runtime scenes and 60 Hz pose measurements passed for both variants.
The candidate scene SHA-256 values are:

- normal: `4fb8c2d04b26f2499bfe4c4539af610190feec6f8ee7d79ef0addb81ec634841`;
- shiny: `5541a8ee59ad233c41606674292207e6c355ded37755b6784acaa23bcfbc2c56`.

The latest scripted battle review captured both actors in `faint_loop` with
their full tails above the platform:
`/home/adinho/Documents/3d_models/LegendsZA-Mega-Dragonite-shiny-test/fixed-mega-faint-loop.png`.
Earlier `runtime-pilot` artifacts remain diagnostic history; the `runtime-faint-crop2`
directories contain the current local candidates. Neither version is selected
for release.

These candidates still expose only one `physical_attack`. The ZA source has
`attack01` as one complete clip and `attack03_start`, `attack03_loop`, and
`attack03_end` as a separate staged attack. The latter has not been assembled
or reviewed as the game's `physical_attack_2` action. It must not be claimed
as a second available physical attack in this pilot.
