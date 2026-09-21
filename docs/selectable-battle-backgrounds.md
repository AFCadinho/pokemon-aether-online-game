# Selectable 2D battle backgrounds

Sprite battles keep their background choice separate from the battle UI and
Pokémon presentation. Players can choose the original 2D art, a fixed-camera
loop rendered from the matching 3D arena, or automatic selection. Environment
profiles without a rendered loop always fall back to their original assets.

The PvP stadium is the first rendered-arena profile. Its committed loop is
1152×648 at 24 fps and uses a six-second forward render followed by the same
frames in reverse, producing a seamless twelve-second loop. It remains below
the two MiB browser asset budget.

To regenerate the source AVI, run Godot with the task slot environment:

```sh
ops/worktrees/slot-env SLOT -- godot \
  --path .worktrees/SLOT/frontend \
  --fixed-fps 24 \
  --write-movie /absolute/path/stadium-source.avi \
  --quit-after 144 \
  --script res://tools/sprite_factory/render_stadium_background.gd
```

Encode and scale the forward/reverse loop with FFmpeg:

```sh
ffmpeg -i stadium-source.avi \
  -filter_complex '[0:v]scale=1152:648:flags=lanczos,fps=24,split=2[forward][reverse_in];[reverse_in]reverse[reverse];[forward][reverse]concat=n=2:v=1:a=0[out]' \
  -map '[out]' -c:v libtheora -q:v 6 -an pvp_stadium_rendered.ogv
```

The fallback JPEG is a representative frame from that loop. Both outputs live
beside the existing original stadium assets; regeneration never overwrites the
original 2D background.
