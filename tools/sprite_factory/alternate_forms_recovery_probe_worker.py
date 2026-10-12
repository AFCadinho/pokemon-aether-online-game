"""Read-only structural evidence for remaining alternate-form source bindings."""
import hashlib
import json
from pathlib import Path
import sys
import bpy


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def value(socket):
    try:
        v = socket.default_value
        return list(v) if hasattr(v, '__len__') and not isinstance(v, str) else v
    except (AttributeError, TypeError):
        return None


def tree_info(tree, seen=None):
    seen = set() if seen is None else seen
    if not tree or tree.name in seen:
        return None
    seen.add(tree.name)
    return {'name': tree.name, 'nodes': [
        {'name': n.name, 'type': n.bl_idname,
         'inputs': {s.name: value(s) for s in n.inputs},
         'properties': {p: getattr(n, p) for p in ('blend_type','operation','use_clamp','uv_map','interpolation','extension') if hasattr(n,p)},
         'outputs': {s.name: value(s) for s in n.outputs},
         **({'image': n.image.name, 'size': list(n.image.size)} if n.type == 'TEX_IMAGE' and n.image else {}),
         **({'group': tree_info(n.node_tree, seen)} if n.type == 'GROUP' else {})}
        for n in tree.nodes],
        'drivers': [{'path': c.data_path, 'expression': c.driver.expression, 'variables': [{'name': v.name, 'type': v.type, 'targets': [{'id': t.id.name if t.id else None, 'path': t.data_path} for t in v.targets]} for v in c.driver.variables]} for c in tree.animation_data.drivers] if tree.animation_data else [],
        'links': [[l.from_node.name, l.from_socket.name, l.to_node.name, l.to_socket.name] for l in tree.links]}


def main(job):
    for source in job['sources']:
        path = Path(source['path'])
        assert hashlib.sha256(path.read_bytes()).hexdigest() == source['sha256']
        out = Path(source['output']); out.parent.mkdir(parents=True, exist_ok=True)
        if out.exists():
            continue
        bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False, use_scripts=False)
        rigs = []
        for rig in [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']:
            bones = {b.name: {'parent': b.parent.name if b.parent else None,
                'matrix': [list(r) for r in b.matrix_local]} for b in rig.data.bones}
            meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and
                any(m.type == 'ARMATURE' and m.object == rig for m in o.modifiers)]
            rigs.append({'name': rig.name, 'bones': bones, 'bones_sha256': digest(bones),
                'matrix': [list(r) for r in rig.matrix_world],
                'meshes': [{'name': m.name, 'matrix': [list(r) for r in m.matrix_local],
                    'vertices': len(m.data.vertices), 'polygons': len(m.data.polygons),
                    'geometry_sha256': digest([[list(v.co) for v in m.data.vertices],
                        [list(p.vertices) for p in m.data.polygons]]),
                    'skin_sha256': digest([[(m.vertex_groups[g.group].name, g.weight) for g in v.groups] for v in m.data.vertices]),
                    'materials': [a.name if a else None for a in m.data.materials]} for m in meshes]})
        actions = []
        for action in bpy.data.actions:
            curves = [(c.data_path, c.array_index, [(list(k.co), k.interpolation) for k in c.keyframe_points])
                for l in action.layers for s in l.strips for b in s.channelbags for c in b.fcurves]
            actions.append({'name': action.name, 'range': list(action.frame_range),
                'paths': sorted({c[0] for c in curves}), 'curves_sha256': digest(curves)})
        result = {'source_sha256': source['sha256'], 'rigs': rigs, 'actions': actions,
            'custom_properties': {o.name: {k: repr(v) for k,v in o.items()} for o in bpy.data.objects if o.keys()},
            'materials': {m.name: tree_info(m.node_tree) for m in bpy.data.materials},
            'images': [{'name': i.name, 'path': i.filepath, 'size': list(i.size),
                'packed': bool(i.packed_file), 'packed_sha256': hashlib.sha256(i.packed_file.data).hexdigest() if i.packed_file else None}
                for i in bpy.data.images]}
        out.write_text(json.dumps(result, indent=2)+'\n')
        print('RECOVERY_PROBED', path.name, flush=True)


if __name__ == '__main__':
    main(json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text()))
