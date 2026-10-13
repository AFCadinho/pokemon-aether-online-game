"""Bake legacy surface graphs over their actual exported UV domains."""
import argparse,struct
from pathlib import Path
from remaining_twenty_one import WORK,HERE,read,write,sha,flat
from catalog_remaining_eye_bake import chunks,append_png,write_glb
from PIL import Image


def bake(name):
    place=WORK/'legacy'/name;job=read(place/'job.json');doc,binary=chunks(place/'model.glb')
    out=WORK/'graph-bake'/name;out.mkdir(parents=True,exist_ok=True)
    material_uv={i:[] for i in range(len(doc['materials']))}
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            index=primitive['attributes'].get('TEXCOORD_0')
            if index is None:continue
            accessor=doc['accessors'][index];view=doc['bufferViews'][accessor['bufferView']]
            assert accessor['componentType']==5126 and accessor['type']=='VEC2'
            offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
            material_uv[primitive['material']].extend(struct.unpack_from('<2f',binary,offset+i*view.get('byteStride',8)) for i in range(accessor['count']))
    materials=[]
    for i,m in enumerate(doc['materials']):
        uv=material_uv[i];assert uv
        u0=min(u for u,v in uv);u1=max(u for u,v in uv);v0=min(v for u,v in uv);v1=max(v for u,v in uv)
        if u1-u0<1e-5:u0=0;u1=1
        if v1-v0<1e-5:v0=0;v1=1
        materials.append({'name':m['name'],'output':str(out/f'{i}-colour.png'),'glow_output':str(out/f'{i}-glow.png'),
            'source_uv_domain':[u0,1-v1,u1,1-v0],'gltf_uv_bounds':[u0,v0,u1,v1]})
    spec={'source':job['source'],'source_sha256':job['source_sha256'],'idle_action':job['actions']['idle'],
        'materials':materials,'receipt':str(out/'receipt.json'),'constant_colour_review':True,'static_fresnel_colour_review':True,'bake_resolution':1024}
    if job.get('diagnostic_rig_selection'):spec['diagnostic_rig_selection']=job['diagnostic_rig_selection']
    if not (out/'receipt.json').exists():flat('catalog_animation_material_worker.py',spec,out)
    receipts=read(out/'receipt.json')
    for m,item,receipt in zip(doc['materials'],materials,receipts,strict=True):
        old=m.get('pbrMetallicRoughness',{}).get('baseColorTexture',{})
        u0,v0,u1,v1=item['gltf_uv_bounds']; transform={'scale':[1/(u1-u0),1/(v1-v0)],'offset':[-u0/(u1-u0),-v0/(v1-v0)]}
        def texture(path):
            return {'index':append_png(doc,binary,Path(path).read_bytes(),m['name']+'-graph',0),'extensions':{'KHR_texture_transform':transform}}
        m['pbrMetallicRoughness']={'baseColorTexture':texture(item['output']),'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.55}
        m.pop('emissiveTexture',None);m.pop('emissiveFactor',None)
        m.pop('normalTexture',None)
        if receipt.get('emission_output'):
            m['emissiveTexture']=texture(item['glow_output']);m['emissiveFactor']=[1,1,1]
            m.setdefault('extensions',{})['KHR_materials_emissive_strength']={'emissiveStrength':receipt['emission_strength']}
        im=Image.open(item['output']).convert('RGBA')
        m['alphaMode']='BLEND' if im.getchannel('A').getextrema()[0]<255 else 'OPAQUE'
    if 'KHR_texture_transform' not in doc.setdefault('extensionsUsed',[]):doc['extensionsUsed'].append('KHR_texture_transform')
    write_glb(out/'model.glb',doc,binary)
    write(out/'result.json',{'runtime_approved':False,'source_glb_sha256':sha(place/'model.glb'),'baked_glb_sha256':sha(out/'model.glb'),'materials':materials})
    print('GRAPH_BAKED',name,flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('names',nargs='+');a=p.parse_args()
    errors=[]
    for n in a.names:
        try:bake(n)
        except Exception as e:errors.append(n);print('BAKE_FAIL',n,str(e),flush=True)
    if errors:raise SystemExit(1)
