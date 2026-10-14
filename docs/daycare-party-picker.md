# Daycare Party slot selection

Daycare training uses a modal with six Party positions, matching the Aethering
selection flow. The desktop layout has six cards in one row; narrower windows
use three or two columns. Cards show the slot, Pokémon art (including shinies),
name, level, selection and availability. Empty slots stay empty. Unavailable
members remain visible, with a reason, and cannot start training.

The original `pokemon` API field remains eligible-only for older clients. The
new `party` field is an advisory roster with `eligible` and `blockedReason` for
every current Party member. Both are sorted by `location.partySlot`; Pokémon
locks are still acquired by ID. Preview/confirmation remain authoritative.
Clients with older servers fall back to the eligible catalog.

Selection is preserved by Pokémon identity on refresh. Choosing another member
resets targets and invalidates the previous quote; choosing the same member or
cancelling keeps it. Slot button callbacks verify identity so a stale button
cannot choose a replacement. Busy requests and uncertain payments block opening
the picker. Keyboard Tab stays inside the modal, and Escape/cancel return focus
to the selection button. The main Daycare frame stays fixed.

## Focused checks

Through the assigned slot environment, run:

- `tests/daycare_training_check.gd`
- `tests/daycare_party_picker_check.gd`
- `tests/daycare_guide_check.gd`

The picker check covers all four languages, desktop 1280×960, 520×700,
360×640, 320×480 and landscape 640×360. For native illustrative screenshots,
run it on a graphical display with `DAYCARE_PICKER_CAPTURE=1`,
`--audio-driver Dummy` and `--rendering-method gl_compatibility`; use the slot's
own log path. Captures are saved under `res://.tmp/daycare-party-picker/` and
use no player account or backend transactions. Desktop, tablet, phone and
landscape captures were visually reviewed.

Backend focused suites: `tests.test_daycare_training` (32 tests) and
`tests.test_daycare_postgres` (36 tests), the latter through the existing
`run_daycare_postgres.sh` under `ops/worktrees/runtime-lock`. They include
out-of-order IDs, actual Party-slot gaps and disabled roster members.
No complete batch certification or authenticated gameplay transaction is part
of this change. Existing unrelated shared 3D model/asset UID warnings may appear
while the autoloads initialize.
