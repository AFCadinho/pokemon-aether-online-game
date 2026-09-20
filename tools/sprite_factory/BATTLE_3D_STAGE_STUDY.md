# Shared 3D battle stage — 2026-09-20

Research only: Dragonite and Roaring Moon share one viewport with platforms,
shadows, existing battle HUD scenes and scripted attack/damage moments. No
production catalog, routing, downloads or overworld changes. The projectile
is a placeholder, not source VFX; HP changes are local demo values.

## Materials and size

Optional PBR export UV-plane bakes the reviewed source shader's albedo/eyelid
chain, normal and roughness inputs at source texture resolution. Auxiliary
maps use non-color data; glTF exports tangents. All nine materials have normal
and metallic-roughness texture references, and both models have seven actions.
Source hashes are verified before export; source files are never saved.

This is not visual parity: source emission, alpha and stylized lighting remain
unported. Highlights look strong. Scales, camera, lighting and choreography
are provisional review settings, not production species overrides.

| Payload | Dragonite | Roaring Moon | Pair |
|---|---:|---:|---:|
| Current full Q95 sprite actions/views | 23.74 MiB | 33.33 MiB | 57.07 MiB |
| GLB with albedo/normal/roughness | 5.32 MiB | 11.75 MiB | 17.07 MiB |

About 3.34× smaller for this pair. Added material detail approximately doubles
the earlier albedo-only pair's 8.40 MiB. Do not extrapolate two species to the
complete catalog. No compression or delivery architecture was implemented.

## Short desktop measurement

Godot 4.6.2, Compatibility/OpenGL, AMD integrated Radeon Renoir, Linux,
1120×500 shared viewport, 4× MSAA, shadows and 60-FPS cap:

- Both models loaded/generated synchronously in 365.6 ms, not a cold download.
- After 90 warmup frames: idle and three attacks, 623 measured intervals.
- Per-phase p95 16.69–16.70 ms; maximum 16.73 ms; zero intervals above 20 ms.
- Godot-reported static memory 115.9 MiB and video memory 120.2 MiB for this
  harness, not process RSS or incremental asset memory. Integrated GPU memory
  is shared.

Timing uses `Time.get_ticks_usec()`, not smoothed process delta. This brief
capped test does not establish GPU headroom, full-game or Android/web viability.
Evidence: `.worktrees/slot-c/.tmp/battle-stage-pbr-01/measure-02/`.
The earlier `glb/stage-runtime.json` used smoothed delta and is invalid for
performance conclusions. Follow-up `measure-03` also tests reset/side swapping.

## Reproduce

From the assigned frontend, use absolute paths and a new output directory:

```sh
python3 tools/sprite_factory/prepare_battle_3d_probe.py SOURCE_CATALOG SOURCE_ROOT PROBE_DIRECTORY --pbr-maps --species dragonite roaring-moon
flatpak run org.blender.Blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python ABSOLUTE_FRONTEND/tools/sprite_factory/battle_3d_export_probe.py -- PROBE_DIRECTORY/export-job.json
```

From the workspace root:

```sh
ops/worktrees/slot-env SLOT -- env POKEAETHER_3D_STAGE_REPORT=PROBE_DIRECTORY/glb/report.json godot --path FRONTEND_WORKTREE --rendering-method gl_compatibility --script res://tools/sprite_factory/battle_3d_stage.gd
```

Buttons review physical/special attacks, Roaring Moon's reply, reset, swapped
sides and shadows. For automation, also set `POKEAETHER_STAGE_MEASURE=1` and
optionally `POKEAETHER_STAGE_OUTPUT=ABSOLUTE_OUTPUT_DIRECTORY`. It writes frame
metrics/screenshots, checks HP/reset/side swapping, then exits.

Next: user review of materials/eyes/movement from both sides, then actual
Android and browser profiling before any migration decision.

## Camera choreography follow-up

`Dragon Pulse · demo` now eases toward Dragonite for 0.3 seconds, tracks toward
the target over the 0.5-second projectile flight, holds the impact framing,
then returns to the fixed overview over 0.65 seconds. Only this special attack
uses camera motion. HUD controls remain outside the 3D viewport and stationary.
Focus follows model positions after swapping sides; this is a restrained camera
move, not a continuous orbit. Close-ups may crop the non-focused combatant.

The `Camera motion` switch is enabled by default for review. Switching it off
immediately restores the overview, even mid-attack. Turning it on applies to
the next attack. The choice is session-local; no user settings are written.

Focused test: launch with `POKEAETHER_CAMERA_SMOKE=1` and an absolute
`POKEAETHER_STAGE_OUTPUT`. It checks both sides, stationary HUDs, overview return,
mid-attack disable, a complete disabled attack and reset; it captures attacker
and impact views. Local evidence: `.worktrees/slot-c/.tmp/battle-stage-camera-01/`.
This does not change production battle behavior or establish mobile performance.
