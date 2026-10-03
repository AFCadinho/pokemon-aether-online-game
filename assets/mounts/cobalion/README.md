# Cobalion mount

Built from the supplied four-direction sprite sheet in `source.png`, preserving
its original pixels at 1× and the game's original 64×64 player riding frames.
The 224×224 frames place the unchanged source pixels 16 pixels lower to align
the mount with the player's world position. The complete front-facing Cobalion
sprite is layered over the rider so its head stays visible. Rider masks match
the foreground's opaque pixels in every frame: the player's head remains visible
above and between the horns wherever Cobalion does not actually cover it.
Side frames follow the source's two-pixel animation bob.

Rebuild with `python tools/build_cobalion_mount.py` (Pillow required).
`icon.png` uses the unpadded front cell.

Grant `cobalion-mount` through the existing administration reward controls,
then select Cobalion in the land mount slot. Ownership and a regional Mount
License are required.
