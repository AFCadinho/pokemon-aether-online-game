# Pallet atlas — block 3 verification status

Status: native rendered comparison and candidate export ready; live browser
map-transition, memory and battle-latency checks remain pending. This document
does not certify block 3 complete or authorize importer rollout.

## Native rendered check

`tests/pallet_compact_render_check.gd` creates two independent 1600 × 1280
SubViewports with the original and compact generated visuals. It uses a real
X11/OpenGL compatibility renderer, waits for completed draws, and compares the
entire returned pixel buffers. It rejects blank/solid output and refuses a
headless display driver. Result: both nonblank images are pixel-identical.
The saved compact image was also visually inspected.

Run from slot-C frontend on a working display:

```sh
/home/adinho/Desktop/pokemonaetheronline/game/ops/worktrees/slot-env slot-c -- \
  godot --path . --rendering-method gl_compatibility --position 2500,1400 \
  --resolution 64x64 --script tests/pallet_compact_render_check.gd
```

The comparison covers actual atlas sampling, transform rendering, layer order
and tile padding at 1× over the whole generated visual. It is native rendering
evidence, not an exported desktop login/gameplay run, door movement test or a
browser GPU/latency measurement. Source-property/door-piece regressions from
block 2 remain relevant; rendered gameplay/movement checks are still required.

Ignored artifacts in this slot: `builds/pallet-native-render/original.png` and
`compact.png`. The environment reported an NVIDIA GL initialization fallback
before successfully rendering through the AMD OpenGL device; that warning does
not invalidate the nonblank pixel-buffer comparison. Existing editor launcher
and Unown case-UID warnings remain visible.

The older `pallet_town_visual_integrity_check.gd` also passes, but explicitly
loads the retained original visual. Do not mistake that check for validation of
the new candidate; the compact pixel/property and native render checks load both.

## Clean browser candidate export

Candidate source: `92bebb9e783f10a8156604e1a866aaed5f901db8`, dirty=false,
Godot 4.6.2. PCK SHA-256:
`c43306f34ffa1128fc4808e612d47ecef5d24612cede293552fbc8364eab02de`.
Initial files total approximately 261.766 MiB before HTTP compression.
Read-only PCK inventory confirms all seven compact portable Pallet textures are
present. The thirteen retained original Pallet textures are also still packed.
This is residency optimization, not evidence of a smaller initial download.

Candidate served from the task's existing loopback preview on port 8062; the
user's normal 8061 preview was not rebuilt or replaced. No backend interruption,
authentication, production access or full paired verification occurred in this
preparation step.

## Remaining acceptance

- Approved disposable local runtime for real login, Pallet movement/doors,
  map transitions and three resolved battle/teardown cycles.
- Audit-on check: old unused Pallet atlases must not remain cached solely due
  to candidate references; compact resources must be loaded and memory stable.
- Separate audit-off, comparable control/candidate latency evidence; do not
  use extra texture inspection during timing comparisons.
- Confirm collision/depth behavior and distinguish native render comparison
  from full desktop gameplay evidence.
- Restore the normal Compose stack/database after each runtime; inspect health.
- Record exact builds/results and decide whether block 4 is justified.
