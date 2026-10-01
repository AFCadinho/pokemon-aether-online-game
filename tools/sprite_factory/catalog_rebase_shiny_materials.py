"""Reapply a pinned review palette after source motion repair; UVs must match exactly."""
from copy import deepcopy
from pathlib import Path
import hashlib
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from catalog_remaining_native_emission import sha
from phase5_variant_parity import compare


def uv_signature(doc,blob):
    result=[]
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            accessor=doc['accessors'][primitive['attributes']['TEXCOORD_0']]
            view=doc['bufferViews'][accessor['bufferView']]
            start=view.get('byteOffset',0)
            result.append((doc['materials'][primitive['material']]['name'],
                           {k:v for k,v in accessor.items() if k!='bufferView'},
                           {k:v for k,v in view.items() if k not in ['byteOffset','buffer']},
                           hashlib.sha256(blob[start:start+view['byteLength']]).hexdigest()))
    return result


def rebase(normal,palette,target):
    for row in [normal,palette]:
        if sha(row['path'])!=row['glb_sha256']:raise ValueError('Pinned material/motion input changed')
    doc,original=chunks(Path(normal['path']));colour,colours=chunks(Path(palette['path']))
    if uv_signature(doc,original)!=uv_signature(colour,colours):
        raise ValueError('Motion repair changed UV/material domains; independent colour bake required')
    named={m['name']:m for m in colour['materials']};blob=bytearray(original)
    def texture(info):
        source=colour['textures'][info['index']];view=colour['bufferViews'][colour['images'][source['source']]['bufferView']];start=view.get('byteOffset',0)
        samplers=doc.setdefault('samplers',[]);samplers.append(deepcopy(colour.get('samplers',[{}])[source.get('sampler',0)]))
        result=deepcopy(info);result['index']=append_png(doc,blob,colours[start:start+view['byteLength']],'pinned_review_palette',len(samplers)-1);return result
    for material in doc['materials']:
        source=named[material['name']]
        for key in ['baseColorTexture','metallicRoughnessTexture']:
            if key in source.get('pbrMetallicRoughness',{}):material['pbrMetallicRoughness'][key]=texture(source['pbrMetallicRoughness'][key])
        for key in ['normalTexture','emissiveTexture','occlusionTexture']:
            if key in source:material[key]=texture(source[key])
        for key in ['emissiveFactor','alphaMode','alphaCutoff','doubleSided','extensions']:
            if key in source:material[key]=deepcopy(source[key])
    target.parent.mkdir(parents=True,exist_ok=False);write_glb(target,doc,blob)
    return dict(normal,species=normal['species']+'-shiny',path=str(target),glb_sha256=sha(target),
                geometry_motion_sha256=compare(Path(normal['path']),target),
                palette_input_sha256=palette['glb_sha256'],normal_input_sha256=normal['glb_sha256'],
                uv_domains_byte_identical=True,runtime_approved=False)
