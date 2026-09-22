# FancifulCrow: isolated desktop arena review

Purchased source: https://fancifulcrow.itch.io/temperateforestassets
The user's original `Godot4ProjectFiles.zip` and `Assets.zip` remain untouched.
Paid art is not committed, distributed, or included in the client by these tools.
Creator permits commercial project use/modifications but not standalone asset
redistribution. Preserve the purchase and creator terms before shipping; included
Terrain3D and Asset Placer have separate license notices in their addon folders.

The actual authored forest is a **PackedScene stored as `test_world.res`**, not a
missing scene. `demo.tscn` is the asset showroom. Terrain3D 1.0.1 and Linux native
libraries are already included. No engine/plugin download is required.

## Local preparation

Extract the project ZIP into a fresh directory outside either client checkout,
excluding any cache or credentials should a later archive contain those. Current
review is `slot-c/.tmp/fancifulcrow-review-01/TemperateForestPack-main`.
Run `prepare_temperate_review.py PROJECT` from the assigned frontend. This replaces
only that review's config and explicitly packages the tracked review/material
scripts. It retains the author's wind globals and Jolt requirement, while removing
demo autoloads, editor plugins and fullscreen/input overrides. Import the review
through `ops/worktrees/slot-env slot-c -- godot --headless --editor --path PROJECT
--import` before launch. No `.godot` caches are copied.

From the client, run:

```sh
bash tools/sprite_factory/open_temperate_review.sh
```

Right-drag orbits, wheel zooms, Battle view resets, Play both plays the selected
action, Tab hides controls. No gameplay, normal settings, or real arena is changed.

## Current adaptation and limits

The authored terrain is flattened in memory at its original center height within
radius 5, blending to the surrounding hills out to 9. Grass/flowers are removed
only within one radius-6 circle centered between the fighter spawns. Terrain3D 1.0.1
uses `0.4 * size` for the removal brush radius. Grass outside the arena stays.
Only authored scene objects occupying the clearing or whose projected bounding-box
shadows overlap the fighting area are hidden. The generated Instancer container
must stay visible: hiding that origin-positioned node was the cause of all the
grass disappearing. Do not free Terrain3D-owned nodes during scene construction.
This review retains ownership and releases nodes through normal teardown.
No terrain save is performed. Original ZIPs remain the authoritative source.

The existing neutral Pokémon rig/material response is retained. The creator's
sun/sky setup is not adopted. The clearing is sunny because local shadow-casting
scenery is hidden, not because lighting or Pokémon materials were retuned. Other
trees and Pokémon retain their shadows. Shadow projection assumes this fixed
neutral sun direction; revisit the scenery selection if that rig ever changes.
This is a review adaptation, not final art direction.

A winding dirt trail runs behind the clearing (`z = -18 + 2.3*sin(0.12*x)`).
It does not connect to the arena: a broad band of tall grass separates them.
The trail uses a second in-memory terrain texture asset, reusing purchased ground
detail with a dirt tint and feathered control-map blending. Vegetation is removed
only along the narrow trail; source resources are never saved.

The preview calibrates actor elevation from posed mesh vertices over the complete
idle clip, sampled at 60 Hz after scale/facing placement. A fixed upward correction
keeps the lowest sampled point 0.025 units above the terrain directly beneath it,
without per-frame bobbing correction or species overrides. Sampling must wait for
`RenderingServer.frame_post_draw`: forcing CPU bone transforms alone left the skin
transforms read by `bake_mesh_from_current_skeleton_pose` stale. The previous
-0.163 / 0.188 Roaring Moon measurements were therefore invalid. Correct sampling
finds -1.447 clearance and applies 1.472 lift; Dragonite needs only 0.019.
This is review-only startup calibration, not a production loading strategy: bake
and cache grounding metadata in asset preparation before integration. Other action
contact/trajectory semantics and future ground-walking models need separate checks;
idle clearance does not prove every attack/faint pose is free from penetration.
The generic base review exposes an optional placement hook, otherwise unchanged.

This reuses the isolated review's double-environment HDR pass, not a production
arena architecture. Resolve its bounded terrain/occluder representation before
shipping. Native caches/resources and purchase assets remain local.

## Focused evidence

Godot 4.6.2 Forward+, RTX 3070 Laptop GPU, 1280x720 MSAA4. Final smoke run:
`slot-c/.tmp/temperate-ground-03`: four orbit captures, seven action-start checks,
height assertions for the clearing and both spawns, both viewports freed on exit.
The default view confirms tall grass around the shared circle, a separate background
trail, and the raised Roaring Moon. A second full idle sweep at half-frame offsets
remeasures final rendered geometry after correction and lighting-pass setup:
minimum clearance Dragonite 0.02501, Roaring Moon 0.02549. This is an independent
post-placement assertion, not arithmetic on the pre-placement minimum.
Route texture assertions, preparation unit tests (2), and `git diff --check` pass.
No script/runtime errors; bundled Terrain3D emits deprecation and editor-texture
warnings. See the capture directory's metrics for this run.
This short run is not a 60-FPS acceptance or first-load benchmark.

## Shadow filtering correction

The isolated Temperate review now selects directional `SOFT_HIGH` filtering and
`shadow_blur = 2/3` in both passes. Godot applies a 1.5 multiplier at High, so the
effective radius is 1 instead of the old Low/radius-2 combination. No changes to
sun direction/energy, ambient light, material endpoints, normals, texture quality,
shadow-map size or actor geometry. Cast/self shadows remain enabled. This is a
renderer-quality choice local to the separate review process, not a change to the
shared neutral-light rig or the live client quality settings.

Reference: https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-rendering-lights-and-shadows-directional-shadow-soft-shadow-filter-quality

Evidence: `slot-c/.tmp/shadow-quality-01`, identical pose/camera for baseline,
Medium/radius-1 and High/effective-radius-1, plus 120 animated frames per variant
at each of two angles. High visibly reduces the mottled shadow pattern on Roaring
Moon and cleans up ground-shadow edges. Shadows are naturally somewhat crisper.
Frame wait p95: baseline 17.165/17.223 ms, High 17.105/17.269 ms. These are short,
vsync-limited frame measurements, not isolated GPU timings or proof of zero cost.
More filtering samples do have a cost; lower-end hardware still needs validation.

Final integrated smoke: `slot-c/.tmp/temperate-shadow-fixed-02`; checks both passes
retain three neutral lights and one shadow caster with matched blur, rechecks idle
clearance, captures four moving viewpoints, starts seven actions and frees both
viewports. The existing material-response unit check also passes.
