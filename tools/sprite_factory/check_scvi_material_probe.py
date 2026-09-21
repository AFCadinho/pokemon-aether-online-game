"""Blender structural checks on a real probe job; never saves its source."""
import hashlib
import json
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).parent))
from scvi_material_probe import apply_probe, eligible


job = json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text())
source = Path(job['source'])
assert hashlib.sha256(source.read_bytes()).hexdigest() == job['source_sha256']
bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)


def geometry():
    return {obj.name: (obj.hide_render, tuple(tuple(v.co) for v in obj.data.vertices),
                      tuple(tuple(p.vertices) for p in obj.data.polygons))
            for obj in bpy.context.scene.objects if obj.type == 'MESH'}


before_geometry = geometry()
before_nodes = {m.name: set(n.name for n in m.node_tree.nodes)
                for m in bpy.data.materials if m.node_tree}
assert apply_probe([])['applied'] == []
report = apply_probe(job['material_probe_metadata'], job.get('displacement_probe', False))
names = {m['name'] for m in job['material_probe_metadata'] if eligible(m)}
assert names == {item['material'] for item in report['applied']}
assert geometry() == before_geometry, 'Source meshes/visibility changed'
for mat in bpy.data.materials:
    if not mat.node_tree:
        continue
    now = {n.name for n in mat.node_tree.nodes}
    if mat.name in names:
        assert before_nodes[mat.name] <= now, 'Original shader nodes removed'
        surface = next(n for n in mat.node_tree.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output)
        mix = surface.inputs['Surface'].links[0].from_node
        assert mix.type == 'MIX_SHADER'
        assert mix.inputs[0].links[0].from_socket.name == 'Alpha'
        assert mix.inputs[2].links[0].from_node.type == 'BSDF_TRANSPARENT'
    else:
        assert now == before_nodes[mat.name], 'Unmatched material changed'
if names:
    try:
        apply_probe(job['material_probe_metadata'])
    except ValueError as error:
        assert 'already applied' in str(error)
    else:
        raise AssertionError('Duplicate application was not rejected')
assert hashlib.sha256(source.read_bytes()).hexdigest() == job['source_sha256']
print('PASS material probe:', sorted(names), 'source geometry retained; unrelated materials unchanged')
