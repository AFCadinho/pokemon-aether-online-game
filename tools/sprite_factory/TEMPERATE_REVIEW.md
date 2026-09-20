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

The authored terrain is flattened in memory within radius 12 with a blend to the
surrounding hills out to 19. Vegetation instances are cleared around that area;
nearby authored objects are hidden with a canopy margin. Do not free nested object
instances before Terrain3D enters the tree: the shipped extension crashed in that
case. This review retains ownership and releases them through normal teardown.
No terrain save is performed. Original ZIPs remain the authoritative source.

The existing neutral Pokémon rig/material response is retained. The creator's
sun/sky setup is not adopted. Trees still cast environmental shadows, so the
clearing currently looks shaded and needs user review; do not promise the source
demo's presentation. This is a first functional clearing, not final art direction.

This reuses the isolated review's double-environment HDR pass, not a production
arena architecture. Resolve its bounded terrain/occluder representation before
shipping. Native caches/resources and purchase assets remain local.

## Focused evidence

Godot 4.6.2 Forward+, RTX 3070 Laptop GPU, 1280x720 MSAA4. Final smoke run:
`slot-c/.tmp/temperate-capture-02`: four orbit captures, seven action-start checks,
height assertions for the clearing and both spawns, both viewports freed on exit.
No script/runtime errors; bundled Terrain3D emits deprecation and editor-texture
warnings. p95 17.133 ms, max 23.572 ms, reported video memory 573,286,128 bytes.
This short run is not a 60-FPS acceptance or first-load benchmark.
