"""Restore source eye textures when a reference palette incorrectly recoloured them.

Review-only: does not decide whether a species has different shiny iris colours.
Normal/shiny input hashes and exact material names are pinned by the caller.
"""
from copy import deepcopy
from pathlib import Path
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from catalog_remaining_native_emission import sha
from phase5_variant_parity import compare


def preserve(row, normal, target):
    for data in [row, normal]:
        if sha(data['path']) != data['glb_sha256']:
            raise ValueError('Eye repair input hash changed')
    document, original = chunks(Path(row['path']))
    source, source_blob = chunks(Path(normal['path']))
    materials = {m['name']: m for m in source['materials']}
    binary = bytearray(original)
    changed = []
    for material in document['materials']:
        if 'eye' not in material['name'].lower():
            continue
        reference = materials[material['name']]
        info = reference.get('pbrMetallicRoughness', {}).get('baseColorTexture')
        if info is None:
            continue
        texture = source['textures'][info['index']]
        view = source['bufferViews'][source['images'][texture['source']]['bufferView']]
        start = view.get('byteOffset', 0)
        target_info = deepcopy(info)
        target_info['index'] = append_png(document, binary,
            source_blob[start:start+view['byteLength']], material['name']+'_source_eye', texture.get('sampler',0))
        material['pbrMetallicRoughness']['baseColorTexture'] = target_info
        changed.append(material['name'])
    if not changed:
        return dict(row, eye_palette_policy='No named eye material; visual eye check remains mandatory')
    target.parent.mkdir(parents=True,exist_ok=False)
    write_glb(target,document,binary)
    return dict(row,path=str(target),glb_sha256=sha(target),
                geometry_motion_sha256=compare(Path(row['path']),target),
                eye_palette_policy='Pinned normal source eye restored; shiny iris differences need visual review',
                eye_materials_restored=changed,runtime_approved=False)
