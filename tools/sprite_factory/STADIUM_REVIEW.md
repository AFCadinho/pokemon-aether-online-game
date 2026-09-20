# PokeAether stadium study

Original procedural 3D arena inspired by the user's purple stadium reference:
tiered seating on all four sides, emissive fascia and roof fixtures, a marked
polished floor, two animated screens and the existing tracked PokeAether logo.
The reference image itself is not used as geometry, a texture or a skybox.
No new purchased assets. Model/logo distribution rights remain unchanged.

## Open

The prepared local preview can be started from any working directory:

```sh
bash tools/sprite_factory/open_stadium_review.sh
```

For a fresh local review project, from the frontend checkout:

```sh
python tools/sprite_factory/prepare_stadium_review.py ../.worktrees/slot-c/.tmp/stadium-review-01
../ops/worktrees/slot-env slot-c -- godot --headless --editor --path ../.worktrees/slot-c/.tmp/stadium-review-01 --quit
bash tools/sprite_factory/open_stadium_review.sh
```

Preparation copies only ten explicit source/shader files and two tracked logos;
never caches, userdata or machine configuration. The existing prepared local
Dragonite/Roaring Moon runtime catalog is required. Right-drag orbits, wheel
zooms, Tab hides controls and Play both tests the selected animation.

## Rendering / scope

The three neutral Pokémon lights, materials and high shadow filtering stay fixed.
Arena accents use emissive geometry; there are no additional colored actor lights.
The display viewport adds restrained glow and screen-space floor reflections.
The auxiliary material-irradiance viewport disables both, avoiding reflected or
glowing lighting data and unsupported SSR with a transparent background.
SSR is view-dependent and can lose off-screen reflections; it is not ray tracing.
The floor glow and translucent overhead beams are art-directed, not bounced
lighting or volumetric scattering. The crowd is a deterministic
MultiMesh of inexpensive silhouettes, not detailed animated spectators.

This is a desktop visual candidate, not a wired PvP arena. No authority, battle
flow, existing arena selection or client defaults change. Production integration,
export testing, wider hardware performance and final art approval remain pending.
Review startup still performs the existing full-idle grounding calibration.

## Focused checks

`python tools/sprite_factory/test_prepare_stadium_review.py` checks preparation.
The inherited smoke checks neutral lights, full-idle ground clearance, four camera
angles, seven animation starts and teardown of both viewports. This is not full
development certification or a multiplayer PvP acceptance test.

Local evidence (2026-09-20): slot-c/.tmp/stadium-run-04.log and
stadium-capture-04/. Smoke completed without logged errors/warnings; idle minimum
clearance 0.0250/0.0255; seven action starts and viewport teardown passed.
Short sampled p95 frame time 17.221 ms, max 17.473 ms on RTX 3070 Laptop.
This is not a broad hardware benchmark. Preparation tests (3), shell syntax
and diff whitespace checks passed. The main screen framing, distant crowd,
architectural detailing and light shafts remain first-pass art for user review.

Branding: the emblem and wordmark are byte-identical to the user's Documents/logo
files `43327 05 1024x1024.png` and `43327 02.png`. Reuse the existing tracked
assets rather than importing duplicates. Wordmarks replace plain-font fascia and
screen branding; original alpha and aspect ratio are preserved.
