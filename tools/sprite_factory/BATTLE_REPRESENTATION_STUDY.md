# Compact sprites versus runtime 3D — first feasibility study

Date: 2026-09-20. Local research only. Production catalogs, game scenes and
renderer defaults are unchanged. This is not a decision to migrate the game.

## Finding

Runtime 3D is worth a focused visual-quality and device-validation follow-up.
Four normal Pokémon with all seven battle actions total **13.91 MiB** in this
experimental GLB representation, versus **102.04 MiB** of current sprite atlas
pages. That is 7.33× smaller for these particular assets. One model serves front,
back and zoomed views, so it can also serve Pokédex and Summary without another
image sequence.

This is **not equal-quality compression**: the successful prototype translates
base color/mask/eyelid shading into albedo textures and uses simplified PBR
lighting. Original normal maps, variable roughness, alpha, emission, toon/rim
behavior and source lighting are not fully translated. Size and speed must be
remeasured after restoring the desired appearance. No claim about the complete
normal/shiny catalog follows from these four normal variants.

## Comparable storage scope

All sprite profiles contain every source frame, both views and all seven
actions. Native 60-FPS timing is retained. The 256 profile is an explicitly
lossy experiment authorized for this investigation. Source masters stay 512.
GLB contains one skinned model and all seven sampled skeletal animations.

| Pokémon | Current 512 Q95 sprites | 512 Q70 sprites | 256 Q75 sprites | Experimental 3D |
|---|---:|---:|---:|---:|
| Dragonite | 23.74 MiB | 13.50 MiB | 7.92 MiB | 2.19 MiB |
| Roaring Moon | 33.33 MiB | 19.17 MiB | 10.77 MiB | 6.21 MiB |
| Jigglypuff | 19.66 MiB | 9.42 MiB | 6.28 MiB | 1.62 MiB |
| Diglett | 25.31 MiB | 8.90 MiB | 5.13 MiB | 3.89 MiB |
| **Total** | **102.04 MiB** | **50.99 MiB** | **30.10 MiB** | **13.91 MiB** |

These are raw stored atlas/GLB bytes, not exported application sizes or measured
HTTP transfer sizes. Sprite still previews/metadata are excluded, as in the
preceding full-action benchmark. GLBs already embed geometry, skin, animation,
textures and material metadata. No wire compression or texture compression
extension is used. GPU texture storage differs from these PNG-compressed GLBs.

Lowering WebP quality alone can save roughly half the sprite disk space in this
sample. The moving review, especially eyes, edges and zoom, must determine
whether the degradation is acceptable. Neither compact profile is approved.
The shader differences make a scalar PSNR ranking of 3D versus sprites
misleading; no visual-equivalence score is claimed.

## 3D runtime evidence

Godot 4.6.2, Compatibility/OpenGL, integrated AMD Radeon Graphics (Renoir),
Mesa 26.2.2 on Linux. Actual GPU rendering, not headless. Each instance is in
an independent 512×512 SubViewport with 4× MSAA, two shadowless directional
lights and ambient illumination. No battle environment, effects, UI or game
logic is included. There are two- and four-instance cases for each species.

After 30 warmup frames, every case recorded 180 frames with a 60-FPS cap and
VSync disabled. Across all eight cases, p95 was 16.69–16.71 ms and no measured
frame exceeded 20 ms. The capped frame interval is not a measurement of GPU
render time or spare performance capacity. This is a short desktop smoke
benchmark, not mobile/web or full-battle certification.

| Pokémon | Runtime GLB parse | Instantiate two / four | First draw, two / four | Engine video-memory counter, two / four |
|---|---:|---:|---:|---:|
| Dragonite | 50.1 ms | 19.5 / 29.0 ms | 10.4 / 3.3 ms | 56.7 / 89.1 MiB |
| Roaring Moon | 85.3 ms | 43.3 / 71.5 ms | 9.4 / 6.3 ms | 73.4 / 97.9 MiB |
| Jigglypuff | 25.3 ms | 7.5 / 12.4 ms | 8.6 / 2.5 ms | 68.8 / 88.9 MiB |
| Diglett | 67.4 ms | 4.9 / 7.8 ms | 6.5 / 12.5 ms | 80.2 / 100.3 MiB |

The video-memory counter is whole-process and includes viewport buffers and
renderer resources. It is not isolated per-model VRAM or total system RAM.
Static allocation deltas during instance creation ranged from 1.8–21.4 MiB;
they exclude parsing allocations and do not represent peak process RSS.
Runtime GLB parsing is used for the probe; a shipping pre-imported resource
could have different loading behavior. Preloading remains necessary.

Meshes contain 2,443–11,722 triangles and 27–142 bones. All seven expected
animations import for every Pokémon. Seeking to the middle of each action
changes the bone pose; the standalone review loads all **56 species/action/view
combinations** successfully. That verifies presence, loading and motion, not
pixel-perfect skeletal equivalence at every source frame.

glTF clip duration ends at the final sampled key, while sprite timing holds
each frame for 1/60 second. The comparison player uses the source count/60
duration and holds the final skeletal pose for the remaining frame interval.
The raw runtime smoke loop uses the GLB duration; its reported duration is not
an approved game action-timing contract.

## Material translation

A direct Blender glTF export produced purple bodies and mask-colored eyes:
the custom source shader does not export correctly through a generic PBR
exporter. Its original GLBs are preserved as rejected evidence.

The working probe extracts the existing color/layer-mask/eyelid chain from the
reviewed imported shader. It removes that chain's Eevee-dependent lighting
input, bakes it on a full UV plane and connects the texture to a plain PBR
material. Baking on model geometry left missing/black regions in early probes;
the UV-plane version produces complete color coverage in the inspected views.
Albedo textures retain the largest source material texture dimension (256 or
1024 in this sample). No source blend file is modified or saved.

Inspection of final front screenshots confirms recognizable body colors and
open visible eyes on these four samples. Appearance is flatter than the source
sprites, and edge/detail and back-view quality still require human approval.
The graph adapter is intentionally specific to the pinned importer shader and
rejects missing expected nodes; it is not a generic production material importer.

## 2D world with 3D battles

A 2D overworld can coexist with a 3D battle scene and a 2D HUD. The probe already
renders 3D SubViewports beside 2D UI and sprites. Godot documents this viewport
composition in [Using a SubViewport as a texture](https://docs.godotengine.org/en/4.6/tutorials/shaders/using_viewport_as_texture.html).
Overworld conversion is not needed to investigate the battle renderer.

Compatibility is the starting renderer because it targets older desktop/mobile
hardware and is the available renderer for Godot web exports. Actual devices
still need tests; [Godot's renderer overview](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html)
describes support, not the performance of this game.

Recommended next gate: match materials and lighting for one approved battle
view, put two Pokémon plus the intended stage/effects in one actual battle
viewport, then measure a representative Android device and exported browser
build. Preserve the four-species review for geometry/eye regressions. Only
after that gate should a catalog migration or full renderer integration be
considered. Shiny material sharing is a promising follow-up, not measured here.

## Reproduction and moving review

From an assigned frontend worktree, generate explicit export jobs:

```sh
python3 tools/sprite_factory/prepare_battle_3d_probe.py SOURCE_CATALOG SOURCE_ROOT PROBE_DIRECTORY --bake-colors
flatpak run org.blender.Blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python ABSOLUTE_FRONTEND/tools/sprite_factory/battle_3d_export_probe.py -- PROBE_DIRECTORY/export-job.json
python3 tools/sprite_factory/compact_battle_sprite_probe.py PACKAGED_CATALOG SOURCE_CATALOG COMPACT_DIRECTORY
python3 tools/sprite_factory/prepare_representation_review.py PACKAGED_CATALOG COMPACT_DIRECTORY PROBE_DIRECTORY/glb/report.json PROBE_DIRECTORY/review.json
```

Use absolute paths with Flatpak. From the workspace root:

```sh
ops/worktrees/slot-env SLOT -- env POKEAETHER_3D_PROBE_REPORT=PROBE_DIRECTORY/glb/report.json godot --path FRONTEND_WORKTREE --rendering-method gl_compatibility --script res://tools/sprite_factory/battle_3d_runtime_probe.gd
ops/worktrees/slot-env SLOT -- env POKEAETHER_REPRESENTATION_REVIEW=PROBE_DIRECTORY/review.json godot --path FRONTEND_WORKTREE --rendering-method gl_compatibility --script res://tools/sprite_factory/battle_representation_review.gd
```

The comparison offers species, action, front/back and 1×/2× zoom. Columns are
current Q95, 512 Q70, 256 Q75 and experimental 3D. It synchronizes source timing
and uses the source cameras, but is not a reproduction of every game UI layout.
It intentionally reloads assets synchronously on selection for review only.
Set `POKEAETHER_REVIEW_SMOKE=1` for the 56-case load check, or
`POKEAETHER_REVIEW_CAPTURE=ABSOLUTE_PNG_PATH` for a screenshot and automatic exit.

Local evidence:

- `.worktrees/slot-c/.tmp/battle-representation-01/compact/report.json`
- `.worktrees/slot-c/.tmp/battle-representation-baked-04/glb/report.json`
- `.worktrees/slot-c/.tmp/battle-representation-baked-04/glb/godot-3d-runtime.json`
- `.worktrees/slot-c/.tmp/battle-representation-baked-04/glb/*-front.png` and `*-back.png`
- `.worktrees/slot-c/.tmp/battle-representation-baked-04/review.json`

Validation: Python compilation; SHA-pinned Blender source verification; exact
exported-action-name checks; compact-page alpha equality after resize; real GPU
runtime and bone-pose checks; 56-case moving-review load test; visual screenshot
inspection. No full project gate, Android/web certification or production change.
