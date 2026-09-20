"""Prepare an already extracted, isolated FancifulCrow project for local review.

Never packages purchased assets into the client. Run once on a fresh extraction.
"""
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('project', type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    source = Path(__file__).resolve().parents[2]
    if project.is_relative_to(source) or not (project / 'scenes/world/test_world.res').is_file():
        raise ValueError('Expected an isolated extracted Temperate Forest project')
    for relative in ['scripts/battle/battle_ui/material_response.gd',
                     'scripts/battle/battle_ui/material_response.gdshader',
                     'scripts/battle/battle_ui/material_irradiance.gdshader',
                     'tools/sprite_factory/forest_battle_review.gd',
                     'tools/sprite_factory/temperate_battle_review.gd']:
        target = project / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((source / relative).read_bytes())
    # No demo autoloads, editor plugins, full-screen capture or input overrides.
    (project / 'project.godot').write_text('''config_version=5
[application]
config/name="PokeAether Temperate Forest Review"
config/features=PackedStringArray("4.6", "Forward Plus")
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[filesystem]
import/blender/enabled=false
[physics]
3d/physics_engine="Jolt Physics"
[rendering]
renderer/rendering_method="forward_plus"
[shader_globals]
wind_direction={"type": "vec2", "value": Vector2(0.6, 0.4)}
wind_speed={"type": "float", "value": 1.0}
wind_strength={"type": "float", "value": 1.0}
''')
    print(f'Prepared isolated review: {project}')


if __name__ == '__main__':
    main()
