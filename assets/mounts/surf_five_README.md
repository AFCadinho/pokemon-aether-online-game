# Five admin-testable Surf mounts

Wailmer, Drednaw, Mantine, Basculegion and Wailord use the approved
`surf-five-v1` follower designs at their original pixel scale. Their permanent
items are respectively `wailmer-mount`, `drednaw-mount`, `mantine-mount`,
`basculegion-mount` and `wailord-mount`. Grant one through admin item rewards,
then select it in the Surf slot. Normal Surf access is still required.

These are normal variants only. There are no boxes or Gift Store products.

## Artwork and rebuilding

Each folder contains its native source sheet and generated runtime sheets.
Drednaw's source is the approved reposed rear-view sheet; do not replace it
with the original follower without also reviewing its rear saddle alignment.
The other sources are unchanged follower sheets. `tools/surf_five_designs.json`
records the approved seat anchors, phase shifts and foreground polygons.

Run `python3 tools/build_surf_five_mounts.py` from the frontend with Pillow
installed. It regenerates the six textures for each mount and checks the
matching definitions in `data/mounts.json`. There is no source scaling:
64-pixel source cells (128 for Wailord) are placed on 192-pixel runtime cells.

The lower body fades and takes a water tint. Broken foam touches its lower
silhouette. `water_contact.png` has four idle rows followed by four swimming
rows; swimming adds a trailing wake. Existing `MountWaterContact` synchronizes
the direction and phase with the mount on local and remote players. Its node
stays in the mount's world depth and outside player clothing/masking.

The rider mask retains the approved **opaque** foreground silhouette so player
pixels cannot show through translucent fins. Base and foreground do not draw
the same pixels twice. Fishing uses each mount's anatomical foreground and
seat correction, retaining idle foam without a moving wake.

## Position and verification

The resting lower silhouette matches Lapras and follower NPCs: its lower edge
is 12 pixels below the physical origin (native lower edge 60, half-cell 32,
sprite offset -16). `WORLD_WATERLINE_Y` in the builder translates the complete
approved rig down by 12 pixels: mount, foreground, opaque mask, contact foam,
wake and rider offsets. The original design coordinates remain in the config.
The native swimming cycle can move a fin or tail below that line. Physical player position,
collision, map sorting and ordinary adjacent interaction are unchanged. These
smaller rigs do not need Kyogre's side-specific interaction-height correction.

`tests/surf_five_mounts_check.gd` checks ownership, Surf-only selection,
submerged layers, switching against fresh player renders, local/remote seats,
all directions/phases, real NPC interaction gates and fishing. Run it through
the assigned slot's `ops/worktrees/slot-env` wrapper.

`tools/preview_surf_five_mounts.gd -- --output=/absolute/output/path` captures
both player bodies in all four directions, riding, swimming and fishing with
the actual runtime renderer. `--anchors` adds the occupied tile and its origin;
`--adinho` uses the custom outfit for the male row. `--poliwag` adds the real
follower sprite on the same physical tile row, one tile to the side, using the
NPC's normal sprite offset. Captures use integer 2x
magnification. They supplement a manual map test near NPCs, shore edges and
foreground scenery; they are not captures of a connected multiplayer session.
