# V1 shape validation, local review batch

All five builds below are `needs_review`. They are available only through the
explicit local preview catalog at `.worktrees/slot-c/.tmp/sprite-factory-shapes/preview.json`.
No normal or shiny variant was approved. The 512×512 RGBA, 24 FPS baseline and
existing Dragonite/Rattata/Dratini assets were unchanged.

## Source choice and limitations

The local `/home/adinho/MEGA downloads/Gen1` folder contains 126 Blender files.
It has Machamp and Onix base files, but no base Pidgeot, Gastly, or Venusaur.
Pidgeot Mega is present, but was not passed off as the base form. Articuno tests
large flying wings; Abra tests a hovering body; Parasect tests a broad, low body.
This does **not** certify Gastly's gas transparency or Venusaur's flower/leaves.
Weezing and Ivysaur were inspected as closer alternatives, but have missing
connected eye-texture nodes. The source gate correctly refused to build them.

Each source was inspected in Blender 5.2.0 LTS with auto-execution disabled.
All selected files have one armature, packed/available textures, no detected
shiny material candidate, and stored embedded text that was never run. Exact
source hashes, rig names, actions, camera settings and accepted inspection
warnings are in the five manifests. Action mappings were chosen after viewing
512px front/back key-pose surveys. The full action renders then received per-frame
geometry and pixel QC. Action semantics, loop seams, material appearance and
platform placement still need human review.

## Selected actions and presentation

| Species | Idle | Physical | Special | Damage | Sleep | Faint | Camera ortho front/back | Display render scale front/back | Ground policy |
|---|---|---|---|---|---|---|---:|---:|---|
| Articuno | battlewait01_loop | attack02 | rangeattack01 | damage01 | sleep01_loop | legacy fallback | 5.8 / 5.8 | 2.3 / 2.3 | floating |
| Machamp | ba10_waitA01 | ba20_buturi01 | ba21_tokusyu01 | ba30_damageS01 | fallback | ba41_down01 + final pose | 3.2 / 3.2 | 2.7 / 2.7 | grounded |
| Abra | ba10_waitA01 | fallback | ba21_tokusyu01 | ba30_damageS01 | fallback | ba41_down01 + final pose | 1.9 / 1.9 | 4.2 / 4.2 | floating |
| Onix | ba10_waitA01 | ba20_buturi01 | ba21_tokusyu01 | ba30_damageS01 | fallback | ba41_down01 + final pose | 8.5 / 8.5 | 1.8 / 2.0 | grounded |
| Parasect | ba10_waitA01 | ba20_buturi01 | ba21_tokusyu01 | ba30_damageS01 | kw20_drowseB01 | ba41_down01 + final pose | 2.3 / 2.3 | 4.0 / 4.0 | grounded |

The table uses action suffixes; manifests contain exact full Blender names,
ordered source frames, source FPS, speed and loop flags. Articuno's source is
24 FPS; the other four are 25 FPS, sampled at 24 FPS without dropping render
quality. Attacks play at 3× source cadence, damage at 2×, and Articuno idle at
1.3×. Other idle/sleep clips play at 1×. These are initial gameplay timings for
human review, not approved artistic decisions.

Camera positions are `(3,-7,target_z+2)` front and `(-3,7,target_z+2)` back.
Targets are Articuno `.75`, Machamp `.8`, Abra `.5`, Onix `2.45`, Parasect `.5`
world units high. The floating/grounded label is explicit manifest metadata;
the runtime currently applies the data-driven 2D `position_offset`, while
`ground_point` is retained for future tooling. Abra and Articuno use elevated
offsets, not a species branch in Godot. Onix needed separate front/back offsets
and back display scale after a battle-scene comparison.

## Full-size output and automatic checks

| Species | Frames front+back | Canonical masters | Runtime PNG atlases | Review previews | Minimum alpha margin | QC warnings |
|---|---:|---:|---:|---:|---:|---|
| Articuno | 1,336 | 219.58 MiB | 73.83 MiB | 29.63 MiB | 24 px | 4 duplicate idle/sleep endpoints |
| Machamp | 418 | 74.39 MiB | 30.39 MiB | 13.14 MiB | 20 px | none |
| Abra | 426 | 75.03 MiB | 29.11 MiB | 13.66 MiB | 46 px | 2 duplicate idle endpoints |
| Onix | 542 | 85.90 MiB | 30.24 MiB | 9.64 MiB | 65 px | 2 duplicate idle endpoints |
| Parasect | 574 | 104.55 MiB | 44.34 MiB | 22.29 MiB | 51 px | 4 duplicate idle/sleep endpoints |

All final builds have zero technical errors and no clipped frames. Every atlas
cell was verified pixel-exact against its canonical master. Maximum atlas page
size is 4096×4096; Machamp's tallest page is 4096×3584. The master sizes above
exclude separately preserved raw Blender PNGs, interrupted attempts and
independent reference builds. No frame, FPS, render setting or texture quality
was reduced.

An early Articuno `attack01` render clipped in 24 frames despite acceptable
three-pose samples. Full-action bounds showed a front-camera peak of 3.866 world
units. Visually suitable `attack02` peaks at 2.619, so the final fixed camera
uses ortho 5.8 and `attack02`. Its tightest visible margin is 24 px. Articuno's
`down` action ends in a flying pose, so faint remains the legacy tween.

Onix's first back presentation visually crossed below its platform and exceeded
the configured height review limit. The final manifest uses a 2.0 back display
scale and corrected front/back offsets. The final battle-scene screenshots show
its lower body on the platforms, with the head clear of the HP UI. Onix remains
substantially larger than the small reference Pokémon.

During in-game review Articuno appeared too high above both platforms. A
follow-up presentation-only correction moves its front view 25 px and back view
10 px lower. The manifest and full build were regenerated at the same quality;
the former build remains available for comparison. Battle-scene composition
checks show the corrected front view hovering just above the opponent platform
and the back view's tail meeting the player platform. This remains subject to
the player's visual approval.

Parasect's complete 574-frame render survived an interruption during WebP
preview generation. Canonical and raw PNGs were verified frame-by-frame, the
partial previews were archived, and postprocessing/atlas verification was
completed without rerendering. V1 does not yet offer a built-in resume command;
that is a quality-preserving operational improvement to consider before bulk
work, not a reason to reduce render quality.

## Local battle composition, fallback and cost

The existing generic resolver loaded all ten new front/back idles in the actual
battle scene using the PvP stadium, platforms and current UI. Composition PNGs
are in the temporary batch output. Focused Godot checks exercised all five
species, absent shiny/forms, missing physical/sleep/faint actions, the V1
Dragonite/Rattata routing and ordinary fallback. Dratini router/VFX regression
and six factory unit tests passed. This is not yet a server-backed gameplay
session or a human aesthetic approval.

One headless Godot run measured first idle loads at 88–175 ms per view and cached
lookups at about 0.3–0.5 ms. This is a local measurement, not a release latency
guarantee. Approximate decoded RGBA8 idle atlas capacity per view is 88 MiB
Articuno, 40 MiB Machamp, 80 MiB Abra, 64 MiB Onix and 64 MiB Parasect. Full
GPU/driver memory use was not reliably measured. Existing lazy action loading
limits startup work, but loaded actions remain cached for the process lifetime.
Later work can add asynchronous prefetch, action unloading or cache budgets while
retaining all 512px frames and 24 FPS timing.

The V1 layout, source gate, lossless master/atlas separation, exact identity keys
and fallback generalized without code changes. Per-species cameras, lighting,
scale, action selection and platform offsets required human decisions. The
first full-action Articuno render demonstrates why sparse pose checks cannot
replace full bounds QC. Missing eye textures, a convincing Articuno faint and
Onix placement were the main blockers or corrections. Remaining open categories:
a true gas/transparent body and a large low plant with flower/leaves. These and
an approved shiny source should precede any bulk rendering.
