# Flying Nimbus

Approved golden Nimbus design, packed from `source.png` without changing the
cloud artwork. The source is the generated 1254px transparent concept atlas:
front / left / right / rear in four 627px quadrants. Native rendering samples
each quadrant at 64px using nearest neighbour, as in the approved preview.
Source generation ID: 01a0ff08-de85-78e3-92c0-c435575ee8ad.

`python3 tools/build_flying_nimbus.py --check` verifies the seven runtime atlases
and all four seats. Omit `--check` to rebuild. Runtime mount cells are 192px;
the art remains 64px. The rear two source quadrants need 6px extra vertical
padding. Packing thresholds the generated alpha at 128 to remove invisible
halos and keep rider occlusion binary. Foreground/rider masks cover only the lower cloud rim. The actual
player appearance is composed by the existing mounted rider service.

The complete rig uses the existing 6px hover, with a 1px / 2.4s oscillation.
Cloud and rider retain their approved relative placement and shadow gap.
Movement adds seven bounded golden puffs opposite the travel direction, behind
the cloud. Idle, mount switching and dismounting stop the trail. These visuals
do not change world coordinates, collision, interactions or world depth.

Grant item `flying-nimbus-mount` through the existing administration inventory
reward flow, then select **Flying Nimbus** in the Land mount picker. Normal
regional Mount License restrictions apply. No store listing or box is added.

Review the actual game renderer with `tools/preview_flying_nimbus.gd` and use
`-- --output=/absolute/path` to export PNG frames for a GIF.
