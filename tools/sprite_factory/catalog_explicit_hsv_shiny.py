"""Source-pinned explicit local-reference hue recipes for offline shiny review.

Rules are supplied by the caller, not inferred from mismatched reference poses.
Every alpha byte, mesh, skin, animation and texture UV remains unchanged.
"""
import colorsys
from functools import lru_cache
from io import BytesIO
import json
from pathlib import Path
from PIL import Image
from catalog_reference_shiny_proposals import references, sha
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from phase5_variant_parity import compare


def transfer(image, rules, *, minimum_saturation=.18, dark_value_floor=.15, neutral_maximum_saturation=.12):
    if not 0 <= minimum_saturation <= 1:
        raise ValueError("Invalid source saturation threshold")
    if not 0 <= neutral_maximum_saturation <= 1:
        raise ValueError("Invalid neutral saturation limit")
    if not 0 <= dark_value_floor <= 1:
        raise ValueError("Invalid dark colour floor")
    for rule in rules:
        if len(rule) not in (4,6) or not all(isinstance(v, (int,float)) for v in rule[2:]):
            raise ValueError('Expected an explicit hue or neutral rule')
        if rule[0] not in ('neutral','dark-neutral','dark-to-white') and not (0 <= rule[0] < rule[1] <= 1.10):
            raise ValueError('Invalid hue window')
        if len(rule)==6 and not 0 <= rule[4] <= rule[5] <= 1:
            raise ValueError('Invalid source value interval')
        if not 0 <= rule[2] <= 1 or not 0 <= rule[3] <= 1:
            raise ValueError('Invalid target hue or saturation')
    @lru_cache(maxsize=65536)
    def colour(p):
        if p[3] < 16:
            return p
        h,s,v=colorsys.rgb_to_hsv(*(x/255 for x in p[:3]))
        for rule in rules:
            low,high,target,sat=rule[:4]
            neutral=low in ('neutral','dark-neutral','dark-to-white')
            match=((v<.25 if low=='dark-to-white' else v<.5 if low=='dark-neutral' else s<neutral_maximum_saturation)) if neutral else (v>=.12 and s>minimum_saturation and low<=h+(1 if h<.08 and high>1 else 0)<=high)
            if len(rule)==6:match=match and rule[4]<=v<=rule[5]
            if match:
                value=(1-v*.4 if low=='dark-to-white' else max(v,dark_value_floor) if low=='dark-neutral' else v)
                return (*[round(x*255) for x in colorsys.hsv_to_rgb(target,sat if neutral else min(1,s*sat/.65),value)],p[3])
        return p
    out=Image.new('RGBA',image.size)
    out.putdata([colour(p) for p in image.convert('RGBA').get_flattened_data()])
    return out


def build(row, rules, output):
    source=Path(row['path'])
    if sha(source)!=row['glb_sha256']:
        raise ValueError('Pinned source changed')
    doc,original=chunks(source);binary=bytearray(original);changed=[]
    for material in doc['materials']:
        if 'eye' in material['name'].lower() and material['name'] not in row.get('include_eye_materials',[]):
            continue
        info=material.get('pbrMetallicRoughness',{}).get('baseColorTexture')
        if not info:
            continue
        tex=doc['textures'][info['index']]
        view=doc['bufferViews'][doc['images'][tex['source']]['bufferView']]
        offset=view.get('byteOffset',0)
        image=Image.open(BytesIO(original[offset:offset+view['byteLength']])).convert('RGBA')
        proposal=transfer(image,row.get('material_rules',{}).get(material['name'],rules), minimum_saturation=row.get('palette_minimum_saturation', .18),dark_value_floor=row.get('dark_value_floor',.15),neutral_maximum_saturation=row.get('neutral_maximum_saturation',.12))
        if proposal.tobytes()==image.tobytes():
            continue
        assert proposal.getchannel('A').tobytes()==image.getchannel('A').tobytes()
        png=BytesIO();proposal.save(png,format='PNG')
        info['index']=append_png(doc,binary,png.getvalue(),material['name']+'_explicit_reference_shiny',tex.get('sampler',0))
        changed.append(material['name'])
    if not changed:
        raise ValueError('Explicit recipe matched no source colour pixels')
    target=output/row['species']/'model.glb'
    target.parent.mkdir(parents=True,exist_ok=False)
    write_glb(target,doc,binary)
    result={'species':row['species'],'path':str(target),'glb_sha256':sha(target),
            'normal_glb_sha256':sha(source),'geometry_motion_sha256':compare(source,target),
            'alpha_unchanged':True,'runtime_approved':False,
            'method':'explicit_local_reference_palette_proposal_v1','rules':rules,
            'minimum_saturation':row.get('palette_minimum_saturation', .18),'dark_value_floor':row.get('dark_value_floor',.15),'neutral_maximum_saturation':row.get('neutral_maximum_saturation',.12),'material_rules':row.get('material_rules',{}),'include_eye_materials':row.get('include_eye_materials',[]),'changed_materials':changed,'references':[{'path':str(p),'sha256':sha(p)} for p in references(row['species'])]}
    target.with_suffix('.receipt.json').write_text(json.dumps(result,indent=2)+'\n')
    return result
