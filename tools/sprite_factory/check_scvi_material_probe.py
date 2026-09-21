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
if job.get('ambient_material_probe'):
    from blender_ambient_probe import prepare
    native_uv = {o.name: [tuple(tuple(v.uv) for v in layer.data) for layer in o.data.uv_layers]
                 for o in bpy.context.scene.objects if o.type == 'MESH'}
    evaluate = prepare(job['material_probe_metadata'], job['ambient_material_probe'])
    start = evaluate(0)
    middle = evaluate(1)
    assert start != middle, 'Auxiliary UV loop is static'
    assert evaluate(2) == start, 'Source two-second loop does not wrap'
    assert evaluate(3) == middle, 'UV state depends on preceding evaluation'
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        original = native_uv[obj.name]
        assert original == [tuple(tuple(v.uv) for v in layer.data)
                            for layer in list(obj.data.uv_layers)[:len(original)]], 'Native UVs changed'
    print('PASS auxiliary UV loop: motion, wrap, repeat evaluation, native UV preservation')
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
