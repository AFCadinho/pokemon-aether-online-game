# Shadow Lugia foreground layers

`tools/build_shadow_lugia_layers.py` extracts normal and shiny foreground sheets
from their existing mount atlases without changing the source pixels or palette.
The complete front-facing head, including its narrow tip, is drawn above the
rider as one continuous silhouette. The nearby tail remains behind the rider.
Side views extract the near wing and shoulder independently for the raised and
lowered poses; the raised pose is also the idle frame. The right-facing selection
mirrors the left-facing selection, matching the source art exactly.

Masks follow the foreground alpha and preserve the small existing far-leg
occlusion. All four frames and both variants retain their original size, rider
offsets and hovering behavior. Run `tests/shadow_lugia_mount_check.gd` in Godot
for head continuity, wing depth, idle frames and actual rider-layer checks.
