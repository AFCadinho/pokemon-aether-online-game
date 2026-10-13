"""Reproducible local reconstruction previews for the final 21 forms.

Authorization: user permitted authored missing geometry, motion and effects.
No output of this tool grants visual, battle, runtime or release approval.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import os
from pathlib import Path
import re
import shutil

from alternate_forms_batch import ROOT, HERE, SOURCE, MODELS, MOTIONS, read, write, sha
from catalog_shiny_za_17_probe import run_flatpak
from scvi_batch import source_entry
from scvi_material_probe import inspect_materials

WORK = ROOT/'.tmp/remaining-twenty-one-v2'
OLD = ROOT/'.tmp/alternate-forms-batch-v1'
IMPORTER = ROOT.parent/'.tmp/scvi-importer'
DEPS = ROOT.parent/'.tmp/scvi-python-deps'
CORE = ['idle','physical_attack','special_attack','damage','sleep','faint_start']
TERA = {'teal':11,'wellspring':12,'hearthflame':13,'cornerstone':14}


def flat(worker, job, place):
    path=place/'job.json'
    if (place/'worker.log').exists():
        index=1
        while (place/f'worker-retry-{index}.log').exists():index+=1
        (place/'worker.log').rename(place/f'worker-retry-{index}.log')
        if path.exists():path.rename(place/f'job-retry-{index}.json')
    write(path,job)
    run_flatpak(HERE/worker,path,[(HERE,':ro'),(SOURCE,':ro'),(OLD,':ro'),
        (IMPORTER,':ro'),(DEPS,':ro'),(WORK,'')],place/'worker.log')


def native_specs():
    result=[{'species':'pikachu-f-base','resource':'pm0025_01_00'},
            {'species':'pichu-base','resource':'pm0172_00_00'}]
    for name,pm in [('kyogre-primal',382),('groudon-primal',383)]:
        result.append({'species':name,'resource':f'pm{pm:04}_51_00','za':True})
    for form,index in TERA.items():
        for kind,suffix in [('tera','00'),('gem','99')]:
            result.append({'species':f'ogerpon-{form}-{kind}','resource':f'pm1120_{index:02}_{suffix}', 'static':kind=='gem'})
    return result


def native(row):
    name=row['species']; ident=row['resource']; place=WORK/'native'/name;place.mkdir(parents=True,exist_ok=True)
    root=OLD/'za-sources' if row.get('za') else MODELS
    source=source_entry({'species':name,'pm':int(ident[2:6]),'resource_id':ident},root,root if row.get('za') else MOTIONS)
    directory=Path(source['model_dir'])
    prepared=place/'import/prepared.blend'; report=prepared.with_name('import.json')
    if not report.exists():
        files={str(p):sha(p) for p in directory.parent.rglob('*') if p.is_file() and p.suffix in ['.png','.trmdl','.trmsh','.trmbf','.trmtr','.trskl','.trmmt']}
        motions={k:v for k,v in source['motions'].items() if v}
        files.update({p:sha(p) for p in motions.values()})
        job={'species':name,'identity':ident,'variant':'normal','model_dir':str(directory),
             'motions':motions,'motion_channels':{},'output':str(prepared),'report':str(report),
             'restore_all_eyelids':any(m['shaders'] and m['shaders'][0]['name']=='EyeClearCoat' and all(s['name'] in ['EyeClearCoat','Eye'] and s['values'].get('EyelidType') in ['All','Upper'] for s in m['shaders']) for m in inspect_materials(directory/(ident+'.trmtr'))),'importer':str(IMPORTER),'python_deps':str(DEPS),
             'importer_commit':'b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04',
             'shader_sha256':sha(IMPORTER/'SCVIShader.blend'),'source_files':files}
        flat('scvi_import_worker.py',job,prepared.parent)
    imported=read(report); assert sha(prepared)==imported['prepared_sha256']
    out=place/'export';out.mkdir(exist_ok=True)
    # Isolated derivative in this same assigned slot; original import is immutable.
    isolated=out/'input.blend'
    if not isolated.exists():shutil.copyfile(prepared,isolated)
    assert sha(isolated)==sha(prepared)
    actions={a:r['name'] for a,r in imported['actions'].items() if r}
    missing=[a for a in CORE if a not in actions]
    for a in missing:actions[a]='PAO_MISSING_'+a
    if row.get('static'):actions={'idle':'PAO_MISSING_idle'};missing=['idle']
    job={'species':name,'source':str(isolated),'source_sha256':sha(isolated),'actions':actions,
         'authored_motion_review':missing,'output':str(out),'native_flatten_bone_hierarchy_diagnostic':True,'scvi_pbr_probe':False}
    if not (out/'export.json').exists():flat('phase5_godot_export_worker.py',job,out)
    assert sha(out/'model.glb')==read(out/'export.json')['glb_sha256']
    write(place/'source.json',{'species':name,'resource':ident,'directory':str(directory),'authored_clips':missing,
        'import_report_sha256':sha(report),'runtime_approved':False})
    print('NATIVE',name,flush=True)


def legacy(name):
    rows=read(OLD/'legacy-intake.json')['entries']; row=next(r for r in rows if r['species']==name)
    place=WORK/'legacy'/name;place.mkdir(parents=True,exist_ok=True)
    if name=='greninja-ash':
        ev=read(HERE/'remaining_forms_evidence.json')['blender_probes']['Gen6/pm0725_ash']
        source=ev['source']; selection=None; actions={'idle':'RECOVERED_OBidle','physical_attack':'RECOVERED_OBattack1','special_attack':'RECOVERED_OBattack3','damage':'RECOVERED_OBhit','faint_start':'RECOVERED_OBdown'}
    else:
        source=row['source']; selection=row['diagnostic_rig_selection']; actions=row.get('actions') or {}
        if not actions:
            probe=read(source['output']); variant=next(v for v in probe['variants'] if v['rig']==selection['rig'])
            names=variant['action_names']
            if name.startswith('castform-') or name=='necrozma-ultra':
                detailed=read(ROOT/'.tmp/remaining-forms-investigation-v1/probes'/('Gen3/pm0351.json' if name.startswith('castform-') else 'Gen7/pm0800.json'))
                family=selection['rig_identity']
                names=[a['name'] for a in detailed['actions'] if family in a['name']]
            endings={'idle':'ba10_waitA01','physical_attack':'ba20_buturi01','special_attack':'ba21_tokusyu01','damage':'ba30_damageS01','faint_start':'ba40_down01','sleep':'ba11_sleep01'}
            for category,ending in endings.items():
                found=[a for a in names if re.search(re.escape(ending)+r'(?:\||\.|$)',a)]
                if len(found)==1:actions[category]=found[0]
    missing=[a for a in CORE if a not in actions]
    for a in missing:actions[a]='PAO_MISSING_'+a
    if name.startswith('castform-') or name in ['necrozma-ultra','greninja-ash']:
        prep=place/('prepared-v2/source.blend' if name=='greninja-ash' else 'prepared/source.blend')
        if not prep.exists():flat('remaining_twenty_one_prepare.py',{'species':name,'source':source['path'],'source_sha256':source['sha256'],'rig':selection['rig'] if selection else 'model_skeleton','output':str(prep)},prep.parent)
        assert sha(prep)==read(prep.with_suffix('.json'))['prepared_sha256']
        source={'path':str(prep),'sha256':sha(prep)};selection=None
    job={'species':name,'source':source['path'],'source_sha256':source['sha256'],
         'actions':actions,'authored_motion_review':missing,'output':str(place),
         'native_flatten_bone_hierarchy_diagnostic':True,'scvi_pbr_probe':False}
    if selection:job['diagnostic_rig_selection']=selection
    if not (place/'export.json').exists():flat('phase5_godot_export_worker.py',job,place)
    assert sha(place/'model.glb')==read(place/'export.json')['glb_sha256']
    write(place/'source.json',{'species':name,'source':source,'authored_clips':missing,'runtime_approved':False})
    print('LEGACY',name,flush=True)


def stage(only=None):
    names=read(HERE/'remaining_fourteen_qualification.json')['remaining_species']
    if only:names=[n for n in names if n in only]
    entries=[]
    colours={'teal':'74dcc1','wellspring':'68bdef','hearthflame':'ffc950','cornerstone':'b9c4db'}
    for name in names:
        base='pikachu-f-base' if name.startswith('pikachu-') else 'pichu-base' if name=='pichu-spiky-eared' else name
        for variant in ['normal','shiny']:
            path=WORK/'models'/base/variant/'model.glb'
            entry={'species':name+('-shiny' if variant=='shiny' else ''),'base_species':name,'variant':variant,
                'path':str(path),'glb_sha256':sha(path),'runtime_approved':False,
                'review_scale':0.01 if name=='eternatus-eternamax' else 1.0,
                'material_limitations':'Authored reconstruction preview. Visual review, sleep eyes, battle qualification and packaging still pending.'}
            if name.startswith('ogerpon-'):
                gem=WORK/'models'/name.replace('-tera','-gem')/variant/'model.glb'
                entry.update(gem_path=str(gem),gem_sha256=sha(gem),effect_colour=colours[name.split('-')[1]])
                info=read(WORK/'native'/name.replace('-tera','-gem')/'source.json')
                projection=WORK/'palettes'/name.replace('-tera','-gem')
                table=projection/(info['resource']+'.trmtr')
                specs={}
                for row in inspect_materials(table):
                    if row['name']!='body_c' or 'LayerMaskMap' not in row['textures']:continue
                    specs[row['name']]={'colours':row['colors'],'floats':row['floats'],'textures':{
                        key:{'path':str(projection/Path(row['textures'][key]).with_suffix('.png').name),
                            'sha256':sha(projection/Path(row['textures'][key]).with_suffix('.png').name)} for key in ['LayerMaskMap','NormalMap']}}
                entry['gem_layers']=specs
            entries.append(entry)
    path=WORK/('stage-'+('-'.join(only) if only else 'all')+'.json')
    write(path,{'runtime_approved':False,'reconstruction_authorized':True,'entries':entries})
    print(path)


def main():
    assert os.environ.get('POKEAETHER_SLOT')==ROOT.parent.name
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=['native','legacy','stage','review-project']);parser.add_argument('--only')
    args=parser.parse_args(); WORK.mkdir(parents=True,exist_ok=True)
    if args.phase=='review-project':
        project=WORK/'runtime-project';project.mkdir(exist_ok=True)
        link=project/'tools'
        if not link.exists():link.symlink_to(ROOT/'tools',target_is_directory=True)
        assert link.resolve()==ROOT/'tools'
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Remaining forms review"\n[display]\nwindow/size/viewport_width=640\nwindow/size/viewport_height=640\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        return
    if args.phase=='stage':stage(args.only.split(',') if args.only else None);return
    rows=native_specs() if args.phase=='native' else [dict(species=n) for n in [
        'castform-sunny','castform-rainy','castform-snowy','greninja-ash','eternatus-eternamax',
        'necrozma-ultra','necrozma-dawn-wings','necrozma-dusk-mane']]
    if args.only:rows=[r for r in rows if r['species'] in args.only.split(',')]
    failures=[]
    with ThreadPoolExecutor(max_workers=2) as pool:
        pending={pool.submit(native if args.phase=='native' else lambda r:legacy(r['species']),r):r['species'] for r in rows}
        for future in as_completed(pending):
            name=pending[future]
            try:future.result()
            except Exception as error:failures.append({'species':name,'error':str(error)});print('FAILED',name,str(error),flush=True)
    write(WORK/(args.phase+'-status.json'),{'failures':failures,'runtime_approved':False})
    if failures:raise SystemExit(1)

if __name__=='__main__': main()
