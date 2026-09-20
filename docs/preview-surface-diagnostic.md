# Preview surface artifact investigation

The reported moving tile-like pattern is not yet reproduced conclusively.
Do not treat this diagnostic as an artifact fix or change distribution format
based on it. Sprite resolution, frame rate and playback are unchanged.

In a local debug build, open Summary or Pokédex and press F8:

1. Flat background with the original animated sprite.
2. A stationary 16-logical-pixel grid with the original animated sprite.
3. Grid only, covering the sprite and preview badges as well.
4. Original presentation again. Shift+F8 also restores it immediately.

The key affects visible previews; hidden cards do not change mode. Closing a
card discards its diagnostic state. Release builds do not attach the control.
The output reports logical size, screen transform and window size, without
Pokémon/player data. Test the same view at the usual window size and maximized.

Interpretation:

- Artifacts remaining in grid-only mode rule out sprite textures, atlas cells
  and animated sprite playback as their direct source. Investigate final UI
  scaling, window presentation and display capture next.
- Only the scenic background being affected points to that image's filtering
  or source, rather than animated sprite compression.
- Only the moving sprite being affected requires further frame/render-path
  comparison. A clean stationary grid alone does not prove a sprite fault:
  display artifacts can depend on motion.
- Unequal grid-line widths at fractional screen scales can be ordinary pixel
  resampling; distinguish that static effect from the reported moving tiles.

Previous controlled checks found identical pixels between all 91 Dragonite
idle master frames and their PNG atlas cells. Correct premultiplied-alpha
composition removed a measurable edge error, but did not resolve the user's
reported symptom. Fixed-size offscreen comparisons cannot rule out a problem
in final window scaling or presentation.
