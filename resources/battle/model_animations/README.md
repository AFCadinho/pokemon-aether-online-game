# Gliscor flight correction

Gliscor's original installed normal/shiny scenes use source bank 0's low
`00001_battlewait01_loop` ground stance. Raising that stance by 0.6 m does not
make it a flight animation. The source's bank 2 contains the upright airborne
stance, with raised claws and a hanging tail.

`gliscor_flight.res` contains skeletal animation tracks only. The client applies
it to the two exact model hashes listed in `gliscor_flight.json`, in battle,
Pokédex and summary previews. Downloaded meshes, materials, normal/shiny colors,
bundle hashes and installation state are unchanged. The patch ships with the
client, so it also works with already installed bundles. No R2 publication is
needed for this client correction. Unknown or future model hashes do not inherit
the animation or its measured profile.

## Provenance and reproduction

- Source: `Biochao/Gen4.zip`, member `pm0472.blend` (renamed `pm0472_00.blend`
  for the existing source worker). The SHA-256 and action names are in the JSON.
- Export with `tools/sprite_factory/phase5_godot_export_worker.py`, a job using
  that source hash, `source_actions` from the JSON, and `scvi_pbr_probe: false`.
  Run Blender with `--disable-autoexec` as in the existing source pipeline.
- Run `build_gliscor_flight_library.gd -- SOURCE_GLB APPROVED_NORMAL_SCN OUTPUT_RES`
  through the slot Godot wrapper. It verifies the export/model hashes, identical
  bone names/rest transforms and matching track paths. Only skeletal channels
  are retained. Missing channels receive their rest value so previous actions
  cannot contaminate a pose.
- Special attack joins the source start, one loop and end. The airborne bank
  has one physical attack; the old ground-only second attack is omitted.
- Sleep keeps the approved model's expression and pose. Sleep/wake blend over
  0.2 seconds. Attacks/faint retain their own native entry/exit motion.
- Run `measure_gliscor_flight.gd -- APPROVED_NORMAL_SCN OUTPUT_DIRECTORY` with
  graphical Godot. `profile.json` provides the profile stored in the JSON:
  120 Hz skinned bounds and floor clearance, conservative 60 Hz offsets for
  non-idle clips. The old extra hover height is absent.

## Verification

- `tests/gliscor_flight_check.gd`: exact hashes, skeletal-only tracks, timing,
  placement, clearance profile and independent per-actor animation libraries.
- `tests/model_placement_check.gd`: Gliscor has no extra hover; Weezing retains
  its height correction.
- `tools/sprite_factory/check_gliscor_flight_battle.gd -- LOCAL_CATALOG OUTPUT_DIRECTORY`:
  real downloaded normal/shiny scenes, seven poses, both cameras, and live
  sleep/wake/attack/faint transitions at 1x and 4x. Lowest measured point in the
  live transition run: 0.0280 m above the floor.
- `tests/summary_model_preview_check.gd` with `SUMMARY_MODEL_SPECIES=gliscor`,
  `SUMMARY_SECOND_SPECIES=gliscor` and `SUMMARY_MODEL_CATALOG=LOCAL_CATALOG`:
  actual preview loading, replay, rotation, hidden previews and independent cards.

Weezing was checked separately against `Biochao/Gen1.zip`, `pm0110_00.blend`,
SHA-256 `9459fc997213788821f2b51569feda2009a616d6122f94828d909c0645cb462c`.
Its installed model already uses `20001_battlewait01_loop.gfbanm` and the matching
bank-2 attack/sleep/faint clips. That archive has no separate bank-0 ground set.
Its existing 0.45 m presentation lift is retained.
