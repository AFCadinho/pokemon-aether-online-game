# Adventure Party shared doubles HUD in immersive 2D and 3D — 2026-10-07

The initial team-status implementation passed the existing headless HP-layout
fixture but did not verify its draw order against an active 3D viewport. A new
OpenGL fixture using the real 3D arena, camera and native battle UI reproduced
an actual visibility issue: the VS/team header, turn display and reset-camera
button were at z=0, behind the battlefield viewport at z=1. The HP HUDs were
already above the viewport at z=40.

The top controls now draw at z=60. The co-op header also uses its current
minimum size, so it can grow with pixel-sized typography on smaller windows and
shrink again when the window grows. If it intersects the corner portraits,
field conditions, turn label or camera button, it moves to a clear row below
those controls. The four HP HUDs reserve a minimum 12 stage-space units below
the header. Their ordinary top remains 84 when that already leaves enough
space. Team order, battle logic, timers and animation duration do not change.

Immersive 2D doubles now uses the same four HP cards and fixed row as 3D,
with allied p1/p3 on the left and opposing p2/p4 on the right. Cards retain
their owners, combatant metadata and animated HP values from the existing
source panels. Stat overlays follow the visible cards, including after a
state update. Switching modes reuses the cards; absent source rows hide them
instead of showing stale HP. Sprite/model positions and animation anchors
stay with their existing presenters. The shared cards use the same 14-pixel
base typography as existing HP panels. Stat-change and ability-effect labels
use a compact 12-pixel base in doubles, including 3D, and still follow the
player's text-size setting. The screenshot fixture includes both a boost and
a drop. Single battles retain their layout and typography.

## Validation

`tests/coop_immersive_team_layout_check.gd` exercises the real battle scene and
3D arena with four local procedural actors, then switches to 2D. It checks
draw order and rectangle clearance for the team status, four HP cards, three Trainer portraits, weather,
terrain, turn and camera reset. It tests English, Dutch, Brazilian Portuguese
and Simplified Chinese at five logical host sizes (960x540, 1024x768, 1280x720,
1600x900, 1920x1080), including a four-Trainer status fixture. The largest
supported text setting (150%) is also checked on a small host in both modes.
It verifies identical HP positions and node reuse across modes, HP animation
values, stat-overlay placement and hiding a removed source row. The typography
scan runs explicitly so a fast headless runner cannot miss its delayed font
resizing. Failures exit nonzero instead of continuing after nested assertions.

Both the headless layout check and the OpenGL screenshot run pass; minimum
observed header-to-HP clearance is 12 stage-space units. Existing co-op status,
3D doubles HUD, single/double immersive layout and PvP timer checks provide
regression coverage. Existing immersive-layout checks retain their shutdown
ObjectDB warnings. The broad gameplay check passes its behavior assertions
and exits 0, but retains its previously reproduced headless skeleton/material
errors and five resources still in use at shutdown; this task does not repair
that lifecycle. The co-op presentation check exits 0 without errors.

The local browser gallery includes matching 2D/3D screenshots, waiting and
choosing states, four-Trainer status and Chinese examples.
The capsules are layout test actors, not downloaded Pokemon models. This
verifies the actual UI/viewport composition, not a live battle with two clients,
model-specific poses or production networking. A new gameclient release is
needed; no backend change is involved.
