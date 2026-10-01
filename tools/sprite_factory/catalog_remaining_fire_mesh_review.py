"""Make a review-only static fire approximation from pinned real-mesh bakes."""
import copy
import hashlib
from io import BytesIO
import json
from pathlib import Path
import sys
from PIL import Image
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from phase5_variant_parity import compare

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / '.tmp/remaining-142-production'


def main(name, batch='fire-mesh-colour-v6'):
    work = BASE / batch / name
    job = json.loads((work/'job.json').read_text())
    source = BASE / 'native-materials-v2' / name / 'model.glb'
    pinned = {'ponyta':'f0af3c62ad2959466ac7cfa05b79e085e7d3063e452d4773160048baa5db18e2',
              'rapidash':'e6669b6be642bc82feb3b3c6e7cdab7e68fb7bc16eab91ba6dbc1aa01bd40cd6'}
    assert hashlib.sha256(source.read_bytes()).hexdigest() == pinned[name]
    document, binary = chunks(source)
    binary = bytearray(binary)
    changes = []
    for item in job['materials']:
        mat = next(m for m in document['materials'] if m['name'] == item['name'])
        colour = Image.open(item['output']).convert('RGBA')
        glow = Image.open(item['glow_output']).convert('RGB')
        pixels = []
        for c,g in zip(colour.getdata(), glow.getdata()):
            intensity = max(g)/255
            # Review adaptation: transparent outer fire instead of opaque black
            # generated-noise shells. This is not an official source alpha map.
            a = c[3] * intensity
            # The mesh worker normalizes HDR emission before PNG encoding.
            # Authored warm ramp: retain actual source opacity/noise details;
            # low-opacity tips are red/orange, dense inner flame is yellow.
            density = a/255
            rgb = (255, round(50+185*density), round(25*density*density))
            pixels.append((*[min(255,x) for x in rgb], round(a)))
        colour.putdata(pixels)
        packed = BytesIO(); colour.save(packed,format='PNG')
        pbr = mat['pbrMetallicRoughness'];old = pbr.get('baseColorTexture',{})
        sampler = document['textures'][old['index']].get('sampler',0)
        tex={'index':append_png(document,binary,packed.getvalue(),item['name']+'_mesh_fire_review',sampler)}
        x0,y0,x1,y1=item.get('source_uv_domain',[0,0,1,1])
        if [x0,y0,x1,y1]!=[0,0,1,1]:
            tex['extensions']={'KHR_texture_transform':{'offset':[-x0/(x1-x0),(y1-1)/(y1-y0)],'scale':[1/(x1-x0),1/(y1-y0)]}}
        pbr.update(baseColorTexture=tex,baseColorFactor=[1,1,1,1],metallicFactor=0,roughnessFactor=1)
        mat.pop('emissiveTexture',None);mat.pop('emissiveFactor',None)
        mat['extensions']={'KHR_materials_unlit':{}}
        mat.update(alphaMode='BLEND',doubleSided=True)
        mat.pop('alphaCutoff',None)
        changes.append(item['name'])
    used=document.setdefault('extensionsUsed',[])
    if 'KHR_materials_unlit' not in used:used.append('KHR_materials_unlit')
    target=work/'model.glb';write_glb(target,document,binary)
    parity=compare(source,target)
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    row=copy.deepcopy(next(r for r in json.loads((BASE/'fire-unlit-v3/stage.json').read_text()) if r['species']==name))
    row.update(path=str(target),glb_sha256=sha(target),runtime_approved=False,appearance_approved=False,attention='Static mesh-context fire approximation; user review pending')
    (work/'stage.json').write_text(json.dumps([row],indent=2)+'\n')
    receipt={'species':name,'runtime_approved':False,'source_sha256':sha(source),'glb_sha256':sha(target),'geometry_motion_parity':parity,'materials':changes,'bake_job_sha256':sha(work/'job.json'),'bake_receipt_sha256':sha(work/'receipt.json'),'method':'real-source-mesh bake; authored warm flame ramp; explicit core opacity graph evaluated on outer source mesh','limitations':['procedural time variation not reproduced','authored colour ramp and outer opacity require visual acceptance']}
    (work/'review-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(name,sha(target),parity)


if __name__=='__main__': main(sys.argv[1])
