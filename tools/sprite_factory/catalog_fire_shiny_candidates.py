"""Authored local-reference fire shiny proposals; never catalog admission."""
import copy
import colorsys
import hashlib
import io
import json
import sys
from pathlib import Path
from PIL import Image
from catalog_remaining_eye_bake import chunks

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'.tmp/remaining-142-production'

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    work=BASE/('fire-shiny-'+(sys.argv[1] if len(sys.argv)>1 else 'v1'));work.mkdir(exist_ok=False)
    source_job=BASE/'fire-live-preview-v1/job-inline-v9.json'
    job=json.loads(source_job.read_text());job['output']=str(work/'runtime')
    normal=copy.deepcopy(job['entries']);shiny=[];proof=[]
    for row in normal:
        name=row['species'];entry=copy.deepcopy(row)
        entry.update(species=name+'@shiny',variant='shiny',appearance_approved=False)
        reference=ROOT/'assets/sprites/pokemon/pokemon_home_shiny'/f'{name}.png'
        assert reference.is_file()
        changes=[]
        if name in ['ponyta','rapidash']:
            edge,core=(([.015,.24,.4],[.02,.42,.7]) if name=='ponyta' else
                       ([.16,.13,.24],[.35,.31,.45]))
            for material in entry['fire_materials']:
                material['fire_edge']=edge;material['fire_core']=core
        else:
            assert sha(row['path']) == row['glb_sha256']
            document,binary=chunks(Path(row['path']))
            entry['body_materials']=[]
            for material in document['materials']:
                if material['name'] not in ['BodyA','BodyAVco','BodyAInc']:continue
                texture=document['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]
                view=document['bufferViews'][document['images'][texture['source']]['bufferView']]
                offset=view.get('byteOffset',0)
                original=Image.open(io.BytesIO(binary[offset:offset+view['byteLength']])).convert('RGBA')
                image=original.copy();changed=0
                for y in range(image.height):
                    for x in range(image.width):
                        r,g,b,a=original.getpixel((x,y));h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
                        # Back/legs occupy the brown outer atlas, while the red
                        # head, central heated belly strip and yellow rings stay.
                        if (x < image.width*.35 or x > image.width*.65) and .0 < h < .09 and .2 < s < .8 and .05 < v < .6:
                            rgb=tuple(round(z*255) for z in colorsys.hsv_to_rgb(.51,.55,min(1,v*1.7)))
                            image.putpixel((x,y),(*rgb,a));changed+=1
                assert changed>0
                assert image.getchannel('A').tobytes()==original.getchannel('A').tobytes()
                assert image.crop((round(image.width*.35),0,round(image.width*.65),image.height)).tobytes()==original.crop((round(image.width*.35),0,round(image.width*.65),image.height)).tobytes()
                target=work/(material['name']+'-shiny.png');image.save(target)
                entry['body_materials'].append({'material':material['name'],'source_rgba_hex_sha256':hashlib.sha256(original.tobytes().hex().encode()).hexdigest(),'texture':{'path':str(target),'sha256':sha(target)}})
                changes.append({'material':material['name'],'changed_pixels':changed,'alpha_unchanged':True,'central_belly_strip_unchanged':True})
        if name == 'rapidash':
            assert sha(row['path']) == row['glb_sha256']
            document,binary=chunks(Path(row['path']))
            material=next(m for m in document['materials'] if m['name']=='Eye')
            texture=document['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]
            view=document['bufferViews'][document['images'][texture['source']]['bufferView']]
            offset=view.get('byteOffset',0)
            original=Image.open(io.BytesIO(binary[offset:offset+view['byteLength']])).convert('RGBA')
            image=original.copy();changed=0
            for y in range(image.height):
                for x in range(image.width):
                    r,g,b,a=original.getpixel((x,y));h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
                    if (h < .05 or h > .95) and s > .45 and v > .12:
                        rgb=tuple(round(z*255) for z in colorsys.hsv_to_rgb(.60,.45,v))
                        image.putpixel((x,y),(*rgb,a));changed+=1
            assert changed>0
            assert image.getchannel('A').tobytes()==original.getchannel('A').tobytes()
            target=work/'rapidash-Eye-shiny.png';image.save(target)
            entry['body_materials']=[{'material':'Eye','source_rgba_hex_sha256':hashlib.sha256(original.tobytes().hex().encode()).hexdigest(),'texture':{'path':str(target),'sha256':sha(target)}}]
            changes.append({'material':'Eye','changed_iris_pixels':changed,'alpha_unchanged':True})
        shiny.append(entry)
        proof.append({'species':name,'reference_sha256':sha(reference),'body_changes':changes,'authored_shiny':True,'appearance_approved':False,'runtime_approved':False})
    job['entries']=normal+shiny
    (work/'job.json').write_text(json.dumps(job,indent=2)+'\n')
    (work/'palette-receipt.json').write_text(json.dumps({'source_job_sha256':sha(source_job),'entries':proof,'worker_sha256':sha(Path(__file__))},indent=2)+'\n')
    print(work/'job.json')

if __name__=='__main__':main()
