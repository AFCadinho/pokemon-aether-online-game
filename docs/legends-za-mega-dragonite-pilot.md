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
