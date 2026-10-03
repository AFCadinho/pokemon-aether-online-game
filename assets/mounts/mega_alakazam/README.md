# Mega Alakazam levitation mount

Based on the supplied source sheet and approved seated levitation concept.
`icon.png` uses the original 64×64 front cell for Bag and mount selection icons,
so the large transparent riding canvas does not shrink the creature in menus.
Alakazam uses the original 32 logical pixels (64 physical pixels), with no
fractional scaling or uneven pixel blocks. The player's exact 64×64 ride assets are retained.
The player's normal foot origin anchors every direction. Alakazam, the psychic wisps
and rear mask are positioned around that origin, bringing the creature closer
in the front/side views and retaining the lower rear head position. Only the hover and
small vertical animation bob lift the rider; turning never shifts them sideways.

`source.png` is the user-supplied 512×256 sheet. Only the first four columns
are used. `tools/build_mega_alakazam_mount.py` reproduces the three 896×896
runtime sheets, with four directions and four 224×224 frames per direction.
Pillow is required. The source's exact 2× grid is reduced losslessly and restored
at export, preserving every creature pixel at its original size.

Thin, broken translucent psychic arcs replace the solid purple ring. The side
views bring Alakazam 16 physical pixels closer to the player, and the front
view brings them 6 pixels closer. The approved rear height is retained.
The psychic effect is baked into the mount, not the rider. The player retains
their own 64×64 ride assets, clothing, hair and skin. A dedicated rear
foreground sheet and matching binary rider mask keep the creature's full
head/body ahead of the rider and the floating spoons behind them. Each whole
directional layout uses the player's normal foot anchor.

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
