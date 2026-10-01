"""Keep approved materials while replacing an unstable bone hierarchy export.

Uses Blender's native flattened-bone export from the exact prepared source.
Vertex data, UVs, triangles, weights and named joint assignments are guarded.
No placement offset is used to conceal deformed geometry.
"""
import copy
import hashlib
import json
from pathlib import Path
import struct

from catalog_remaining_eye_bake import chunks, write_glb


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def values(doc, binary, index):
    a = doc['accessors'][index]
    if 'sparse' in a:
        raise ValueError('Sparse geometry requires explicit handling')
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    fmt = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}[a['componentType']]
    view = doc['bufferViews'][a['bufferView']]
    size = struct.calcsize('<' + fmt * width)
    offset = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    return [struct.unpack_from('<' + fmt * width, binary, offset + i * view.get('byteStride', size)) for i in range(a['count'])]


def mesh_signature(doc, binary):
    if len(doc['skins']) != 1:
        raise ValueError('Expected one verified source rig')
    joints = [doc['nodes'][n]['name'] for n in doc['skins'][0]['joints']]
    result = {}
    for mesh in doc['meshes']:
        primitives = []
        for primitive in mesh['primitives']:
            attributes = {}
            for name, index in primitive['attributes'].items():
                data = values(doc, binary, index)
                if name.startswith('JOINTS_'):
                    data = [tuple(joints[int(x)] for x in row) for row in data]
                attributes[name] = data
            primitives.append({'attributes': attributes, 'indices': values(doc, binary, primitive['indices']),
                               'mode': primitive.get('mode', 4), 'material': doc['materials'][primitive['material']]['name']})
        result[mesh['name']] = primitives
    return result


def graft(approved, flattened, target):
    doc, binary = chunks(approved)
    extra, extra_binary = chunks(flattened)
    if mesh_signature(doc, binary) != mesh_signature(extra, extra_binary):
        raise ValueError('Flattened export changed mesh data or named skin assignments')
    material_map = {m['name']: i for i, m in enumerate(doc['materials'])}
    before_materials = copy.deepcopy(doc['materials'])
    packed = bytearray(binary)
    while len(packed) % 4:
        packed.append(0)
    offset = len(packed)
    packed.extend(extra_binary)
    first_view, first_accessor = len(doc['bufferViews']), len(doc['accessors'])
    for view in extra['bufferViews']:
        v = copy.deepcopy(view)
        if v.get('buffer', 0) != 0:
            raise ValueError('External source buffer')
        v['buffer'] = 0
        v['byteOffset'] = v.get('byteOffset', 0) + offset
        doc['bufferViews'].append(v)
    for accessor in extra['accessors']:
        a = copy.deepcopy(accessor)
        a['bufferView'] += first_view
        doc['accessors'].append(a)
    for key in ('nodes', 'skins', 'meshes', 'animations', 'scenes', 'scene'):
        if key in extra:
            doc[key] = copy.deepcopy(extra[key])
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            primitive['indices'] += first_accessor
            primitive['attributes'] = {k: v + first_accessor for k, v in primitive['attributes'].items()}
            primitive['material'] = material_map[extra['materials'][primitive['material']]['name']]
            if primitive.get('targets'):
                raise ValueError('Morph targets require explicit handling')
    for skin in doc['skins']:
        skin['inverseBindMatrices'] += first_accessor
    for animation in doc['animations']:
        for sampler in animation['samplers']:
            sampler['input'] += first_accessor
            sampler['output'] += first_accessor
    excluded = []
    for node in doc['nodes']:
        if node.get('name') == 'pm1131_00_00_closedshell_mesh':
            node.pop('mesh', None)
            node.pop('skin', None)
            excluded.append(node['name'])
    assert doc['materials'] == before_materials
    assert packed[:len(binary)] == binary
    target.parent.mkdir(parents=True, exist_ok=True)
    write_glb(target, doc, packed)
    return {'approved_source_sha256': sha(approved), 'flattened_export_sha256': sha(flattened),
            'glb_sha256': sha(target), 'geometry_uv_weights_named_joints_unchanged': True,
            'approved_materials_and_textures_unchanged': True, 'excluded_alternate_shell': excluded,
            'policy': 'native Blender flattened bone hierarchy; original source actions and timing retained'}


def prepare(evidence):
    rows = json.loads((evidence / 'native-detail-v2/status-complete.json').read_text())['entries']
    checkpoint = json.loads(Path(__file__).with_name('catalog_remaining_dlc_material_checkpoint.json').read_text())
    approved = {r['species']: r for r in checkpoint['entries']}
    for row in rows:
        directory = evidence / 'flat-motion-v1' / row['species']
        report = json.loads((directory / 'export.json').read_text())
        job = json.loads((directory / 'job.json').read_text())
        original_job = json.loads((evidence / 'material-pairs-v1' / row['species'] / 'export/job.json').read_text())
        flat = directory / 'model.glb'
        if (sha(flat) != report['glb_sha256'] or not report['flatten_bone_hierarchy']
                or job['source_sha256'] != original_job['source_sha256']):
            raise ValueError('Flattened source provenance differs')
        for variant, source in row['variants'].items():
            target = evidence / 'flat-approved-v1' / row['species'] / variant / 'model.glb'
            if target.exists():
                raise ValueError('Retain completed output evidence')
            if sha(Path(source['path'])) != approved[row['species']]['variants'][variant]['glb_sha256']:
                raise ValueError('Appearance-approved input hash differs')
            receipt = graft(Path(source['path']), flat, target)
            target.with_name('receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        print('PRESERVED_MATERIALS_FLAT_MOTION', row['species'], flush=True)


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-root', type=Path, required=True)
    args = parser.parse_args()
    prepare(args.evidence_root.resolve())
