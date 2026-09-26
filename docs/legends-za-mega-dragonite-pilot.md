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

Qualification remains pending a complete battle Mega event. The corrected
faint pose passed human review in the local battle window. The sleep animation
is still an explicit idle alias; source TRACM
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
The player confirmed the corrected faint view looks good in the reopened
interactive battle preview.
Earlier `runtime-pilot` artifacts remain diagnostic history; the `runtime-faint-crop2`
directories contain the current local candidates. Neither version is selected
for release.

These candidates still expose only one `physical_attack`. The ZA source has
`attack01` as one complete clip and `attack03_start`, `attack03_loop`, and
`attack03_end` as a separate staged attack. The latter has not been assembled
or reviewed as the game's `physical_attack_2` action. It must not be claimed
as a second available physical attack in this pilot.

## Second physical attack and sleep candidate (26 September 2026)

The next local candidate combines the Mega source's `attack03_start` (35
frames), `attack03_loop` (21 frames), and `attack03_end` (101 frames) into one
155-frame `physical_attack_2` at 60 Hz. The exporter now supports a reviewed
ordered list of source phases on a single NLA track. This is separate from the
existing `attack01` physical action. Both normal and shiny Godot scenes expose
eight battle actions.

The **Mega** source directory has no sleep animation. The same archive does
contain `pm0149_00_00_20281_sleep01_loop` for ordinary Dragonite. That 161-frame
action was imported onto the Mega rig and replaces the earlier idle-as-sleep
alias in this local candidate. It is a retargeted base-form motion, so the
Mega-specific wings, tail, and face still need human review in motion. The
importer reports inherited eyelid-pose and unapplied TRACM material/visibility
tracks; those limitations also remain for the other actions.

Artifacts are under
`/home/adinho/Documents/3d_models/LegendsZA-Mega-Dragonite-attack2-test`.
The prepared Blender source SHA-256 values are
`6520c4fab420a0bf9573a462232a8ed61c21c724c448508d5cdcf0460987d662`
(normal) and
`975fbf1214c80191f27744ba979067bd7a5d1494a091d0ad95b92c99f53739df`
(shiny). The corresponding Godot scene SHA-256 values are
`ea0f7d23ee709b8c571b35ee4500512223229be31731a1c7b1178e81841bebdb`
and `367557de31b200b0927527e7f5723696b1cfefba446853cf0bca6adaadff4ed7`.
Both GLB reports passed the existing validator, both Godot scenes reloaded,
and rendered 60 Hz grounding measurements were baked into motion profiles.
The local battle presenter loaded normal and shiny, played both physical
actions and sleep, and advanced faint start to faint loop without a pose or
timing error. Screenshots named `composite-mega-physical_attack_2*.png` and
`composite-mega-sleep*.png` show sampled battle poses. This remains a local
candidate; no selected catalog entry, bundle, content-index entry, or upload
has been made.

## Sleep eyes corrected in local review (26 September 2026)

Human review found the eyes visibly open during the borrowed Dragonite sleep
loop. The base-form clip omits ten Mega upper-eyelid tracks. A fresh normal
and shiny import uses Mega Dragonite's own `28000_eye01` frame 10 as the closed
eyelid baseline for those missing tracks; both import reports now have no
unresolved sleep eyelid warning.

The eyes were still visibly open in Godot because the baked eye image contains
the open iris. The base sleep TRACM specifies a fixed eye UV offset of about
`-0.35513`, which the current PBR material bake does not preserve. Applying
that offset to a material override did not survive the battle presenter's
material-response pass. The reviewed local candidate therefore hides the eye
mesh **only during sleep**, with the closed eyelid pose retained, and restores
it for all other actions. This is an explicit visual approximation, not a
claim of full source eye-shader parity. The offline, SHA-pinned transformation
is implemented by `battle_3d_action_visibility_patch.gd`; its inputs and
reports are in the `eyelid-fix/{normal,shiny}` artifact directories.

Both corrected Blender exports passed the report validator, both Godot scenes
reloaded, and rendered 60 Hz grounding checks reported zero errors. The local
battle presenter exercised normal and shiny idle, two physical attacks,
special attack, damage, sleep, and faint start/loop without a model, pose, or
timing failure. The corrected sleep and late-sleep screenshots are in
`eyelid-fix/composite-mega-sleep*.png`. The player then confirmed the closed-eye
sleep appearance in the reopened interactive battle preview. The final local
scene SHA-256 values are
`044a0801792b20457736787e3f4ffb4e26afb68ef6ff05260556e9bdceac1881`
(normal) and
`2537d353bcbeb5a3a2a3b7e15455ab437b049382858f911f1b6822dca1ae5cad`
(shiny). This is still a local pilot: the complete Mega event and release
bundle qualification remain pending, and neither scene is selected or
uploaded.

## Local 3D Mega Evolution preview (26 September 2026)

The ZA archive also contains `pm0149_51_00_20620_megaappeal01.tranm`:
181 frames at 60 FPS, non-looping. It is a motion on the Mega rig, not a
base-to-Mega mesh morph. The pinned clip SHA-256 is
`1466bbc4e1d95a7471e018aa56c140c017a70ddc6a6e74f62622aae752a7e46e`.
It was appended to a copy of the reviewed normal Mega source and exported as
the additional `mega_appeal` action. The GLB report passed the existing
validator and Godot reloaded the standalone runtime scene. The scene SHA-256
is `67b9f3921d2db0120776fcb030c2ecb5599e18128e7276f3f8f393f0f48cc4cc`.
Artifacts are under
`/home/adinho/Documents/3d_models/LegendsZA-Mega-Dragonite-evolution-test`.

`tools/sprite_factory/mega_dragonite_evolution_preview.gd` is a standalone
local review: ordinary Dragonite charges a 3D effect, the form changes during
the flash, then Mega Dragonite plays its native appeal. The effect uses a
CC0 Kenney particle texture as a 3D billboard, plus local 3D rings and a
flash sphere. The texture license is retained beside the texture. The script
plays the game's existing `PRSFX- Mega Evolution2.wav` from the start of the
1.35-second charge; that file lasts about 1.37 seconds. The script
accepts the base and Mega `.scn` paths via `POKEAETHER_MEGA_PREVIEW_BASE` and
`POKEAETHER_MEGA_PREVIEW_MEGA`; run Godot through `ops/worktrees/slot-env` in
an assigned slot. `POKEAETHER_MEGA_PREVIEW_AUTOQUIT=1` makes the preview run
headlessly to completion. Optional `POKEAETHER_MEGA_PREVIEW_SCREENSHOTS` saves
sample frames. The live preview has replay, reset, and camera-turn controls.

The headless pass logged the native appeal swap and completion without errors.
Rendered samples are in `screenshots-approved-layout/`. Human visual review
and real battle event timing remain pending. This work does not select a Mega
model, create a bundle, or alter the content index. The new scene exists only
to review `mega_appeal`; the previously reviewed sleep-eye correction was not
reapplied to it.
