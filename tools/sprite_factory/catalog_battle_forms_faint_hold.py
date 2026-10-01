"""Freeze an own-rig faint endpoint; preserve native geometry/materials."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
from catalog_remaining_eye_bake import chunks, write_glb
from catalog_dlc_sleep_proposals import sample, append


def build(source, output):
    doc, raw = chunks(source)
    before = copy.deepcopy(doc)
    binary = bytearray(raw)
    start = next(a for a in doc['animations'] if a['name'] == 'faint_start')
    pose = sample(doc, binary, start, 1.)
    hold = dict(name='faint_loop', samplers=[], channels=[])
    for (node, prop), value in sorted(pose.items()):
        times = append(doc, binary, [[0.], [1.]], 'SCALAR')
        values = append(doc, binary, [value, value], 'VEC4' if prop == 'rotation' else 'VEC3')
        hold['channels'].append(dict(sampler=len(hold['samplers']), target=dict(node=node, path=prop)))
        hold['samplers'].append(dict(input=times, output=values, interpolation='LINEAR'))
    doc['animations'] = [hold if a['name'] == 'faint_loop' else a for a in doc['animations']]
    for key in ('nodes', 'meshes', 'skins', 'materials', 'textures', 'images'):
        if doc.get(key) != before.get(key):
            raise ValueError('Hold changed appearance or geometry')
    assert binary[:len(raw)] == raw
    output.parent.mkdir(parents=True, exist_ok=False)
    write_glb(output, doc, binary)
    receipt = dict(source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        glb_sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
        duration=1., native_faint=False,
        policy='Constant own-rig hold at exact faint_start endpoint; battle review required')
    output.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('source', type=Path)
    p.add_argument('output', type=Path)
    args = p.parse_args()
    print(json.dumps(build(args.source, args.output)))
