"""Produce five own-rig battle-form candidates; approval and admission stay separate."""
import argparse
import concurrent.futures
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import urllib.request

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SLOT = ROOT.parent
WORK = ROOT / '.tmp/battle-forms-first-five-v1'
INTAKE = HERE / 'catalog_battle_forms_first_five_intake.json'
IMPORTER = SLOT / '.tmp/scvi-importer'
DEPS = SLOT / '.tmp/scvi-python-deps'
sys.path.insert(0,str(HERE))
from catalog_shiny_za_17_probe import run_flatpak
from battle_form_motion_intake import prepare
from catalog_shiny_151_material_probe import rebuild
from phase5_variant_parity import compare
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from catalog_native_uv_domain_recovery import used_domains
from scvi_material_probe import inspect_materials
from rare_material_parameters import color_socket
from catalog_dlc_layer_emission import restore
from catalog_dlc_sleep_proposals import propose
from catalog_dlc_flat_motion import graft


def read(p): return json.loads(Path(p).read_text())
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(value, indent=2, allow_nan=False)+'\n')


def download(row):
    folder = WORK/'sources'/row['species'];folder.mkdir(parents=True,exist_ok=True)
    source=folder/'source.unity3d'
    if not source.exists(): source.write_bytes(urllib.request.urlopen(row['motion_url'],timeout=60).read())
    digest=sha(source)
    venv=ROOT/'.tmp/remaining-dlc-15-v1/inspect-venv/bin/python'
    decoded=folder/'decoded-motion.json'
    if not decoded.exists():
        subprocess.run([str(venv),str(HERE/'unity_motion_intake.py'),str(source),'--sha256',digest,'--output',str(decoded)],check=True)
    data=read(decoded);assert data['source_sha256']==digest
    motion,receipt=prepare(row['identity'],data)
    receipt.update(source_sha256=digest,decoded_sha256=sha(decoded),source_url=row['motion_url'],
                   creator=read(INTAKE)['creator'],attribution_url=read(INTAKE)['attribution_url'])
    target=folder/'proposal-motion.json';write(target,motion);receipt['proposal_motion_sha256']=sha(target)
    write(folder/'receipt.json',receipt)
    return {'species':row['species'],'status':'motion_intake','clips':len(data['clips']),**receipt}


def import_model(row):
    source=Path(read(INTAKE)['source_root']);model=source/row['model'];folder=WORK/'import'/row['species'];folder.mkdir(parents=True,exist_ok=True)
    if (folder/'prepared.blend').exists(): return read(folder/'import.json')
    assert subprocess.check_output(['git','-C',str(IMPORTER),'rev-parse','HEAD'],text=True).strip()=='b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04'
    files={str(p):sha(p) for p in model.parent.iterdir() if p.is_file()}
    job={'species':row['species'],'identity':row['identity'],'variant':'normal',
         'model_dir':str(model.parent),'motions':{},'motion_channels':{},'restore_all_eyelids':False,
         'output':str(folder/'prepared.blend'),'report':str(folder/'import.json'),
         'importer':str(IMPORTER),'python_deps':str(DEPS),'importer_commit':'b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04',
         'shader_sha256':sha(IMPORTER/'SCVIShader.blend'),'source_files':files}
    write(folder/'job.json',job)
    run_flatpak(HERE/'scvi_import_worker.py',folder/'job.json',[(WORK,''),(HERE,':ro'),(source,':ro'),(IMPORTER,':ro'),(DEPS,':ro')],folder/'import.log')
    assert all(sha(p)==s for p,s in files.items())
    return read(folder/'import.json')


def convert(row):
    source=WORK/'import'/row['species']/'prepared.blend';motion=WORK/'sources'/row['species']/'proposal-motion.json';folder=WORK/'motion'/row['species'];folder.mkdir(parents=True,exist_ok=True)
    if (folder/'prepared.blend').exists(): return read(folder/'report.json')
    job={'source':str(source),'motion':str(motion),'source_sha256':sha(source),'motion_sha256':sha(motion),
         'explicit_source_hierarchy':row['species'].startswith('ogerpon-'),
         'identity':row['identity'],'verified_translation_scale':100,'output':str(folder/'prepared.blend'),'report':str(folder/'report.json')}
    if row['species'].startswith('ogerpon-'):
        # The converted feeler chain loses precision under repeated 0.1
        # scales. Stabilize this accessory in its own SCVI rest shape under
        # the animated spine; retain the other source bone curves and clocks.
        job['rest_bone_overrides'] = {
            c['name'].split('|')[-1].replace('.gfbanm', ''):
                ['feeler_a_root'] + [f'feeler_a_{i:02}' for i in range(1,14)]
            for c in read(motion)['clips']
            if c['name'].endswith(('_00400_attack01', '_00630_directionattack01'))}
    write(folder/'job.json',job)
    run_flatpak(HERE/'unity_motion_review_worker.py',folder/'job.json',[(WORK,''),(HERE,':ro')],folder/'convert.log')
    return read(folder/'report.json')


def export(row):
    folder=WORK/'motion'/row['species'];names=[r['action'] for r in read(folder/'report.json')['animations']]
    actions={}
    for category,part in [('idle','battlewait01_loop'),('physical_attack','attack01'),('special_attack','rangeattack01'),('damage','damage01'),('faint_start','down01_start'),('physical_attack_2','directionattack01')]:
        matches=[n for n in names if n.endswith('_'+part)]
        if category=='idle' and not matches:matches=[n for n in names if 'defaultidle01' in n]
        if len(matches)>1:raise ValueError('Ambiguous action '+category)
        if matches:actions[category]=matches[0]
    assert {'idle','physical_attack','special_attack','damage','faint_start'}<=actions.keys()
    result={}
    for kind in ('hierarchical','flat'):
        out=WORK/'export'/row['species']/kind;out.mkdir(parents=True,exist_ok=True)
        if not (out/'export.json').exists():
            job={'species':row['species'],'source':str(folder/'prepared.blend'),'source_sha256':sha(folder/'prepared.blend'),
                 'actions':actions,'output':str(out),'scvi_pbr_probe':False,'native_flatten_bone_hierarchy_diagnostic':kind=='flat'}
            write(out/'job.json',job)
            run_flatpak(HERE/'phase5_godot_export_worker.py',out/'job.json',[(WORK,''),(HERE,':ro')],out/'export.log')
        result[kind]=read(out/'export.json')
    return result


def material_source(row):
    source=Path(read(INTAKE)['source_root']);original=source/row['model'];folder=WORK/'material-source'/row['species'];folder.mkdir(parents=True,exist_ok=True)
    normal=original.with_suffix('.trmtr');rare=normal.with_stem(normal.stem+'_rare')
    targets={normal.name:normal,rare.name:rare}
    for table in (normal,rare):
        for material in inspect_materials(table):
            for texture_key, texture in material['textures'].items():
                filename=Path(texture).with_suffix('.png').name
                direct=original.parent/filename
                matches=[direct] if direct.exists() else list(original.parent.parent.glob('*/'+filename))
                if not matches and 'Probe' in texture_key:
                    # Cubemap faces/mips are already packed in the native import.
                    # This albedo/layer-mask stage never reads probe references.
                    continue
                if not matches: raise ValueError('Missing source texture: '+filename)
                if len({sha(p) for p in matches}) != 1: raise ValueError('Ambiguous shared texture: '+filename)
                targets[filename]=matches[0]
    pins={}
    for filename,target in targets.items():
        link=folder/filename
        if link.exists(): assert link.resolve()==target.resolve()
        else: link.symlink_to(target)
        pins[filename]={'source':str(target),'sha256':sha(target)}
    write(folder/'source-receipt.json',pins)
    return folder/original.name


def material(row):
    name=row['species'];src=WORK/'motion'/name/'prepared.blend';original=WORK/'export'/name/'flat/model.glb'
    model=material_source(row);normal=model.with_suffix('.trmtr');rare=normal.with_stem(normal.stem+'_rare')
    tables=[{r['name']:r for r in inspect_materials(t)} for t in (normal,rare)]
    variants={}
    for index,variant in enumerate(('normal','shiny')):
        d=WORK/'materials'/name/variant;d.mkdir(parents=True,exist_ok=True)
        if (d/'receipt.json').exists(): variants[variant]=read(d/'receipt.json');continue
        retained=WORK/'pre-hierarchy-fix/materials'/name/variant/'model.glb'
        if retained.exists():
            target=d/'model.glb'
            parity=graft(retained,original,target)
            record={'path':str(target),'sha256':sha(target),'material_source_sha256':sha(retained),
                    'motion_revision':parity,'runtime_approved':False,'visual_approved':False}
            write(d/'receipt.json',record);variants[variant]=record;continue
        table=(normal,rare)[index];base=d/'base.glb';rebuild(original,base,table)
        doc,binary=chunks(base);probe=copy.deepcopy(doc)
        for m in probe['materials']:
            texture=m['pbrMetallicRoughness']['baseColorTexture'];texture.get('extensions',{}).pop('KHR_texture_transform',None);texture['texCoord']=0
        domains={x['material_index']:x for x in used_domains(probe,binary)};items=[]
        for i,m in enumerate(doc['materials']):
            a,b=[t[m['name']] for t in tables];item={'name':m['name'],'output':str(d/f'colour-{i}.png'),'glow_output':str(d/f'glow-{i}.png')}
            if i in domains:item['source_uv_domain']=domains[i]['source_uv_domain']
            if index:
                item['colour_overrides']=[{'key':color_socket(k,m['name']),'normal':v,'rare':b['colors'][k]} for k,v in a['colors'].items() if k in b['colors'] and v!=b['colors'][k] and color_socket(k,m['name'])==k]
                x,y=[t['textures'].get('BaseColorMap') for t in (a,b)]
                if x!=y:
                    x,y=[model.parent/Path(p).with_suffix('.png').name for p in (x,y)]
                    item['texture_overrides']=[{'normal':str(x),'rare':str(y),'normal_sha256':sha(x),'rare_sha256':sha(y),'expected_authored_bindings':1}]
            items.append(item)
        job={'source':str(src),'source_sha256':sha(src),'idle_action':read(WORK/'export'/name/'flat/job.json')['actions']['idle'],
             'materials':items,'constant_colour_review':True,'static_fresnel_colour_review':True,'bake_resolution':1024,
             'receipt':str(d/'shader-receipt.json'),'normal_table':str(normal),'normal_table_sha256':sha(normal),
             'rare_table':str(rare),'rare_table_sha256':sha(rare)}
        write(d/'bake-job.json',job)
        run_flatpak(HERE/'catalog_animation_material_worker.py',d/'bake-job.json',[(WORK,''),(HERE,':ro'),(Path(read(INTAKE)['source_root']),':ro')],d/'bake.log')
        receipts=read(d/'shader-receipt.json');binary=bytearray(binary)
        for i,(m,item,receipt) in enumerate(zip(doc['materials'],items,receipts)):
            pbr=m['pbrMetallicRoughness'];previous=pbr['baseColorTexture'];sampler=doc['textures'][previous['index']].get('sampler',0)
            def texture(path,suffix):
                t={'index':append_png(doc,binary,Path(path).read_bytes(),m['name']+suffix,sampler)}
                if i in domains:
                    t['extensions']={'KHR_texture_transform':{k:domains[i][k] for k in ('offset','scale')}}
                    if 'KHR_texture_transform' not in doc.setdefault('extensionsUsed',[]):doc['extensionsUsed'].append('KHR_texture_transform')
                return t
            if 'eye' not in m['name'].lower():pbr['baseColorTexture']=texture(item['output'],'_native_detail');pbr['baseColorFactor']=[1,1,1,1]
            m.pop('emissiveTexture',None);m.pop('emissiveFactor',None)
            if not receipt['native_emission_output_zero']:
                m['emissiveTexture']=texture(item['glow_output'],'_native_glow');m['emissiveFactor']=[1,1,1]
                m.setdefault('extensions',{})['KHR_materials_emissive_strength']={'emissiveStrength':receipt['emission_strength']}
                if 'KHR_materials_emissive_strength' not in doc.setdefault('extensionsUsed',[]):doc['extensionsUsed'].append('KHR_materials_emissive_strength')
        baked=d/'baked.glb';write_glb(baked,doc,binary);compare(base,baked)
        target=d/'model.glb';layers=restore(baked,target,table)
        record={'path':str(target),'sha256':sha(target),'table_sha256':sha(table),'shader_receipt_sha256':sha(d/'shader-receipt.json'),'layer_emission':layers}
        write(d/'receipt.json',record);variants[variant]=record
    return {'species':name,'identity':row['identity'],'variants':variants,'geometry_motion_sha256':compare(Path(variants['normal']['path']),Path(variants['shiny']['path'])),'export':read(WORK/'export'/name/'flat/export.json'),'runtime_approved':False}


def rest(row):
    name=row['species'];record=next(r for r in read(WORK/'material-status.json')['entries'] if r['species']==name)
    result=[]
    for variant,spec in record['variants'].items():
        key=name+('-shiny' if variant=='shiny' else '');out=WORK/'rest'/key/'model.glb'
        if out.exists():result.append(read(out.with_name('receipt.json')));continue
        receipt=propose(Path(spec['path']),out,hierarchical_source=WORK/'export'/name/'hierarchical/model.glb')
        animations={**record['export']['animations'],'sleep':{'duration':2,'loop':True},'faint_loop':{'duration':1,'loop':True}}
        entry={'species':key,'path':str(out),'glb_sha256':sha(out),'runtime_schema':1,'status':'exported_for_review','runtime_approved':False,
               'animations':animations,'action_timing':{k:{'frames':v['duration']*60,'speed':1,'loop':v['loop']} for k,v in animations.items()},
               'placement':{'scale':1,'yaw_degrees':0},'complete_pose_channels':True,'sleep_proposal':receipt}
        # Source sizes are below 3 m. Hold candidates with a >10 m posed
        # diagonal instead of allowing finite but corrupt transform chains.
        entry['maximum_pose_extent'] = 10
        entry['review_poses'] = [['idle',0,'front'],['idle',.5,'back']] + [[a,.5,'front'] for a in ('physical_attack','physical_attack_2','special_attack','sleep') if a in animations] + [['faint_start',1,'front'],['faint_loop',.5,'front']]
        entry['battle_review_poses'] = [['idle',0]] + [[a,.5] for a in ('physical_attack','physical_attack_2','special_attack','sleep') if a in animations] + [['faint_start',1]]
        write(out.with_name('receipt.json'),entry);result.append(entry)
    return {'species':name,'variants':result,'runtime_approved':False}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('phase',choices=('download','import','convert','export','material','rest'));p.add_argument('--species',nargs='*');args=p.parse_args()
    WORK.mkdir(exist_ok=True);rows=[r for r in read(INTAKE)['entries'] if not args.species or r['species'] in args.species]
    operation={'download':download,'import':import_model,'convert':convert,'export':export,'material':material,'rest':rest}[args.phase];results=[]
    def guarded(row):
        try:return {'species':row['species'],'status':'candidate',**operation(row)}
        except Exception as e:
            import traceback;traceback.print_exc();return {'species':row['species'],'status':'held','reason':str(e),'runtime_approved':False}
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        for result in pool.map(guarded,rows):
            results.append(result);print(args.phase,result['species'],result['status'],result.get('reason',''),flush=True)
            write(WORK/(args.phase+'-status.json'),{'entries':results,'runtime_approved':False})
    if any(r['status']=='held' for r in results):raise SystemExit(1)
    if args.phase=='rest':write(WORK/'rest-stage.json',[v for r in results for v in r['variants']])


if __name__=='__main__':main()
