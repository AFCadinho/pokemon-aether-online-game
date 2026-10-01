"""Disposable, explicitly authored Terastal fur palette for visual review."""
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy


def run(job):
    from scvi_material_probe import inspect_materials
    source, table = Path(job['source']), Path(job['table'])
    if job.get('runtime_approved') is not False or job.get('authored_review_proposal') is not True:
        raise ValueError('This worker only produces authored review proposals')
    if any(hashlib.sha256(p.read_bytes()).hexdigest() != job[k + '_sha256']
           for p, k in ((source, 'source'), (table, 'table'))):
        raise ValueError('Pinned source changed')
    if Path(job['output']).exists():
        raise ValueError('Retain earlier proposals')
    rows = {r['name']: r for r in inspect_materials(table)}
    if job['material'] != 'body_c1' or not any(s['name'] == 'FresnelBlend' for s in rows['body_c1']['shaders']):
        raise ValueError('Unexpected Terastal material')
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False, load_ui=False)
    material = bpy.data.materials[job['material']]
    for key, proposed in job['palette'].items():
        if key not in ('BaseColorLayer1', 'BaseColorLayer2', 'BaseColorLayer3'):
            raise ValueError('Unexpected palette input')
        if len(proposed) != 4 or not all(math.isfinite(v) and 0 <= v <= 1 for v in proposed):
            raise ValueError('Invalid authored palette')
        nodes = [n for n in material.node_tree.nodes if n.type == 'GROUP' and key in n.inputs]
        if len(nodes) != 1 or nodes[0].inputs[key].is_linked:
            raise ValueError('Palette has no unique source input')
        socket = nodes[0].inputs[key]
        if not all(math.isclose(a, b, abs_tol=1e-5) for a, b in zip(socket.default_value, rows['body_c1']['colors'][key])):
            raise ValueError('Source palette differs from its material table')
        socket.default_value = proposed
    bpy.ops.wm.save_as_mainfile(filepath=job['output'])
    if hashlib.sha256(source.read_bytes()).hexdigest() != job['source_sha256']:
        raise ValueError('Original source changed')
    Path(job['receipt']).write_text(json.dumps({**job, 'output_sha256': hashlib.sha256(Path(job['output']).read_bytes()).hexdigest()}, indent=2)+'\n')


if __name__ == '__main__':
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    run(json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text()))
