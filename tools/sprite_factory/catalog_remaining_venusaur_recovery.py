"""Re-export Venusaur's native scaled vine rig and source visibility; review only.

Flattening the exported bone hierarchy bakes Blender's evaluated transforms.
This preserves the native movement when Godot cannot represent the source
parent scale inheritance. No motion keys or visibility times are authored.
"""
import argparse
import copy
import json
import re
from pathlib import Path

from catalog_shiny_za_17_probe import HERE, sha, write, rebuild, restore_fresnel, run_flatpak
from catalog_remaining_eye_bake import chunks
from phase5_variant_parity import compare
from scvi_tracm import inspect_tracm, inspect_visibility
from visibility_export import keys
from visibility_variants import mesh_name


def source_visibility(glb, export, job):
    document, _ = chunks(glb)
    names = [node['name'] for node in document['nodes'] if 'mesh' in node]
    if len(names) != len(set(names)):
        raise ValueError('Ambiguous mesh names')
    targets = {name + '_shape' for name in names}
    manifest = {'schema': 1, 'glb_sha256': sha(glb), 'clips': {}}
    for action, timing in export['animations'].items():
        channel = Path(job['motion_channels'][action])
        if sha(channel) != job['source_files'][str(channel)]:
            raise ValueError('Native side channel changed')
        config = inspect_tracm(channel)
        duration = (config['frames'] - 1) / config['fps']
        if abs(duration - timing['duration']) > 1e-6 or bool(config['loop']) != timing['loop']:
            raise ValueError('Visibility and skeleton clocks disagree')
        tracks, excluded = [], []
        for track in inspect_visibility(channel):
            target = track['target']
            if target not in targets:
                base = re.sub(r'_lod[123]$', '', target)
                if not ((base in targets and base != target) or base == 'pm0003_01_00_flower01_mesh_shape'):
                    raise ValueError('Unknown unexported source target: ' + target)
                excluded.append(target)
                continue
            mesh = mesh_name(target)
            tracks.append({'mesh': mesh, 'source_target': target,
                           'keys': keys(track, config['frames'], config['fps'])})
        if sorted(t['mesh'] for t in tracks) != sorted(names):
            raise ValueError('Incomplete source visibility coverage')
        manifest['clips'][action] = {'duration': duration, 'loop': bool(config['loop']),
                                    'source_sha256': sha(channel), 'tracks': tracks,
                                    'excluded_variant_targets': excluded}
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--production-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    p, out = args.production_root.resolve(), args.output.resolve()
    original = p / 'za-rig-pairs/venusaur'
    imported = json.loads((original / 'import/import.json').read_text())
    source_job = json.loads((original / 'import/job.json').read_text())
    export_job = json.loads((original / 'export/job.json').read_text())
    if imported['identity'] != 'pm0003_00_00' or export_job['species'] != 'venusaur':
        raise ValueError('Default Venusaur identity required')
    for file, expected in source_job['source_files'].items():
        if sha(file) != expected:
            raise ValueError('Pinned source changed: ' + file)
    if sha(export_job['source']) != export_job['source_sha256'] or export_job['source_sha256'] != imported['prepared_sha256']:
        raise ValueError('Prepared native scene changed')
    prior = next(r for r in json.loads((p / 'za-rig-pairs/status.json').read_text())['entries'] if r['species'] == 'venusaur')
    for variant in prior['variants'].values():
        if sha(variant['table']) != variant['table_sha256']:
            raise ValueError('Pinned source palette changed')
    out.mkdir(parents=True, exist_ok=False)
    exported = out / 'export'
    exported.mkdir()
    export_job.update(output=str(exported), native_flatten_bone_hierarchy_diagnostic=True)
    write(exported / 'job.json', export_job)
    run_flatpak(HERE / 'phase5_godot_export_worker.py', exported / 'job.json',
                [(out, ''), (Path(export_job['source']).parent, ':ro'), (HERE, ':ro')], exported / 'worker.log')
    report = json.loads((exported / 'export.json').read_text())
    raw = exported / 'model.glb'
    if report['status'] != 'exported_for_review' or sha(raw) != report['glb_sha256']:
        raise ValueError('Failed native export')
    templates = [r for r in json.loads((p / 'za-final-stage-v2.json').read_text()) if r['species'].split('@')[0] == 'venusaur']
    if len(templates) != 2:
        raise ValueError('Expected normal/shiny pair')
    stage, variants = [], {}
    for original_row in templates:
        row = copy.deepcopy(original_row)
        variant = row['variant']
        table = Path(prior['variants'][variant]['table'])
        target = out / variant / 'model.glb'
        materials = rebuild(raw, target, table)
        restore_fresnel(target, table)
        compare(raw, target)
        row.update(species='venusaur' if variant == 'normal' else 'venusaur-shiny',
                   path=str(target), glb_sha256=sha(target), runtime_approved=False)
        for field in ('runtime_path', 'runtime_sha256'):
            row.pop(field, None)
        row['visibility'] = source_visibility(target, report, source_job)
        stage.append(row)
        variants[variant] = {'path': str(target), 'sha256': sha(target), 'table': str(table),
                             'table_sha256': sha(table), 'materials': materials}
    parity = compare(out / 'normal/model.glb', out / 'shiny/model.glb')
    write(out / 'stage.json', stage)
    write(out / 'status.json', {'schema': 1, 'species': 'venusaur', 'status': 'review_candidate',
                              'runtime_approved': False, 'native_flatten_bone_hierarchy': True,
                              'source_sha256': export_job['source_sha256'], 'variants': variants,
                              'geometry_animation_sha256': parity,
                              'scope': 'Source movement and visibility preserved; fresh actual SCN battle qualification required.'})


if __name__ == '__main__':
    main()
