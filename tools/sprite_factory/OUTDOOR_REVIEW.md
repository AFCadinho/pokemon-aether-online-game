# Standalone outdoor 3D review

Local, noncommercial visual study; not a production battle or overworld change.
Uses the existing Dragonite/Roaring Moon PBR GLBs with all seven source actions,
inside GDQuest's prebuilt outdoor environment. Camera uses perspective, with
360-degree orbit, limited elevation/zoom, per-Pokémon focus and overview reset.

## Third-party boundary

Source: https://github.com/gdquest-demos/godot-4-new-features
Pinned revision: `844195660246ed6b232a0e0fe7e48c94072f24ea`.
GDQuest code/scenes/shaders: MIT. Art/models/textures: CC-BY-NC-SA 4.0.
Full upstream license is downloaded alongside the assets. Do not ship these art
assets in PokeAether without appropriate separate permission or replacement.
The viewer displays attribution and the noncommercial restriction.

`prepare_outdoor_review.py` downloads only the outdoor subtree and LICENSE:
130 files, 10.84 MiB before local import caches. Git blob hashes are verified;
provenance includes SHA-256 for each downloaded file. It rejects destinations
inside the frontend and refuses existing output directories. No upstream
plugins/autoloads are installed. Sophie and script attachments are removed from
the derived scene. The original scene is retained as `.tscn.upstream`.
Absent OBJ MTL references are removed; scene materials supply the appearance.

Runtime adaptations: source SSAO/volumetric fog disabled for Compatibility;
water plane uses a simple opaque blue material instead of the original
Forward+-oriented depth shader. Trees/bushes intersecting sightlines to the
Pokémon temporarily disappear during orbit. Source baked grass transforms are
retained without executing the grass-scatter script. The original clearing is
used; ground heights come from terrain raycasts. Materials/lighting are not
claimed equivalent to either the original demo or current sprites.

## Run

From the assigned frontend, use a new absolute directory under the slot's `.tmp`:

```sh
python3 tools/sprite_factory/prepare_outdoor_review.py OUTDOOR_PROJECT
```

From the workspace root (absolute paths):

```sh
ops/worktrees/slot-env SLOT -- godot --headless --editor --import --path OUTDOOR_PROJECT
ops/worktrees/slot-env SLOT -- env POKEAETHER_3D_STAGE_REPORT=PBR_REPORT godot --path OUTDOOR_PROJECT --rendering-method gl_compatibility --script FRONTEND/tools/sprite_factory/battle_outdoor_review.gd
```

Drag with left/right mouse outside the controls to orbit; wheel to zoom.
`Battle view` or R resets the view. Species buttons focus the camera. Choose
an action and `Play both` to view it from any angle. Nonlooping actions hold
their final pose; choose idle to resume. No battle backend or save data is used.

## Verification and limitations

Godot 4.6.2 / Compatibility / Linux AMD Radeon desktop tested. Automated smoke
mode (`POKEAETHER_OUTDOOR_SMOKE=1`, `POKEAETHER_STAGE_OUTPUT=OUTPUT_DIRECTORY`)
captures four orbit angles, checks seven actions, focus, wheel zoom and
camera limits/reset. Screenshots inspected, Python compilation and UID checks
passed. Assets prepared/imported in a fresh standalone project.

Local project: `.worktrees/slot-c/.tmp/outdoor-review-02`.
Screenshots: `.worktrees/slot-c/.tmp/outdoor-capture-03`.
PBR report: `.worktrees/slot-c/.tmp/battle-stage-pbr-01/glb/report.json`.

This is not a performance benchmark or Android/web certification. The camera
does not implement full environment collision avoidance; extreme zoom/orbit can
intersect scenery, and foliage hiding may visibly pop. No production assets,
delivery format or overworld behavior changed.

## Scripted outdoor battle follow-up

The viewer now includes fixed screen-space HP panels and two demo attack
buttons. Dragonite plays its special-attack clip with a placeholder projectile;
Roaring Moon plays its physical clip. Impact triggers the defender's damage
clip, a brief ring and 18 points of local HP loss. At zero HP the defender plays
faint-start and further attacks are blocked until Reset HP. There is no move
accuracy, type calculation, turn authority, backend or source-game VFX here.

Attack camera eases to the attacker, then impact, and returns to the user's
previous framing. Toggle it off for a fixed camera. Manual drag/zoom/focus/reset
takes priority immediately and cancels later camera cues for that attack.
Free animation inspection remains available outside an active scripted attack.
Controls are guarded against reentrant attacks; transient effects are freed.

Focused runtime test: `POKEAETHER_OUTDOOR_BATTLE_SMOKE=1` with
`POKEAETHER_STAGE_OUTPUT=OUTPUT_DIRECTORY`. Checks HP, both attacks, duplicate
input guard, effect cleanup, camera return/disabled/manual takeover, faint and
reset. Local initial evidence: `.worktrees/slot-c/.tmp/outdoor-battle-01/`;
extended KO regression: `.worktrees/slot-c/.tmp/outdoor-battle-02/`.
This remains a desktop visual prototype, not a completed migration.
