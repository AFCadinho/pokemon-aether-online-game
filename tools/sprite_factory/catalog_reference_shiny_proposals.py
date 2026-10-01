"""Registered local HOME reference colour transfers, explicitly review proposals.

Preserves geometry, timing, source alpha and image shading. Registration and
palette ambiguity are recorded; this never certifies a shiny colour or model.
"""
import argparse
import colorsys
from concurrent.futures import ThreadPoolExecutor, as_completed
from functools import lru_cache
from io import BytesIO
import json
import hashlib
from pathlib import Path
import re
from statistics import median

from PIL import Image
from catalog_remaining_eye_bake import append_png, chunks, write_glb
from phase5_variant_parity import compare

ROOT=Path(__file__).resolve().parents[2]
ALIASES={'aegislash-shield':'aegislash','keldeo-ordinary':'keldeo','jellicent-male':'jellicent',
         'zygarde-50':'zygarde','pumpkaboo-average':'pumpkaboo','gourgeist-average':'gourgeist'}


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def canonical(name):return re.sub('[^a-z0-9]','',name.lower())


def references(name):
    found=[]
    for variant in ['pokemon_home','pokemon_home_shiny']:
        names={canonical(p.stem):p for p in (ROOT/'assets/sprites/pokemon'/variant).glob('*.png')}
        key=canonical(name)
        if key not in names:key=canonical(ALIASES.get(name,name))
        if key not in names:raise ValueError('Local colour reference absent: '+name)
        found.append(names[key])
    return found


def palette(name):
    refs=references(name);images=[]
    for p in refs:
        im=Image.open(p).convert('RGBA');im=im.crop(im.getchannel('A').getbbox());images.append(im.resize((128,128),Image.Resampling.LANCZOS))
    a,z=[list(im.get_flattened_data()) for im in images]
    overlap=sum(x[3]>200 and y[3]>200 for x,y in zip(a,z))/max(1,sum(x[3]>200 or y[3]>200 for x,y in zip(a,z)))
    if overlap<.78:raise ValueError(f'Reference pose registration is ambiguous: {overlap:.3f}')
    groups={}
    for source,target in zip(a,z):
        if min(source[3],target[3])<=200:continue
        h,s,v=colorsys.rgb_to_hsv(*(float(x)/255 for x in source[:3]))
        if v<.15:continue
        key=(round(h*24)%24,round(s*8)) if s>.12 else (0,0)
        groups.setdefault(key,[]).append((source[:3],target[:3]))
    anchors=[]
    for values in groups.values():
        if len(values)<24:continue
        normal=[median(v[0][i] for v in values) for i in range(3)];shiny=[median(v[1][i] for v in values) for i in range(3)]
        anchors.append({'normal_rgb':normal,'shiny_rgb':shiny,'pixels':len(values),
                        'normal_hsv':list(colorsys.rgb_to_hsv(*(v/255 for v in normal))),
                        'shiny_hsv':list(colorsys.rgb_to_hsv(*(v/255 for v in shiny)))})
    if not anchors:raise ValueError('No stable paired colour anchors')
    return refs,overlap,anchors


def build(row,output):
    name=row['species'];target=output/name/'model.glb'
    try:
        refs,registration,anchors=palette(name)
        source=Path(row['path']);assert sha(source)==row['glb_sha256']
        doc,original=chunks(source);binary=bytearray(original);changed=[]
        @lru_cache(maxsize=100000)
        def colour(pixel):
            if pixel[3]<16:return pixel
            h,s,v=colorsys.rgb_to_hsv(*(x/255 for x in pixel[:3]))
            if v<.10:return pixel
            def distance(anchor):
                ah,ass,av=anchor['normal_hsv'];dh=min(abs(h-ah),1-abs(h-ah))
                return (dh*3 if min(s,ass)>.12 else 0)**2+(s-ass)**2+((v-av)*.2)**2
            anchor=min(anchors,key=distance)
            if distance(anchor)>.16:return pixel
            nh,ns,nv=anchor['normal_hsv'];sh,ss,sv=anchor['shiny_hsv']
            if s>.12 and ns>.12:
                delta=(sh-nh+.5)%1-.5;hh=(h+delta)%1
            else:hh=sh
            hsv=(hh,max(0,min(1,s+(ss-ns))),max(0,min(1,v*(sv/max(nv,.1)))))
            return (*[round(x*255) for x in colorsys.hsv_to_rgb(*hsv)],pixel[3])
        for material in doc['materials']:
            if 'eye' in material['name'].lower():continue
            info=material.get('pbrMetallicRoughness',{}).get('baseColorTexture')
            if not info:continue
            texture=doc['textures'][info['index']];image=doc['images'][texture['source']]
            view=doc['bufferViews'][image['bufferView']];start=view.get('byteOffset',0)
            im=Image.open(BytesIO(original[start:start+view['byteLength']])).convert('RGBA')
            proposal=Image.new('RGBA',im.size);proposal.putdata([colour(p) for p in im.get_flattened_data()])
            if im.tobytes()==proposal.tobytes():continue
            assert im.getchannel('A').tobytes()==proposal.getchannel('A').tobytes()
            packed=BytesIO();proposal.save(packed,format='PNG')
            info['index']=append_png(doc,binary,packed.getvalue(),material['name']+'_reference_shiny',texture.get('sampler',0))
            changed.append(material['name'])
        if not changed:raise ValueError('Reference transfer produced no visible texture changes')
        target.parent.mkdir(exist_ok=False);write_glb(target,doc,binary)
        proof={'species':name,'status':'exported_for_review','path':str(target),'glb_sha256':sha(target),
               'normal_glb_sha256':sha(source),'geometry_motion_sha256':compare(source,target),
               'alpha_unchanged':True,'runtime_approved':False,'method':'registered_home_hsv_transfer_review_v1',
               'registration_iou':float(registration),'anchors':anchors,'changed_materials':changed,
               'references':[{'path':str(p),'sha256':sha(p)} for p in refs],
               'limitations':'Reference shading and spatial registration are approximations; final visual colour qualification is mandatory'}
        target.with_suffix('.receipt.json').write_text(json.dumps(proof,indent=2)+'\n');return proof
    except Exception as error:return {'species':name,'status':'held','reason':str(error),'runtime_approved':False}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--stage',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    output=args.output.resolve();output.mkdir(exist_ok=False);rows=json.loads(args.stage.read_text());results=[]
    with ThreadPoolExecutor(max_workers=2) as pool:
        jobs=[pool.submit(build,row,output) for row in rows]
        for future in as_completed(jobs):
            result=future.result();results.append(result)
            (output/'status.json').write_text(json.dumps({'total':len(rows),'processed':len(results),'runtime_approved':False,'entries':results},indent=2)+'\n')
            print(result['species'],result['status'],result.get('reason',''),flush=True)
