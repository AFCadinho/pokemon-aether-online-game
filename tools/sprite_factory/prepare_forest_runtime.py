"""Export a trusted, purchased local forest project into a Linux desktop pack.

Run from the game workspace; uses slot-c isolation, never copies caches or assets.
Native library stays in the purchased project. This is local review packaging,
not a release/distribution pipeline.
"""
import argparse
import json
import platform
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('project', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[2]
    workspace = next(p for p in source.parents if (p / 'ops/worktrees/slot-env').is_file())
    project, output = args.project.resolve(), args.output.resolve()
    if platform.system() != 'Linux' or platform.machine() != 'x86_64':
        raise ValueError('This local native descriptor targets Linux x86_64')
    if project.is_relative_to(source) or output.is_relative_to(source):
        raise ValueError('Purchased project and pack stay outside the client checkout')
    if not (project / 'scenes/world/test_world.res').is_file():
        raise ValueError('Expected the isolated purchased Temperate Forest project')
    marker = output / '.pokeaether-forest-runtime'
    if output.exists() and any(output.iterdir()) and not marker.exists():
        raise ValueError('Refusing an unrelated nonempty output directory')
    libraries = {mode: project / f'addons/terrain_3d/bin/libterrain.linux.{mode}.x86_64.so'
                 for mode in ['debug', 'release']}
    if not all(path.is_file() for path in libraries.values()):
        raise ValueError('Terrain3D native libraries missing')
    output.mkdir(parents=True, exist_ok=True)
    marker.touch()
    (project / 'export_forest_scene.gd').write_bytes((source / 'tools/sprite_factory/export_forest_scene.gd').read_bytes())
    prefix = [str(workspace / 'ops/worktrees/slot-env'), 'slot-c', '--', 'godot', '--headless', '--path', str(project)]
    subprocess.run(prefix + ['--script', 'res://export_forest_scene.gd'], check=True)
    subprocess.run(prefix + ['--export-pack', 'PokeAether Forest Pack', str(output / 'forest.pck')], check=True)
    descriptor = '[configuration]\nentry_symbol="terrain_3d_init"\ncompatibility_minimum=4.4\n[libraries]\n'
    descriptor += ''.join(f'linux.{mode}.x86_64={json.dumps(str(path))}\n' for mode, path in libraries.items())
    (output / 'terrain.gdextension').write_text(descriptor)
    (output / 'forest.json').write_text(json.dumps({'schema': 1, 'pack': 'forest.pck'}, indent=2) + '\n')
    print(output / 'forest.json')


if __name__ == '__main__':
    main()
