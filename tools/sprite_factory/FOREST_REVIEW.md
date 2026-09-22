# Commercially usable forest: isolated desktop review

Source: https://github.com/Scaryrocker8/godot-stylized-forest
Pinned revision: `e2b6b26b9efb65615071ca3b7b4e4cd573af74b7`.
Scene/art: Jonnie Gieringer, MIT. Leaf shader: Emerson Rowland, CC0 header.
External rocks: Michael Hooper, CC BY 4.0:
https://sketchfab.com/3d-models/low-poly-rocks-9823ec262054408dbe26f6ddb9c0406e
TerraBrush: spimort, MIT. Retain all notices and identify modifications when shipping.
Audio, first-person player/plugin, easter egg, upstream scripts and Blend sources
are excluded. No GDQuest noncommercial art is used by this review.

## Preparation and opening

From the assigned frontend:

```sh
python tools/sprite_factory/prepare_forest_review.py /absolute/path/to/new-review-directory
```

Run Godot's headless editor import in that new project through the assigned slot
environment. The first scan can report TerraBrush's brush texture before it is
imported; subsequent runtime uses the imported file. The project uses its own
cache and carries no enabled editor plugins or autoloads. The native Linux x86_64
TerraBrush dependency is downloaded at the pinned forest revision; no extension
is installed into the frontend. Other desktop builds are not prepared here.

Current local review: slot-c `.tmp/forest-review-01`. To open from the normal
frontend (or assigned frontend):

```sh
bash tools/sprite_factory/open_forest_review.sh
```

Right-drag orbits, wheel zooms, **Battle view** resets, **Play both** plays the
selected source action, and **Tab** hides the temporary controls. This is a full
window 3D preview, not a redesigned battle HUD or connected authoritative battle.

## Adaptation boundary

The existing authored forest terrain/placement masks are retained. A circular
clearing is cut into in-memory object/foliage masks around the source spawn;
terrain height/color and downloaded source images are not saved over. Ground
positions are raycast, rather than species-specific height tweaks.

The locked neutral rig and approved generic Pokémon material response are reused.
Source environment lighting, fog and effects are not adopted, so the scene does
not reproduce the upstream promotional screenshot. In particular, the source
leaf material is bright under the neutral rig; scenery material calibration is
not a reason to retune Pokémon/global lighting.

TerraBrush's internal Terrain node cannot be duplicated. The review-only response
adapter instantiates a second authored terrain for the irradiance pass instead.
This avoids changing the production presenter but incurs extra terrain work.
Before integration, choose a static prepared arena/render-occluder representation
and measure it. Do not ship the entire demo or this double-terrain setup blindly.

## Focused evidence

Godot 4.6.2 / Forward+ / RTX 3070 Laptop GPU / 1280×720, MSAA4.
`POKEAETHER_FOREST_SMOKE=1` plus `POKEAETHER_STAGE_OUTPUT` captures four orbit
angles and checks all seven source actions and an active material response pass.
The final clearing/framing run measured p95 19.740 ms,
max 307.671 ms across abrupt camera changes, and ~655 MiB video memory. This is
not a steady-state GPU benchmark or a 60-FPS acceptance pass. Screenshots are in
slot-c `.tmp/forest-capture-03`, including `metrics.json`. Both render viewports
were verified freed after teardown. One initially occluded orbit angle was
corrected by widening the clearing; the source's random tree scale/jitter needs
more margin than a first-person clearing. Zoom is bounded to 8–18 units.

Remaining: visible scenery review, startup/turning stalls, performance of a bounded
arena, higher-resolution testing, and camera/environment collision handling.
Only then proceed to the proposed full-screen battlefield HUD. No normal battle
scene, settings, Pokémon materials, backend, or overworld lifecycle is changed.
