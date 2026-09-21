"""Isolated Blender A/B renders; never changes sources or enables runtime assets.

Compare culling and displacement independently against the material-loop probe.
Only matching layered smoke materials are touched, never whole mesh visibility.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).parent))
from phase5_source_review_worker import run
from scvi_material_probe import eligible


def intervene(job, cull, displace):
    names = {m['name'] for m in job['material_probe_metadata'] if eligible(m)}
    if not names or not job.get('ambient_material_probe'):
        raise ValueError('Requires an existing auxiliary material-loop probe job')
    for name in names:
        bpy.data.materials[name].use_backface_culling = cull
    count = 0
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH' or not names.intersection(m.name for m in obj.data.materials if m):
            continue
        for modifier in obj.modifiers:
            if modifier.name == 'SourceDisplacementProbe':
                modifier.show_render = displace
                modifier.show_viewport = displace
                count += 1
    if not count:
        raise ValueError('Missing displacement probe')
    return {'backface_culling': cull, 'displacement': displace,
            'runtime_approved': False, 'materials': sorted(names)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('job', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--reference', type=Path,
                        help='Instead render an untouched authored reference; requires matching named actions')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    original = json.loads(args.job.read_text())
    if args.reference:
        source = args.reference.resolve()
        args.output.mkdir(parents=True, exist_ok=False)
        run({'source': str(source), 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
             'species': original['species'], 'output': str(args.output.resolve()),
             'actions': {name: action + '.gfbanm' for name, action in original['actions'].items()}})
        return
    camera_bounds = None
    rows = []
    for cull, displace in ((False, True), (True, True), (False, False), (True, False)):
        job = dict(original)
        output = args.output / f'cull-{int(cull)}-displace-{int(displace)}'
        output.mkdir(parents=True, exist_ok=False)
        job['output'] = str(output)
        run(job, lambda j: intervene(j, cull, displace), camera_bounds)
        report = json.loads((output / 'review.json').read_text())
        camera_bounds = report['camera_bounds']
        rows.append('<tr><th>' + output.name + '</th>' + ''.join(
            f'<td><img width="320" src="{output.name}/{image}"></td>'
            for image in ('idle-front.png', 'ambient-03.png', 'ambient-06.png', 'ambient-09.png')) + '</tr>')
    (args.output / 'index.html').write_text(
        '<!doctype html><meta charset="utf-8"><title>Smoke ablation</title>'
        '<style>body{background:#18202a;color:white;font:16px sans-serif}</style>'
        '<h1>Experimental smoke comparison — not runtime approved</h1>'
        '<p>Same source, camera, lighting and sample times. Only culling and displacement change.</p>'
        '<table>' + ''.join(rows) + '</table>')


if __name__ == '__main__':
    main()
