# Mega Alakazam levitation mount

Based on the supplied source sheet and approved V5 composition. The rear rider
is 22 logical pixels lower than V5, including the last requested adjustment.
The front and side compositions retain V5's relative positions and layering.

`source.png` is the user-supplied 512×256 sheet. Only the first four columns
are used. `tools/build_mega_alakazam_mount.py` reproduces the three 896×896
runtime sheets, with four directions and four 224×224 frames per direction.
Pillow is required. Nearest-neighbor scaling preserves the pixel grid.

The psychic ring is baked into the mount, not the rider. The player retains
their own 64×64 ride assets, clothing, hair and skin. A dedicated rear
foreground sheet and matching binary rider mask keep the creature's full
head/body ahead of the rider and the floating spoons behind them. Each whole
directional layout is shifted to a common ground anchor. These shifts preserve
the approved creature/rider spacing.

To try without logging in, open `tools/mega_alakazam_mount_demo.tscn` in Godot
and run the scene (F6). Move/turn with WASD or arrow keys, toggle animation
with Space, and switch male/female defaults with G. This offline scene reuses
the actual avatar renderer; it is not a map collision test.

For regular gameplay, grant `mega-alakazam-mount` through the existing admin
reward controls and select Mega Alakazam in the land mount slot. The permanent
item requires ownership and the usual regional Mount License. Levitation
retains ordinary land routes and collision rules.

Focused checks: `tests/mega_alakazam_mount_check.gd`, the existing Rayquaza and
Shadow Lugia checks, and backend `tests.test_mega_alakazam_mount`.
