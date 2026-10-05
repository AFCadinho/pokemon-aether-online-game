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
This is a proposal, not runtime admission or publication.

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

The standing proposal, sleep and faint poses still require visual review. Battle
placement and transitions must be qualified before applying the change. Game
registries, approved bundles, R2 and production were not changed by this task.
