"""Apply native palettes to bound meshes only, retaining unselected material uses."""
import copy
from pathlib import Path
from alternate_forms_batch import WORK, SOURCE, read, write, sha, material
from alternate_forms_material_sources import prepare
from alternate_forms_palettes import apply
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from phase5_variant_parity import compare


def build(row):
    base_row = {k:v for k,v in row.items() if k != 'material_selector'}
    prepared = prepare(base_row)
    table = next(SOURCE/r['path'] for r in prepared['scvi_files'] if r['path'].endswith(row['resource']+'.trmtr'))
    directory = table.parent
    selected = WORK/'material-palettes'/row['species'];selected.mkdir(parents=True,exist_ok=True)
    selector = Path(row['material_selector']['path']);assert sha(selector)==row['material_selector']['sha256']
    proofs=[]
    for path in directory.iterdir():
        if path.suffix=='.trmtr':continue
        target=selected/path.name
        if not target.exists():target.symlink_to(path)
    for variant in ('normal','rare'):
        filename=row['resource']+('_rare' if variant=='rare' else '')+'.trmtr'
        proofs.append(apply(directory/filename,selector,variant,row['material_selector']['index'],selected/filename))
    default_work = WORK/'unselected-palettes'
    link=default_work/'export'/row['species'];link.parent.mkdir(parents=True,exist_ok=True)
    if not link.exists():link.symlink_to(WORK/'export'/row['species'],target_is_directory=True)
    original=material(prepared,SOURCE,default_work)
    prepared['scvi_files']=[{**r,'path':str(selected/Path(r['path']).name),'sha256':sha(selected/Path(r['path']).name),
        'bytes':(selected/Path(r['path']).name).stat().st_size} if Path(r['path']).suffix=='.trmtr' else r for r in prepared['scvi_files']]
    result=material(prepared,SOURCE,WORK)
    for v,default,proof in zip(result['variants'],original['variants'],proofs,strict=True):
        doc,blob=chunks(Path(v['path']));before,binary=chunks(Path(default['path']))
        assert len(doc['materials'])==len(before['materials'])
        bindings={}
        for mesh,name,parameter,_ in proof['bindings']:
            if parameter not in ('BaseColorLayer1','BaseColorLayer2','BaseColorLayer3','BaseColorLayer4'):
                raise ValueError('Palette repair covers base colour only')
            bindings.setdefault(name,set()).add(mesh.removesuffix('_shape'))
        restored=[];seen={name:set() for name in bindings}
        for node in doc['nodes']:
            if 'mesh' not in node:continue
            for primitive in doc['meshes'][node['mesh']]['primitives']:
                index=primitive['material'];m=doc['materials'][index];name=m['name']
                if name not in bindings:continue
                if node['name'] in bindings[name]:seen[name].add(node['name']);continue
                source=before['materials'][index]
                assert source['name']==name
                clone=copy.deepcopy(m);clone['name']=name+'_unselected_'+node['name']
                info=source['pbrMetallicRoughness']['baseColorTexture'];t=before['textures'][info['index']]
                view=before['bufferViews'][before['images'][t['source']]['bufferView']];start=view.get('byteOffset',0)
                png=binary[start:start+view['byteLength']]
                sampler=doc['textures'][m['pbrMetallicRoughness']['baseColorTexture']['index']].get('sampler',0)
                clone['pbrMetallicRoughness']['baseColorTexture']={**info,'index':append_png(doc,blob,png,clone['name'],sampler)}
                primitive['material']=len(doc['materials']);doc['materials'].append(clone)
                restored.append({'mesh':node['name'],'material':name,'source_png_sha256':__import__('hashlib').sha256(png).hexdigest()})
        assert seen==bindings,'Unknown native palette target'
        path=Path(v['path']);write_glb(path,doc,blob)
        # Restore only the declared material splits for exact geometry/motion proof.
        restored_doc=copy.deepcopy(doc)
        for node in restored_doc['nodes']:
            if 'mesh' not in node:continue
            for primitive in restored_doc['meshes'][node['mesh']]['primitives']:
                if primitive['material']>=len(before['materials']):
                    clone_name=restored_doc['materials'][primitive['material']]['name']
                    source_name=clone_name.split('_unselected_')[0]
                    primitive['material']=next(i for i,m in enumerate(before['materials']) if m['name']==source_name)
        parity=path.with_name('material-split-parity.glb');write_glb(parity,restored_doc,bytearray(blob))
        compare(Path(default['path']),parity)
        v['glb_sha256']=sha(path)
        for field in ('visibility','eye_motion','material_effects'):
            if field in v:v[field]['glb_sha256']=v['glb_sha256']
        v['mesh_palette_restoration']=restored
        proof['unbound_meshes_restored']=restored
        proof['source_default_glb_sha256']=default['glb_sha256']
        write(path.with_name('receipt.json'),v)
    write(selected/'mesh-palette-proof.json',proofs)
    compare(Path(result['variants'][0]['path']),Path(result['variants'][1]['path']))
    return {**result,'status':'candidate'}
