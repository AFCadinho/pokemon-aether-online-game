# Surf mount idle cycles

Lapras keeps its approved idle. Primal Kyogre, Magikarp, Wailmer, Drednaw,
Mantine, Basculegion, Wailord and Gyarados now use the same gentle rhythm:
rest, one native pixel up, rest, one native pixel down. Durations are
0.9 / 0.65 / 0.9 / 0.65 seconds. There is no scaling or interpolation.

The immutable movement frame zero supplies each direction's approved pose.
The mount, foreground and opaque rider mask move together, and the rider's
seat follows the same pixel offset. The lowest two submerged silhouette rows
remain fixed, as in the Lapras pilot. Frame zero is pixel-identical to the
previous idle, preserving fishing and paused Store previews.

`idleWaterContactSheet` supplies four stationary contact frames per direction.
They gently change opacity at the original foam coordinates, with no moving
wake. The existing movement water sheet is unchanged. The water node follows
the mount clock; it never plays independently. Legacy definitions without this
optional sheet still use a single stationary contact frame.

Shiny variants share normal idle masks and water contact; only artwork differs.
Actor position, map depth, collision, interaction origins and nameplates remain
unchanged. Fishing retains its independent cast clock and static mount pose.

Regenerate after running any source mount builder:

```sh
python3 tools/build_surf_mount_idles.py
python3 tools/build_surf_mount_idles.py --check
```

The check compares all generated pixels, protects resting poses and bottom
contact rows, and rejects overlapping translucent mount/foreground pixels.
`tests/mount_idle_pilot_check.gd` exercises actual local/remote playback, all
directions and genders, normal/shiny switching, masks, rider synchronization,
gameplay anchors, fishing, Store pause and water-cache fallback.

Use `tools/preview_surf_five_mounts.gd -- --mount=ID --idle-cycle` for runtime
captures of all four phases; combine them with the durations above for GIFs.
