"""Reconstruct archived form colours only from matching pinned native tables."""
import re
import copy
import time
from pathlib import Path
from alternate_forms_batch import ROOT, WORK, INTAKE, MODELS, SOURCE, read, write, sha, pin
from alternate_forms_material_sources import prepare
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from catalog_shiny_151_material_probe import rebuild
from catalog_dlc_layer_emission import restore
from scvi_material_probe import inspect_materials
from material_profiles import classify
from phase5_variant_parity import compare, signature
from scvi_identity import Buffer


def process(row):
    name = row['species']; resource = row['resource']
    source = WORK/'legacy-export'/name/'model.glb'
    report = read(source.with_name('export.json'))
    assert sha(source)==report['glb_sha256'] and sha(row['source']['path'])==row['source']['sha256']
    original = MODELS/resource[:6]/resource
    if not original.is_dir(): raise ValueError('No matching native normal/rare material table in SCVI sources')
    projected_export = WORK/'export'/name
    if not projected_export.exists(): projected_export.symlink_to(source.parent,target_is_directory=True)
    assert projected_export.resolve()==source.parent.resolve()
    spec={'species':name,'resource':resource,'selected_motion_files':[],
        'scvi_files':[pin(p) for p in sorted(original.rglob('*')) if p.is_file()]}
    projected=prepare(spec)
    table=next(Path(r['path']) for r in projected['scvi_files'] if r['path'].endswith(resource+'.trmtr'))
    source_rows={r['name']:r for r in inspect_materials(table)}
    if any(classify(m).get('requires_effect_payload') for m in source_rows.values()):
        raise ValueError('Archived source effects require their matching material motion evidence')
    document,binary=chunks(source)
    source_visibility = None
    if name.startswith('alcremie-'):
        selector = original/(resource+'.trmmt')
        view=Buffer(selector.read_bytes()); choices={}
        for variant in ('normal','rare'):
            selected=[v for v in view.tables(view.number(0),2) if view.string(v,0)==variant+'_strawberry']
            assert len(selected)==1
            choices[variant]={view.string(t,0).removesuffix('_shape'):bool(view.scalar(t,1,'B')) for t in view.tables(selected[0],2)}
        assert choices['normal']==choices['rare'] and len(choices['normal'])==11
        mesh_names=[]
        for node in document['nodes']:
            if 'mesh' not in node:continue
            node['name']=re.sub(r'\.\d{3}$','',node['name']);mesh_names.append(node['name'])
        assert len(set(mesh_names))==len(mesh_names) and set(mesh_names)==set(choices['normal'])
        source_visibility={'path':str(selector),'sha256':sha(selector),'meshes':choices['normal']}
    normalized=[]
    for m in document['materials']:
        old=m['name']; name_m=old if old in source_rows else re.sub(r'\.\d{3}$','',old)
        if name_m not in source_rows or name_m in normalized:
            raise ValueError('Ambiguous archive/native material binding: '+old)
        normalized.append(name_m);m['name']=name_m
        texture=table.parent/Path(source_rows[name_m]['textures']['BaseColorMap']).with_suffix('.png')
        m.setdefault('pbrMetallicRoughness',{})['baseColorTexture']={
            'index':append_png(document,binary,texture.read_bytes(),texture.stem,0)}
    output=WORK/('legacy-materials-v2' if source_visibility else 'legacy-materials')/name;output.mkdir(parents=True,exist_ok=True)
    seed=output/'source-bound.glb';write_glb(seed,document,binary)
    if source_visibility:
        original_document,_=chunks(source);restored=copy.deepcopy(document);renames=[]
        for before,after in zip(original_document['nodes'],restored['nodes'],strict=True):
            if before.get('name')!=after.get('name'):
                assert 'mesh' in before and re.sub(r'\.\d{3}$','',before['name'])==after['name']
                renames.append({'from':before['name'],'to':after['name']});after['name']=before['name']
        control=output/'mesh-name-parity.glb';write_glb(control,restored,binary)
        parity=compare(source,control)
        write(output/'mesh-name-proof.json',{'original_sha256':sha(source),'candidate_sha256':sha(seed),
            'geometry_skin_motion_exact_after_reversing_names':parity,'renames':renames})
    else:compare(source,seed)
    variants=[]
    for variant in ('normal','shiny'):
        folder=output/variant;folder.mkdir(exist_ok=True)
        selected=table if variant=='normal' else table.with_stem(table.stem+'_rare')
        receipts=rebuild(seed,folder/'albedo.glb',selected)
        emission=restore(folder/'albedo.glb',folder/'model.glb',selected)
        clips=report['animations']; target=folder/'model.glb'
        entry={'species':name+('-shiny' if variant=='shiny' else ''),'path':str(target),
            'glb_sha256':sha(target),'animations':clips,'source_sha256':row['source']['sha256'],
            'runtime_schema':1,'action_timing':{a:{'frames':c['duration']*60,'speed':1,'loop':c['loop']} for a,c in clips.items()},
            'placement':{'scale':1,'yaw_degrees':0},'complete_pose_channels':True,
            'status':'exported_for_review','runtime_approved':False,'appearance_approved':False,
            'battle_approved':False,'material_receipt':receipts,'layer_emission':emission,
            'material_table_sha256':sha(selected),'maximum_pose_extent':12,
            'source_visibility_policy':'Archived native mesh membership; no raw material-motion clock supplied',
            'review_poses':[[a,f,v] for a,f,v in [('idle',0,'front'),('idle',.5,'back'),('idle',.5,'side'),
                ('physical_attack',.5,'front'),('physical_attack_2',.5,'front'),('special_attack',.5,'front'),
                ('sleep',.5,'front'),('faint_start',1,'front'),('faint_loop',.5,'front')] if a in clips]}
        if source_visibility:
            entry['source_visibility_policy']='Native TRMMT normal/rare_strawberry; retain selected sweet, hide six other options'
            entry['visibility']={'schema':1,'glb_sha256':entry['glb_sha256'],'clips':{
                a:{'duration':c['duration'],'loop':c['loop'],'source_path':source_visibility['path'],
                   'source_sha256':source_visibility['sha256'],'tracks':[
                       {'mesh':mesh,'source_target':mesh+'_shape','keys':[[0.0,visible]]}
                       for mesh,visible in source_visibility['meshes'].items()]} for a,c in clips.items()}}
        write(folder/'receipt.json',entry);variants.append(entry)
    if variants[0]['glb_sha256']==variants[1]['glb_sha256']:
        assert inspect_materials(table)==inspect_materials(table.with_stem(table.stem+'_rare'))
        parity=signature(Path(variants[0]['path']))
    else:parity=compare(Path(variants[0]['path']),Path(variants[1]['path']))
    return {'species':row['species'],'status':'candidate','variants':variants,'geometry_motion_parity':parity,
        'source_route':'archived-own-rig-native-colours','runtime_approved':False}


def main():
    rows=[r for r in read(WORK/'legacy-intake.json')['entries'] if r['status']=='export_candidate']
    done={}
    while len(done)<len(rows):
        progressed=False
        for row in rows:
            name=row['species']
            if name in done:continue
            status=WORK/'status/legacy-export'/(name+'.json')
            if not status.exists():continue
            try:
                assert read(status)['status']=='exported_for_review'
                record=process(row)
            except Exception as e:record={'species':name,'status':'held','reason':type(e).__name__+': '+str(e)}
            write(WORK/'status/legacy-material'/(name+'.json'),record)
            if record['status']=='candidate':write(WORK/'status/material'/(name+'.json'),record)
            done[name]=record;progressed=True
            write(WORK/'legacy-material-status.json',{'entries':sorted(done.values(),key=lambda r:r['species'])})
            print('LEGACY_MATERIAL',name,record['status'],record.get('reason',''),flush=True)
        if not progressed:time.sleep(5)


if __name__=='__main__':main()
