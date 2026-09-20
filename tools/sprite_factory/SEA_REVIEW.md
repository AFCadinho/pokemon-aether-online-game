# Original sea arena study

Standalone coastal preview, not a production battle replacement. Original
procedural sandbar, animated opaque ocean shader and distant rocky coastline.
No purchased environment assets or texture downloads. Existing prepared local
Dragonite/Roaring Moon catalog required, with its existing distribution constraints.

```sh
python tools/sprite_factory/prepare_sea_review.py ../.worktrees/slot-c/.tmp/sea-review-01
bash tools/sprite_factory/open_sea_review.sh
```

Right-drag to orbit, wheel to zoom, Tab to hide UI, Play both to test actions.
The flat radius-8 center stays above water. Inherited full-idle posed grounding
uses y=0; this is a coastal sandbar, not swimming or open-ocean battle semantics.
The procedural water is opaque with shallow color and moving foam/ripples;
it does not implement refraction, underwater views or physics. Camera movement
is restricted to the existing above-surface review controls.

Pokémon retain neutral direct/ambient lighting, material response and High shadow
filtering. Sky is background only, with sky reflections disabled. Cave and forest
previews are untouched. Cave geometry helpers are reused without building a cave.

Preparation packages allowlisted source/shader files, not caches or userdata.
Run `python tools/sprite_factory/test_prepare_sea_review.py` for preparation checks.
The existing review smoke checks both lighting passes, idle ground clearance,
four camera angles, seven action starts and viewport cleanup. Visual acceptance
and eventual production integration remain separate steps.

Local smoke evidence (2026-09-20): slot-c/.tmp/sea-run-03.log and
sea-capture-03/. Seven action starts and cleanup passed; measured full-idle
clearance was 0.0250/0.0255. Sampled p95 frame time 17.283 ms on RTX 3070 Laptop,
not a production performance certification. Four orbit captures generated.
Preparation tests: three passed; launcher shell syntax passed.

Environment reflection setting follows the [Godot 4.6 Environment API](https://docs.godotengine.org/en/4.6/classes/class_environment.html#enum-environment-reflectionsource).
