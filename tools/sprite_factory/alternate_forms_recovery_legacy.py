"""Own archived variants with explicit full native form-palette reconstruction."""
import copy
import re
from pathlib import Path
from alternate_forms_batch import ROOT,HERE,WORK,MODELS,read,write,sha,pin
from catalog_remaining_normal_export import choose_actions
from catalog_shiny_za_17_probe import run_flatpak
from catalog_remaining_eye_bake import chunks,append_png,write_glb
from scvi_material_probe import inspect_materials
from catalog_shiny_151_material_probe import rebuild
from catalog_dlc_layer_emission import restore
from phase5_variant_parity import compare,signature


def intake(name,resource,dex,palette=None):
    previous=ROOT/'.tmp/alternate-forms-batch-v1'
    sources=read(previous/'archive-probe-job.json')['sources']
    found=[]
    for source in sources:
        if not source['member'].startswith(resource[:6]):continue
        for v in read(source['output'])['variants']:
            if v['rig']==resource:found.append((source,v))
    source,v=found[0];assert len(found)==1
    actions,bank=choose_actions({'species':name,'rig_selection':{'rig':v['rig']},
        'action_candidates':v['action_candidates'],'action_candidates_by_bank':v['action_candidates_by_bank'],
        'unambiguous_actions':{k:x[0] for k,x in v['action_candidates'].items() if len(x)==1},
        'second_physical_candidates':[a for a in v['action_names'] if re.search(r'_(attack02|ba20_buturi02)(\.|$)',a)]})
    sleep_proof=None
    if not actions and name in ('cramorant-gorging','cramorant-gulping'):
        probe=ROOT/'.tmp/alternate-forms-recovery-v1/probes-v2/Gen8/pm0917.json'
        detailed=read(probe);assert detailed['source_sha256']==source['sha256']
        base,=[r for r in detailed['rigs'] if r['name']=='pm0917_11_00']
        own,=[r for r in detailed['rigs'] if r['name']==resource]
        assert own['bones']==base['bones'] and own['matrix']==base['matrix']
        choices=v['action_candidates_by_bank']['0']
        actions={k:x[0] for k,x in choices.items() if len(x)==1}
        idle,=choices['idle']
        actions['idle']=idle
        assert set(actions)>={'idle','damage','physical_attack','special_attack','faint_start'}
        assert all(a.startswith(resource+'_') for a in actions.values())
        sleep,=[a for a in detailed['actions'] if a['name']=='pm0917_11_00_00281_sleep01_loop']
        actions['sleep']=sleep['name'];bank='own-bank-0-and-identical-skeleton-sleep'
        sleep_proof={'probe_sha256':sha(probe),'source_sha256':source['sha256'],
                     'skeleton_sha256':own['bones_sha256'],'sleep_action_sha256':sleep['curves_sha256'],
                     'policy':'identical-source-skeleton-sleep-binding'}
    assert actions
    return {'species':name,'resource':resource,'national_dex':dex,'route':'archive-native-palette',
        'source':source,'actions':actions,'bank':bank,'palette':palette,
        'diagnostic_rig_selection':{'policy':'explicit_source_variant_review_v1','rig':v['rig'],
            'rig_identity':resource,'expected_identity':v['texture_identities'][0],'source_sha256':source['sha256']},
        'runtime_approved':False,'sleep_binding':sleep_proof}


def build(row):
    old=ROOT/'.tmp/alternate-forms-batch-v1';name=row['species'];resource=row['resource']
    out=WORK/'export'/name;out.mkdir(parents=True,exist_ok=True)
    assert sha(row['source']['path'])==row['source']['sha256']
    if not (out/'export.json').exists():
        job={'species':name,'source':row['source']['path'],'source_sha256':row['source']['sha256'],
            'diagnostic_rig_selection':row['diagnostic_rig_selection'],'actions':row['actions'],'output':str(out),
            'native_flatten_bone_hierarchy_diagnostic':True,'scvi_pbr_probe':False}
        write(out/'job.json',job)
        run_flatpak(HERE/'phase5_godot_export_worker.py',out/'job.json',[(old,':ro'),(WORK,''),(HERE,':ro')],out/'export.log')
    source=out/'model.glb';assert sha(source)==read(out/'export.json')['glb_sha256']
    from alternate_forms_material_sources import prepare
    directory=MODELS/resource[:6]/resource
    prepared=prepare({'species':name,'resource':resource,'selected_motion_files':[],
        'scvi_files':[pin(p) for p in directory.rglob('*') if p.is_file()]})
    table=next(Path(p['path']) for p in prepared['scvi_files'] if p['path'].endswith(resource+'.trmtr'))
    material_rows={m['name']:m for m in inspect_materials(table)}
    doc,blob=chunks(source);original=copy.deepcopy(doc)
    for node in doc['nodes']:
        if 'mesh' in node:node['name']=re.sub(r'\.\d{3}$','',node['name'])
    for m in doc['materials']:
        m['name']=re.sub(r'\.\d{3}$','',m['name']);binding=material_rows[m['name']]
        texture=table.parent/Path(binding['textures']['BaseColorMap']).with_suffix('.png')
        m.setdefault('pbrMetallicRoughness',{})['baseColorTexture']={'index':append_png(doc,blob,texture.read_bytes(),texture.stem,0)}
    seed=out/'source-bound.glb';write_glb(seed,doc,blob)
    control=copy.deepcopy(doc)
    for a,b in zip(original['nodes'],control['nodes'],strict=True):b['name']=a['name']
    control_path=out/'name-parity.glb';write_glb(control_path,control,bytearray(blob));assert signature(source)==signature(control_path)
    results=[];proofs=[]
    for variant,native in [('normal','normal'),('shiny','rare')]:
        folder=WORK/'materials'/name/variant;folder.mkdir(parents=True,exist_ok=True)
        selected=table if native=='normal' else table.with_stem(table.stem+'_rare')
        if row['palette'] is not None:
            from alternate_forms_recovery_selectors import apply
            projection=WORK/'legacy-palettes'/name/native;projection.mkdir(parents=True,exist_ok=True)
            for p in table.parent.iterdir():
                if p.suffix=='.trmtr':continue
                dest=projection/p.name
                if not dest.exists():dest.symlink_to(p)
            normal_reference=projection/table.name
            if native=='rare' and not normal_reference.exists():normal_reference.symlink_to(table)
            target=projection/selected.name
            proof=apply(selected,directory/(resource+'.trmmt'),native,row['palette'],target)
            # Reject material-wide edits affecting any unbound mesh.
            uses={}
            for n in doc['nodes']:
                if 'mesh' not in n:continue
                for p in doc['meshes'][n['mesh']]['primitives']:uses.setdefault(doc['materials'][p['material']]['name'],set()).add(n['name'])
            bound={}
            for mesh,material,param,kind,value in proof['bindings']:bound.setdefault((material,param),set()).add(mesh.removesuffix('_shape'))
            assert all(meshes==uses[material] for (material,_),meshes in bound.items())
            selected=target;proofs.append(proof)
        rebuild(seed,folder/'albedo.glb',selected)
        restore(folder/'albedo.glb',folder/'model.glb',selected)
        compare(seed,folder/'model.glb');results.append(folder/'model.glb')
    write(out/'material-proof.json',{'source_sha256':row['source']['sha256'],'original_export_sha256':sha(source),
        'only_node_suffixes_and_materials_changed':True,'palettes':proofs,'sleep_binding':row.get('sleep_binding')})
    compare(*results)
    return out,*results,{'native_material_proof_sha256':sha(out/'material-proof.json')}
