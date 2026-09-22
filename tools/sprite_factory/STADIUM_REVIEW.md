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

Preparation copies only allowlisted source/shader files and two tracked logos;
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
MultiMesh of inexpensive swaying silhouettes, not detailed character animations.

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

## Animated ambience follow-up

Six open, soft-edged beam meshes sweep slowly from fixed ceiling fixtures.
Their shader phases match six art-directed floor highlights, outside the central
fighting area. Extra mid-tier strips, subtly swaying crowd silhouettes and a second
MultiMesh of supporter lights add movement without thousands of light nodes.
These are visual shader effects, not additional lights affecting Pokémon materials.
The existing screen background remains animated. Original emblem texture floats
by 0.16 world units with a 2.5% scale pulse; emblem and wordmarks receive a broader diagonal sheen,
with a pause between sweeps. Wordmarks do not move or distort; alpha is preserved.

Visibility follow-up: highlight sweeps recur about every four seconds instead of
the previous long quiet interval. Crowd geometry now combines a head, torso and
two shader-articulated arms in one instanced mesh. Each instance supplies its own
phase and enthusiasm via custom data, avoiding synchronized crowd motion. Supporter
lights use the same individual phases; there are still no per-spectator light nodes.
This remains stylized distant crowd art, not fully rigged character animation.
Follow-up smoke: `stadium-cheer-run-02.log` and `stadium-cheer-capture-02/` in
slot-c/.tmp. Per-instance data and arm tags asserted; animation, idle clearance,
seven action starts and teardown passed. Sampled p95 17.85 ms, max 17.983 ms.

Local evidence: `stadium-live-run-03.log` / `stadium-live-capture-03` in slot-c/.tmp.
Fixed-camera captures with paused actors differ across 120 frames, independently
confirming animated ambience. Full idle clearance, seven action starts and viewport
teardown also passed, with no logged errors/warnings. Short-run p95 17.226 ms,
max 23.682 ms on RTX 3070 Laptop; not a broad hardware benchmark. Three preparation
tests pass. Visual before/after images and orbit images remain available for review.
