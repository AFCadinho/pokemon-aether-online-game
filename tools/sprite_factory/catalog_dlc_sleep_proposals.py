"""Append explicit own-rig rest proposals; retain native geometry and clips.

No native sleep clip exists in this intake. Freeze native idle at its starting pose,
reuse only own-rig eyelid transforms from the faint endpoint, and add 0.6% root
breathing. Human appearance/battle review remains mandatory.
"""
import argparse
from bisect import bisect_right
import copy
import hashlib
import json
import math
from pathlib import Path
import struct
from catalog_remaining_eye_bake import chunks, write_glb


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def accessor(doc, binary, index):
    a = doc['accessors'][index]
    if a['componentType'] != 5126 or 'sparse' in a:
        raise ValueError('Expected explicit float animation accessor')
    width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[a['type']]
    v = doc['bufferViews'][a['bufferView']]
    offset = v.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = v.get('byteStride', width * 4)
    return [list(struct.unpack_from('<' + 'f' * width, binary, offset + i * stride)) for i in range(a['count'])]


def interpolate(a, b, weight, quaternion):
    if not quaternion:
        return [x + weight * (y - x) for x, y in zip(a, b)]
    dot = sum(x * y for x, y in zip(a, b))
    if dot < 0:
        b = [-x for x in b]
        dot = -dot
    if dot > .9995:
        result = [x + weight * (y - x) for x, y in zip(a, b)]
    else:
        angle = math.acos(max(-1, min(1, dot)))
        result = [(math.sin((1 - weight) * angle) * x + math.sin(weight * angle) * y) / math.sin(angle) for x, y in zip(a, b)]
    length = math.sqrt(sum(x*x for x in result))
    if length < 1e-8:
        raise ValueError('Invalid rotation')
    return [x / length for x in result]


def sample(doc, binary, animation, fraction):
    result = {}
    duration = max(accessor(doc, binary, s['input'])[-1][0] for s in animation['samplers'])
    time = duration * fraction
    for channel in animation['channels']:
        target = channel['target']
        if target['path'] not in ('translation', 'rotation', 'scale'):
            raise ValueError('Unknown source animation target')
        sampler = animation['samplers'][channel['sampler']]
        times = [r[0] for r in accessor(doc, binary, sampler['input'])]
        values = accessor(doc, binary, sampler['output'])
        if len(times) != len(values) or sampler.get('interpolation', 'LINEAR') not in ('LINEAR', 'STEP'):
            raise ValueError('Unsupported source animation interpolation')
        index = max(0, bisect_right(times, time) - 1)
        if index == len(times) - 1 or sampler.get('interpolation') == 'STEP':
            value = values[index]
        else:
            w = max(0, min(1, (time - times[index]) / max(times[index + 1] - times[index], 1e-12)))
            value = interpolate(values[index], values[index + 1], w, target['path'] == 'rotation')
        result[(target['node'], target['path'])] = value
    return result


def append(doc, binary, values, kind):
    while len(binary) % 4:
        binary.append(0)
    start = len(binary)
    flat = [x for row in values for x in row]
    if not all(math.isfinite(x) for x in flat):
        raise ValueError('Nonfinite proposal')
    binary.extend(struct.pack('<' + 'f' * len(flat), *flat))
    view = len(doc['bufferViews'])
    doc['bufferViews'].append({'buffer': 0, 'byteOffset': start, 'byteLength': len(binary) - start})
    record = {'bufferView': view, 'componentType': 5126, 'count': len(values), 'type': kind}
    if kind == 'SCALAR':
        record.update(min=[min(flat)], max=[max(flat)])
    index = len(doc['accessors'])
    doc['accessors'].append(record)
    return index


def trs(pose, node, doc):
    t = pose.get((node, 'translation'), doc['nodes'][node].get('translation', [0, 0, 0]))
    x, y, z, w = pose.get((node, 'rotation'), doc['nodes'][node].get('rotation', [0, 0, 0, 1]))
    scale = pose.get((node, 'scale'), doc['nodes'][node].get('scale', [1, 1, 1]))
    rows = [[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
            [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
            [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]]
    return [[rows[i][j]*scale[j] for j in range(3)] + [t[i]] for i in range(3)] + [[0, 0, 0, 1]]


def multiply(a, b):
    return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def inverse(a):
    rows = [list(row) + [float(i == j) for j in range(4)] for i, row in enumerate(a)]
    for i in range(4):
        pivot = max(range(i, 4), key=lambda j: abs(rows[j][i]))
        rows[i], rows[pivot] = rows[pivot], rows[i]
        divisor = rows[i][i]
        if abs(divisor) < 1e-10:
            raise ValueError('Singular eyelid reference pose')
        rows[i] = [v/divisor for v in rows[i]]
        for j in range(4):
            if j != i:
                weight = rows[j][i]
                rows[j] = [x-weight*y for x, y in zip(rows[j], rows[i])]
    return [r[4:] for r in rows]


def decomposition(matrix):
    scale = [math.sqrt(sum(matrix[i][j]**2 for i in range(3))) for j in range(3)]
    r = [[matrix[i][j]/scale[j] for j in range(3)] for i in range(3)]
    if max(abs(sum(r[k][i]*r[k][j] for k in range(3))) for i in range(3) for j in range(i)) > .001:
        raise ValueError('Sleep eyelid transfer introduced shear')
    trace = sum(r[i][i] for i in range(3))
    if trace > 0:
        s = 2*math.sqrt(trace+1)
        q = [(r[2][1]-r[1][2])/s, (r[0][2]-r[2][0])/s, (r[1][0]-r[0][1])/s, s/4]
    else:
        i = max(range(3), key=lambda k: r[k][k]);j, k = (i+1)%3, (i+2)%3
        s = 2*math.sqrt(max(0, 1+r[i][i]-r[j][j]-r[k][k]))
        q = [0, 0, 0, (r[k][j]-r[j][k])/s]
        q[i], q[j], q[k] = s/4, (r[i][j]+r[j][i])/s, (r[i][k]+r[k][i])/s
    length = math.sqrt(sum(x*x for x in q))
    return {'translation': [matrix[i][3] for i in range(3)], 'rotation': [x/length for x in q], 'scale': scale}


def propose(source, target, native_damage=None, hierarchical_source=None):
    doc, original = chunks(source)
    if native_damage:
        extra, extra_binary = chunks(native_damage)
        if [n.get('name') for n in extra['nodes']] != [n.get('name') for n in doc['nodes']]:
            raise ValueError('Native damage node identities differ')
        damage = copy.deepcopy(next(a for a in extra['animations'] if a['name'] == 'damage'))
        packed = bytearray(original)
        for sampler in damage['samplers']:
            for property in ('input', 'output'):
                a = extra['accessors'][sampler[property]]
                sampler[property] = append(doc, packed, accessor(extra, extra_binary, sampler[property]), a['type'])
        doc['animations'].append(damage)
        original = bytes(packed)
    baseline_document = copy.deepcopy(doc)
    clips = {a['name']: a for a in doc['animations']}
    if 'sleep' in clips or 'faint_loop' in clips:
        raise ValueError('Never replace an existing sleep/hold clip')
    idle = sample(doc, original, clips['idle'], 0)
    faint = sample(doc, original, clips['faint_start'], 1)
    baseline = {}
    for node in doc['skins'][0]['joints']:
        for property, default in [('translation', [0,0,0]), ('rotation', [0,0,0,1]), ('scale', [1,1,1])]:
            baseline[(node, property)] = doc['nodes'][node].get(property, default)
    rest = copy.deepcopy(baseline)
    baseline.update(idle)
    transferred = []
    if hierarchical_source:
        hierarchy, _ = chunks(hierarchical_source)
        original_names = {n['name']: i for i, n in enumerate(hierarchy['nodes'])}
        flat_names = {n['name']: i for i, n in enumerate(doc['nodes'])}
        parents = {c: i for i, n in enumerate(hierarchy['nodes']) for c in n.get('children', [])}
        for node in doc['skins'][0]['joints']:
            name = doc['nodes'][node]['name']
            if 'eyelid' not in name:
                continue
            reference = parents[original_names[name]]
            while 'eyelid' in hierarchy['nodes'][reference]['name']:
                reference = parents[reference]
            head = flat_names[hierarchy['nodes'][reference]['name']]
            closure = multiply(multiply(trs(baseline, head, doc), inverse(trs(faint, head, doc))), trs(faint, node, doc))
            for property, value in decomposition(closure).items():
                baseline[(node, property)] = value
            transferred.append(name)
    else:
        for (node, property), value in faint.items():
            if 'eyelid' in doc['nodes'][node].get('name', ''):
                baseline[(node, property)] = value
                transferred.append(doc['nodes'][node]['name'])
    breathing_node = doc['skins'][0]['joints'][0]
    if hierarchical_source:
        flat_parents = {c: i for i, n in enumerate(doc['nodes']) for c in n.get('children', [])}
        breathing_node = flat_parents[breathing_node]
        baseline[(breathing_node, 'scale')] = doc['nodes'][breathing_node].get('scale', [1, 1, 1])
        rest[(breathing_node, 'scale')] = doc['nodes'][breathing_node].get('scale', [1, 1, 1])
    binary = bytearray(original)
    for name, pose, duration in [('sleep', baseline, 2.0), ('faint_loop', {**rest, **faint}, 1.0)]:
        animation = {'name': name, 'samplers': [], 'channels': []}
        root = breathing_node
        for (node, property), value in sorted(pose.items()):
            times = [[0.0], [duration]]
            values = [value, value]
            if name == 'sleep' and node == root and property == 'scale':
                times = [[duration * i / 16] for i in range(17)]
                values = [[x * (1 + .006 * math.sin(2 * math.pi * i / 16)) for x in value] for i in range(17)]
            input = append(doc, binary, times, 'SCALAR')
            output = append(doc, binary, values, 'VEC4' if property == 'rotation' else 'VEC3')
            animation['channels'].append({'sampler': len(animation['samplers']), 'target': {'node': node, 'path': property}})
            animation['samplers'].append({'input': input, 'output': output, 'interpolation': 'LINEAR'})
        doc['animations'].append(animation)
    # Exact source mesh/skin/node and native animation metadata preservation.
    for key in ('nodes', 'meshes', 'skins', 'scenes', 'scene'):
        if doc.get(key) != baseline_document.get(key):
            raise ValueError('Proposal changed source geometry')
    if doc['animations'][:-2] != baseline_document['animations'] or binary[:len(original)] != original:
        raise ValueError('Proposal changed a native animation or buffer')
    target.parent.mkdir(parents=True, exist_ok=True)
    write_glb(target, doc, binary)
    return {'source_sha256': sha(source), 'glb_sha256': sha(target), 'eyelid_bones_from_own_faint': sorted(set(transferred)),
            'policy': 'authored rest, frozen native idle plus own faint eyelids and root breathing', 'native_sleep': False,
            'idle_sample_fraction': 0.0, 'sleep_duration': 2.0, 'faint_loop_duration': 1.0, 'native_geometry_and_clips_unchanged': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-root', type=Path, required=True)
    parser.add_argument('--output-name', default='sleep-proposals-v2')
    parser.add_argument('--flattened-motion', action='store_true')
    args = parser.parse_args()
    if Path(args.output_name).name != args.output_name:
        parser.error('Output name must be a single directory name')
    p = args.evidence_root.resolve()
    output = p / args.output_name
    if output.exists():
        raise ValueError('Output already exists; retain previous evidence')
    input = json.loads((p / 'native-detail-v2/status-complete.json').read_text())['entries']
    checkpoint = json.loads(Path(__file__).with_name('catalog_remaining_dlc_material_checkpoint.json').read_text())
    approved = {r['species']: r for r in checkpoint['entries']}
    results = []
    for row in input:
        for variant, spec in row['variants'].items():
            source = Path(spec['path'])
            if sha(source) != approved[row['species']]['variants'][variant]['glb_sha256'] or not approved[row['species']]['appearance_approved']:
                raise ValueError('Source is not the appearance-approved model')
            name = row['species'] + ('-shiny' if variant == 'shiny' else '')
            target = output / name / 'model.glb'
            damage_source = p / 'native-damage-archaludon/model.glb' if row['species'] == 'archaludon' else None
            if damage_source:
                damage_report = json.loads(damage_source.with_name('export.json').read_text())
                damage_job = json.loads(damage_source.with_name('job.json').read_text())
                original_job = json.loads((p / 'material-pairs-v1/archaludon/export/job.json').read_text())
                if (sha(damage_source) != damage_report['glb_sha256']
                    or damage_job['source_sha256'] != original_job['source_sha256']
                    or damage_report['animations']['damage']['source_action'] != 'pm1132_00_00_00500_damage01.001'):
                    raise ValueError('Archaludon native damage provenance differs')
            hierarchical_source = None
            if args.flattened_motion:
                hierarchical_source = source
                source = p / 'flat-approved-v1' / row['species'] / variant / 'model.glb'
                flat_receipt = json.loads(source.with_name('receipt.json').read_text())
                if flat_receipt['approved_source_sha256'] != sha(hierarchical_source) or flat_receipt['glb_sha256'] != sha(source):
                    raise ValueError('Flattened appearance preservation receipt differs')
                damage_source = None
            receipt = propose(source, target, damage_source, hierarchical_source)
            animations = {**row['export']['animations'], 'sleep': {'duration': 2, 'loop': True}, 'faint_loop': {'duration': 1, 'loop': True}}
            if damage_source:
                animations['damage'] = damage_report['animations']['damage']
                receipt['native_damage_recovery_sha256'] = sha(damage_source)
                receipt['native_damage_recovery_reason'] = 'Blender action suffix .001 was excluded by the former exact role-name match'
            if args.flattened_motion:
                export = json.loads((p / 'flat-motion-v1' / row['species'] / 'export.json').read_text())
                animations.update(export['animations'])
                receipt['flattened_motion'] = flat_receipt
            results.append({'species': name, 'status': 'exported_for_review', 'runtime_approved': False, 'path': str(target),
                'glb_sha256': sha(target), 'animations': animations, 'action_timing': {k: {'frames': v['duration'] * 60, 'speed': 1, 'loop': v['loop']} for k,v in animations.items()},
                'placement': {'scale': 1, 'yaw_degrees': 0}, 'complete_pose_channels': True, 'sleep_proposal': receipt})
    (output / 'stage.json').write_text(json.dumps(results, indent=2) + '\n')
    (output / 'catalog.json').write_text(json.dumps({'runtime_approved': False, 'entries': results}, indent=2) + '\n')
    print('Prepared', len(results), 'rest/hold proposals; all original clips and geometry retained')


if __name__ == '__main__':
    main()
