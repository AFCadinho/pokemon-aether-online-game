# Animated wild grass background

The shared 2D grass video is selected through `BattleEnvironmentProfile.wild_2d_background` for wild battles only. Grass, Pallet, Viridian, Pewter, Cerulean and Routes 1, 2, 3, 4, 22, 24 and 25 reference the same art resource. The original location profile remains the battle environment and 3D arena context. Trainer battles keep their existing static art; water, caves, gyms, the S.S. Anne and the PvP stadium retain their own backgrounds.

## Asset preparation

- User source: `NEW BACKGROUND (2).mp4`, 1920×1080, 24 fps, 20 seconds.
- Source SHA-256: `31c4662d5d699d29c65bd922217b43b864af41b7bc15ddb3157d643d19fd7297`.
- Runtime asset: `assets/video/battle/grass_meadow.ogv`, silent Ogg Theora, 1152×648, 24 fps, 19 seconds, 1,345,267 bytes.
- Crossfade the last second into the original first second and begin at source second 1. This joins the end to the start without reversing the animation.
- Encode with FFmpeg `libtheora`, quality 6, keyframe interval 64, `yuv420p`.
- Extract the first decoded video frame as `assets/background/battle/environments/grass_animated_fallback.jpg` (FFmpeg JPEG quality 2).
- Existing `grass_platform_v3.png` remains a separate transparent platform layer.

Recreate from the source with:

```sh
ffmpeg -i 'NEW BACKGROUND (2).mp4' -filter_complex '[0:v]scale=1152:648:flags=lanczos,split[a][b];[a]trim=start=1:end=20,setpts=PTS-STARTPTS[body];[b]trim=start=0:end=1,setpts=PTS-STARTPTS[head];[body][head]xfade=transition=fade:duration=1:offset=18,format=yuv420p[out]' -map '[out]' -an -c:v libtheora -q:v 6 -g 64 grass_meadow.ogv
ffmpeg -i grass_meadow.ogv -frames:v 1 -q:v 2 grass_animated_fallback.jpg
```

The battle video layer stays below weather and terrain effects. Playback pauses while the battle is hidden or a visible full 3D arena covers it; 2.5D keeps the background. Existing resource exports include the referenced video and fallback.

## Focused verification

Run `tests/animated_grass_background_check.gd` through the assigned slot environment. It checks all grass profiles, unaffected environments, native decoding, a complete loop, hidden/3D pause and resume, and switching to trainer, water and PvP backgrounds. For visual review, run on a real display and pass an absolute screenshot path after `--`.

Browser and Android frame rates still require testing on those target platforms; native decoding is not a platform performance certification.
