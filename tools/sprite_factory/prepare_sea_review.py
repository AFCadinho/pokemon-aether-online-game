"""Prepare an isolated original sea study with only allowlisted review code."""
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('project', type=Path)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[2]
    project = args.project.resolve()
    if project.is_relative_to(source):
        raise ValueError('Review project must be outside the frontend checkout')
    marker = project / '.pokeaether-sea-review'
    if project.exists() and any(project.iterdir()) and not marker.exists():
        raise ValueError('Refusing to overwrite a non-review directory')
    project.mkdir(parents=True, exist_ok=True)
    for relative in [
        'scripts/battle/arenas/forest_arena.gd',
        'scripts/battle/arenas/arena_geometry.gd',
        'scripts/battle/arenas/cave_arena.gd',
        'scripts/battle/arenas/sea_arena.gd',
        'scripts/battle/battle_ui/material_response.gd',
        'scripts/battle/battle_ui/material_response.gdshader',
        'scripts/battle/battle_ui/material_irradiance.gdshader',
        'tools/sprite_factory/forest_battle_review.gd',
        'tools/sprite_factory/temperate_battle_review.gd',
        'tools/sprite_factory/cave_battle_review.gd',
        'tools/sprite_factory/sea_battle_review.gd',
        'tools/sprite_factory/sea_water.gdshader',
    ]:
        target = project / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((source / relative).read_bytes())
    (project / 'project.godot').write_text('''config_version=5
[application]
config/name="PokeAether Sea Review"
config/features=PackedStringArray("4.6", "Forward Plus")
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
renderer/rendering_method="forward_plus"
''')
    marker.touch()
    print(f'Prepared isolated sea: {project}')


if __name__ == '__main__':
    main()
