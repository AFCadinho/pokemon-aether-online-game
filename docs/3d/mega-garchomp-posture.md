# Mega Garchomp posture investigation

2026-10-05, task `mega-garchomp-posture`.

## Findings

The user's report is confirmed for ordinary Mega Garchomp. Its approved runtime
idle is `pm0445_51_00_20001_battlewait01_loop`: the body is horizontal, arms out
and legs behind, visually a flight pose. The retained native ZA source also has
`pm0445_51_00_00001_battlewait01_loop`, which visibly stands upright. This is an
animation-bank selection issue, not a camera tilt or a missing model.

Mega Garchomp Z is separate (`pm0445_52_00`). Its own
`pm0445_52_00_20001_battlewait01_loop` is already upright. Normal and shiny were
rendered from their exact approved runtime files; no matching posture issue was
found. Its extended arms belong to that native pose. It has no equivalent bank
00 in this source resource, and should not inherit ordinary Mega Garchomp's clips.

## Review candidate

The candidate uses ordinary Mega Garchomp's native bank 00 for idle, physical and
special attacks, damage and fainting. Rest uses that same native down loop. A
matching set avoids abruptly returning to the flying bank during attacks.
The original approved normal/shiny geometry and materials remain in the scenes;
the candidate replaces skeletal animation only and preserves existing other
animation tracks. Skeleton names, order and rest transforms match exactly.
This was the review proposal; the approved client integration is documented below.

Reproducible tools:

- `tools/sprite_factory/mega_garchomp_posture_import.py`: hash-bound read of the
  retained Mega source into a separate review directory.
- `mega_garchomp_motion_export.py`: animation carrier with no exported materials.
- `mega_garchomp_posture_candidate.gd`: exact approved SCN hashes and skeleton
  compatibility checks before generating isolated review scenes.
- `mega_garchomp_posture_review.html`: comparison page template.

The regular material exporter initially rejected the new import because a new
material export lacked the full catalog provenance it requires. We retained that
check and used a dedicated animation-only carrier. No newly exported geometry or
materials are used in the candidates.

Evidence and source pins are in `mega_garchomp_posture_checkpoint.json`. The
retained local review is `.tmp/mega-garchomp-posture-v1/review/`, served at
`http://127.0.0.1:8803/`. Six entries (old/new normal/shiny and unchanged Mega Z
normal/shiny) passed duration, finite posed geometry and reverse-order pose
checks. All 36 screenshots rendered successfully. This is an appearance review,
not a battle scale/performance qualification. Browser automation was unavailable;
`xdg-open` was invoked and page/image HTTP 200 responses were verified.

The investigation itself left game registries, approved bundles, R2 and production
unchanged.

## Approved standing integration

2026-10-05, task `mega-garchomp-standing`. The user's response **“ja goedgekeurd”**
approves the exact comparison above. The checkpoint binds this to its HTML and
36 screenshots. Mega Garchomp Z remains on its existing native animation set.

The correction follows the existing Gliscor client animation override:
`resources/battle/model_animations/mega_garchomp_standing.res` contains only skeletal
tracks from the same native bank 00. Missing bone channels receive constant rest
keys so prior actions cannot leak into later ones. All 70 sampled normal/shiny
poses match the approved candidate's bone transforms. Existing non-skeletal
tracks were confirmed to be static `visible=true` on already visible meshes;
no new mesh/material/property tracks are shipped.

The override is restricted to the two exact approved SCN hashes in
`mega_garchomp_standing.json`. It updates action timing and measured placement
through `ReviewedModels.resolve`, and installs actor-owned animation libraries
in the battle presenter and Pokédex/summary preview. It never mutates a shared
library or applies to Mega Garchomp Z, an unrelated identity, or a future model
revision. Attack clips keep their native entry/exit motion; idle/sleep retain
a 0.2-second blend, verified through the live presenter.

All seven actions were measured at 120 Hz. Idle grounding lift is
0.0392560351 units, with 60 Hz conservative clearance curves for other actions.
The real battle presenter passed both cameras, both appearances, and repeated
idle/attack/damage/sleep/faint transitions at 1× and 4× playback. Minimum observed
floor clearance was 0.0266221166 units, above the existing 0.005 check threshold.
Pokédex and summary controls both loaded the standing two-second idle for normal
and shiny. Runtime screenshots were visually inspected.

Focused checks and reproducible tools (run through `slot-env slot-a`):

- `tests/mega_garchomp_standing_check.gd`: exact hashes, safe skeletal tracks,
  per-actor library isolation, timing/placement and unchanged Mega Z profiles.
- `tools/sprite_factory/build_mega_garchomp_standing_library.gd -- MOTION_GLB APPROVED_SCN OUTPUT_RES`:
  source hash, exact skeleton compatibility and static visibility guards.
- `measure_mega_garchomp_standing.gd -- APPROVED_SCN OUTPUT_DIRECTORY`:
  posed-vertex envelopes and floor clearance curves.
- `check_mega_garchomp_standing_review.gd`: 70 approved candidate pose comparisons.
- `check_mega_garchomp_standing_battle.gd -- LOCAL_CATALOG OUTPUT_DIRECTORY`:
  actual presenter, 14 screenshots and live transitions at 120 Hz.
- `check_mega_garchomp_standing_previews.gd -- LOCAL_CATALOG OUTPUT_PNG`:
  actual normal/shiny Pokédex and summary controls.

Retained local evidence is in `.tmp/mega-garchomp-standing-v1/`; its digests and
results are recorded in `mega_garchomp_standing_checkpoint.json`.
The approved SCN files and public v9 index stay byte-identical. No R2 upload is
needed for this correction: the library ships with the game client. Local
integration enables it in newly started development clients; production requires
a later client release. This task does not certify or publish a release.
