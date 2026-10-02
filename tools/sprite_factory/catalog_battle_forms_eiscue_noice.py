"""Select the bare head and antenna from Eiscue's shared source mesh bank."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
from catalog_remaining_eye_bake import chunks, write_glb


def build(source, output):
    doc, binary = chunks(source)
    original = copy.deepcopy(doc)
    excluded = []
    for node in doc['nodes']:
        name = node.get('name', '')
        if name.endswith(('_antenna_a_mesh', '_headice_a_mesh', '_headice_b_mesh',
                          '_ice_a_mesh', '_ice_b_mesh', '_ice_c_mesh', '_ice_d_mesh')):
            if 'mesh' in node:
                excluded.append(name)
                node.pop('mesh')
                node.pop('skin', None)
    retained = [n.get('name', '') for n in doc['nodes'] if 'mesh' in n]
    if len(excluded) != 7 or not all(any(n.endswith(s) for n in retained)
        for s in ('_antenna_b_mesh', '_head_mesh', '_eye_mesh', '_body_mesh')):
        raise ValueError('Unexpected Eiscue source mesh identities')
    for key in ('meshes', 'skins', 'materials', 'textures', 'images', 'animations'):
        assert doc.get(key) == original.get(key), key
    output.parent.mkdir(parents=True, exist_ok=False)
    write_glb(output, doc, binary)
    receipt = dict(source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        glb_sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
        excluded=excluded, retained=retained,
        policy='Explicit Noice form mesh selection from shared source; animation, rig and material data unchanged; appearance review required')
    output.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('source', type=Path)
    p.add_argument('output', type=Path)
    args=p.parse_args()
    print(json.dumps(build(args.source,args.output)))
