# Zekrom movement turbo

Normal and shiny Zekrom opt into `movementEffect: "zekrom_turbo"`.
`scripts/world/mount_turbo_effect.gd` owns a short pixel-edged energy jet,
turbine illumination and a maximum of 12 CPU spark particles per rider.
There are no extra lights, full-screen shaders, sprite replacements or speed
changes. CPU particles also work with the compatibility renderer.

The existing four movement poses share a two-pixel vertical bob. Tail centers
and nozzles are native 192px-cell coordinates, mirrored for side views; the
same frame offset moves both light and exhaust. The effect starts when the
mount enters a walk animation and ramps up in 0.125s. Stopping ends particle
emission immediately and fades remaining light within 0.084s. Dismounting or
switching to another mount clears it completely.

The jet is occluded by the body/rider in front view. In side/rear views it
begins inside the visible turbine opening, above the tail artwork. Side-view
illumination follows the existing two cyan turbine slits. Every component
keeps relative world Z zero, so the complete mounted actor retains normal
map sorting. Local, remote and Store previews share this effect.

Nozzle coordinates (before the native bob):

| Facing | Nozzle | Exhaust |
| --- | --- | --- |
| Down | 95, 88 | Up, behind body |
| Left | 121, 87 | Right |
| Right | 71, 87 | Left |
| Up | 95, 103 | Down |

`tests/zekrom_turbo_check.gd` checks activation, direction, per-frame attachment,
normal/shiny switching, map depth, stopping, dismount and Store pause. Run
`tools/preview_zekrom_turbo.gd -- --output=PATH` for a runtime GIF sequence:
64 frames at 50ms each, showing idle → movement → idle in all directions.

Particle API reference: https://docs.godotengine.org/en/stable/classes/class_cpuparticles2d.html
