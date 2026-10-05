"""Source-bound regional eye corrections; preserve approved body and geometry."""
import copy
import json
import struct
from pathlib import Path
from io import BytesIO
from PIL import Image
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from catalog_remaining_eye_audit import embedded_image
from catalog_galar_birds_candidates import sha
from phase5_variant_parity import signature
from scvi_material_probe import inspect_materials

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'.tmp/regional-production-v1'


def bounds(doc,binary,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    assert a['componentType']==5126 and a['type']=='VEC2'
    start=v.get('byteOffset',0)+a.get('byteOffset',0)
    uv=[struct.unpack_from('<2f',binary,start+i*v.get('byteStride',8))for i in range(a['count'])]
    return [min(p[j]for p in uv)for j in range(2)]+[max(p[j]for p in uv)for j in range(2)]


def main():
    output=WORK/'eyes-followup-v2';output.mkdir(exist_ok=False)
    current=json.loads((WORK/'runtime-final-v2.json').read_text())
    source={r['species']:r for r in json.loads((ROOT/'tools/sprite_factory/regional_model_source_intake.json').read_text())['entries']}
    audit=[];stage=[]
    for row in current:
        row=copy.deepcopy(row);name=row['species'];base=name.removesuffix('-shiny')
        path=Path(row['path']);assert sha(path)==row['glb_sha256']
        doc,data=chunks(path);binary=bytearray(data);before=copy.deepcopy(doc['materials']);changes=[]
        for spec in row.get('eye_motion',{}).get('materials',[]):
            material=next(m for m in doc['materials']if m['name']==spec['material'])
            ranges=[bounds(doc,binary,p['attributes']['TEXCOORD_0'])for mesh in doc['meshes']for p in mesh['primitives']if doc['materials'][p['material']]['name']==spec['material']]
            defaults=spec['defaults']['UVScaleOffset'];sx,sy,tx,ty=defaults
            transforms=[defaults]+[v for clip in spec['clips'].values() for _,v in clip['parameters']['UVScaleOffset']]
            outside=any(b[0]*sx+tx<-.001 or b[1]*sy+ty<-.001 or b[2]*sx+tx>1.001 or b[3]*sy+ty>1.001
                        for sx,sy,tx,ty in transforms for b in ranges)
            record={'species':name,'material':spec['material'],'uv_ranges':ranges,'repeat_before':spec['repeat_uv'],'outside_domain_during_source_clips':outside}
            if outside and not spec['repeat_uv']:
                # Native GLB textures repeat; the eye-motion pack had replaced
                # that sampler with clamp, sampling only the blank edge.
                texture=doc['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]
                sampler=doc.get('samplers',[{}])[texture.get('sampler',0)]
                assert sampler.get('wrapS',10497)==10497 and sampler.get('wrapT',10497)==10497
                spec['repeat_uv']=True;changes.append(spec['material']+':restore_native_repeat')
            audit.append(record)
        if base=='arcanine-hisui':
            s=source[base];table=next(Path(s['source_root'])/r['path']for r in s['scvi_files']if r['path'].endswith(s['resource']+('_rare.trmtr'if name.endswith('-shiny')else'.trmtr')))
            assert sha(table)==row['material_table_sha256'], 'Source eye table changed'
            official={r['name']:r for r in inspect_materials(table)}
            for material in doc['materials']:
                if material['name']not in {'l_eye','r_eye'}:continue
                src=official[material['name']];mask=Image.open(table.parent/Path(src['textures']['LayerMaskMap']).with_suffix('.png')).convert('RGBA')
                channels=mask.split();pbr=material['pbrMetallicRoughness'];maps=[]
                for key in ['Roughness','Metallic']:
                    im=Image.new('L',mask.size,round(src['floats'][key]*255))
                    for i,ch in enumerate(channels,1):
                        value=src['floats'].get(key+'Layer'+str(i),src['floats'][key]);scale=src['floats'].get('LayerMaskScale'+str(i),1)
                        im=Image.composite(Image.new('L',mask.size,round(value*255)),im,ch.point(lambda v:min(255,round(v*2*scale))))
                    maps.append(im)
                image=Image.merge('RGB',(Image.new('L',mask.size,255),*maps));packed=BytesIO();image.save(packed,format='PNG')
                index=append_png(doc,binary,packed.getvalue(),material['name']+'_source_roughness_metallic',0)
                pbr.update(metallicRoughnessTexture={'index':index},metallicFactor=1,roughnessFactor=1)
                assert embedded_image(doc,binary,pbr['baseColorTexture']['index']).getchannel('A').getextrema()==(255,255)
                material['alphaMode']='OPAQUE'
                changes.append(material['name']+':source_layer_surface_properties')
        if changes:
            target=output/(name+'.glb');write_glb(target,doc,binary)
            assert signature(target)==signature(path)
            for old,new in zip(before,doc['materials']):
                if old!=new:assert base=='arcanine-hisui'and old['name']in {'l_eye','r_eye'}
            row['path']=str(target);row['glb_sha256']=sha(target)
            for key in ['eye_motion','visibility']:
                if key in row:row[key]['glb_sha256']=row['glb_sha256']
            row.pop('runtime_path',None);row.pop('runtime_sha256',None)
            row['regional_eye_followup']={'input_sha256':sha(path),'changes':changes,'geometry_motion_unchanged':True,'body_materials_unchanged':True}
            stage.append(row)
    (output/'stage.json').write_text(json.dumps(stage,indent=2)+'\n')
    (output/'audit.json').write_text(json.dumps({'runtime_approved':False,'variants_audited':len(current),'native_eye_materials':audit,'changed_variants':[r['species']for r in stage]},indent=2)+'\n')
    print('Variants for rerender:',[r['species']for r in stage])


if __name__=='__main__':main()
