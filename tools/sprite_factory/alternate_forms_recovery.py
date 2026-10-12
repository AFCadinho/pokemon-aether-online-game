"""Repair held alternate forms in a fresh workspace; old approvals stay immutable."""
import argparse
import copy
import importlib
import os
import struct
import subprocess
from pathlib import Path

import alternate_forms_batch as batch
from alternate_forms_batch import ROOT, HERE, SOURCE, MODELS, MOTIONS, read, write, sha

PREVIOUS = batch.WORK
WORK = ROOT/'.tmp/alternate-forms-recovery-v1'
INTAKE = HERE/'alternate_forms_recovery_intake.json'


def setup():
    WORK.mkdir(parents=True, exist_ok=True)
    original = {r['species']:r for r in read(batch.INTAKE)['entries']}
    rows = []
    for r in read(PREVIOUS/'legacy-intake.json')['entries']:
        if r['species'].startswith('unown-'):
            rows.append({**r, 'route':'archive-unown', 'national_dex':201})
    from scvi_batch import source_entry
    for r in read(PREVIOUS/'legacy-intake.json')['entries']:
        if r['species'].startswith('silvally-'):
            rows.append({**r,'route':'archive-silvally','national_dex':773})
    for r in read(HERE/'alternate_forms_colour_intake.json')['entries']:
        if not r['species'].startswith('squawkabilly-'): continue
        r = copy.deepcopy(r)
        source = source_entry({'species':r['species'], 'pm':1064, 'resource_id':r['resource'],
            'cross_bank_sleep_diagnostic':True, 'motion_overrides':{'sleep':'00281_sleep01_loop'}}, MODELS, MOTIONS)
        assert not [w for w in source['warnings'] if w.startswith(('missing_action:', 'motion_bank_hold:'))]
        r['actions'] = {a:Path(p).stem for a,p in source['motions'].items() if p}
        paths = sorted({Path(p) for p in [*source['motions'].values(), *source['motion_channels'].values()] if p})
        r['selected_motion_files'] = [batch.pin(p) for p in paths]
        r.update(route='native', status='native_candidate', holds=[],
            recovery_policy='Own source sleep bank 0; battle bank 2, individually tested transitions')
        rows.append(r)
    for name in ['sawsbuck-autumn','sawsbuck-summer','sawsbuck-winter']:
        rows.append({**original[name],'route':'sawsbuck-order'})
    for family,pm in [('pumpkaboo',735),('gourgeist',736)]:
        for form,number in [('small',12),('large',13),('super',14)]:
            name=family+'-'+form;ident=f'pm{pm:04}_{number:02}_00';root=WORK/'za-sources';directory=root/ident[:6]/ident
            native=source_entry({'species':name,'pm':pm,'resource_id':ident},root,root)
            assert not [w for w in native['warnings'] if w.startswith(('missing_action:','motion_bank_hold:'))]
            def pinned(p):return {'path':str(p),'sha256':sha(p),'bytes':p.stat().st_size}
            used={Path(p) for p in [*native['motions'].values(),*native['motion_channels'].values()] if p}
            rows.append({'species':name,'resource':ident,'national_dex':original[name]['national_dex'],
                'route':'native','source_directory':str(directory),'scvi_files':[pinned(p) for p in sorted(directory.rglob('*')) if p.is_file()],
                'selected_motion_files':[pinned(p) for p in sorted(used)],'actions':{a:Path(p).stem for a,p in native['motions'].items() if p},
                'rare_texture_replacements':[],'dynamic_visibility_review':True,'preserve_source_static_effects':True,
                'status':'native_candidate','holds':[],'runtime_approved':False})
    from alternate_forms_recovery_legacy import intake as legacy_intake
    for index,colour in enumerate(['red','orange','yellow','green','blue','indigo','violet']):
        if index:rows.append(legacy_intake('minior-'+colour,'pm0824_12_00',774,index))
    rows.append(legacy_intake('minior-meteor','pm0824_11_00',774,0))
    for name,resource in [('cramorant-gorging','pm0917_13_00'),('cramorant-gulping','pm0917_12_00')]:
        rows.append(legacy_intake(name,resource,845))
    write(INTAKE, {'schema':1, 'original_intake_sha256':sha(batch.INTAKE), 'entries':rows})
    print('RECOVERY_INTAKE', len(rows))


def context(only):
    # Configure reusable, unchanged diagnostic modules before importing consumers.
    batch.WORK = WORK
    batch.INTAKE = INTAKE
    batch.cohort_rows = lambda: [r for r in read(INTAKE)['entries'] if not only or r['species'] in only]
    return batch.cohort_rows()


def unown(row):
    from catalog_shiny_za_17_probe import run_flatpak
    from catalog_remaining_eye_bake import chunks, append_png, write_glb
    from phase5_variant_parity import compare
    name = row['species']; exported = PREVIOUS/'legacy-export'/name
    report = read(exported/'export.json'); source = exported/'model.glb'
    assert sha(source) == report['glb_sha256'] and sha(row['source']['path']) == row['source']['sha256']
    baked = WORK/'archive-bake'/name; baked.mkdir(parents=True, exist_ok=True)
    job = {'source':row['source']['path'], 'source_sha256':row['source']['sha256'], 'output':str(baked), 'materials':['body','eye']}
    write(baked/'job.json', job)
    probe=WORK/'probes-v2/Gen2'/(Path(row['source']['member']).stem+'.json')
    own=read(probe)
    if not any(n['name']=='Mix (Legacy).011' for n in own['materials']['body']['nodes']):
        ref=WORK/'probes-v2/Gen2/pm0201_12.json'
        job.update(palette_reference=str(ref),palette_reference_sha256=sha(ref))
        write(baked/'job.json',job)
        worker=HERE/('alternate_forms_recovery_question_bake.py' if name=='unown-question' else 'alternate_forms_recovery_shared_palette_bake.py')
    else:
        worker=HERE/('alternate_forms_recovery_unown_u_bake.py' if name in ('unown-i','unown-u') else 'alternate_forms_recovery_archive_bake.py')
    if not (baked/'bake.json').exists():
        run_flatpak(worker,baked/'job.json',[(PREVIOUS,':ro'),(WORK,''),(HERE,':ro')],baked/'bake.log')
    receipt = read(baked/'bake.json')
    assert receipt['worker_sha256'] == sha(worker) and receipt['source_sha256'] == job['source_sha256']
    entries=[]
    for variant in ('normal', 'shiny'):
        doc, blob = chunks(source)
        for material in doc['materials']:
            texture, = [t for t in receipt['textures'] if t['variant']==variant and t['material']==material['name']]
            assert sha(texture['path'])==texture['sha256']
            pbr = material.setdefault('pbrMetallicRoughness', {})
            old = pbr.get('baseColorTexture',{})
            sampler = doc['textures'][old['index']].get('sampler',0) if old else 0
            pbr['baseColorTexture']={'index':append_png(doc,blob,Path(texture['path']).read_bytes(),material['name']+'_'+variant,sampler)}
            pbr['baseColorFactor']=[1,1,1,1]
            material.pop('emissiveTexture',None);material.pop('emissiveFactor',None)
            material['alphaMode']='OPAQUE'
        out = WORK/'materials'/name/variant/'model.glb';out.parent.mkdir(parents=True,exist_ok=True)
        write_glb(out,doc,blob);compare(source,out)
        entry=model_entry(name,variant,out,report,row,{'authored_palette_receipt_sha256':sha(baked/'bake.json')})
        entries.append(entry)
    compare(Path(entries[0]['path']),Path(entries[1]['path']))
    return {'species':name, 'status':'candidate', 'variants':entries, 'runtime_approved':False}



def model_entry(name,variant,out,report,row,evidence):
    clips=report['animations']
    entry={'species':name+('-shiny' if variant=='shiny' else ''), 'path':str(out),
        'glb_sha256':sha(out), 'source_sha256':row['source']['sha256'], 'animations':clips,
        'runtime_schema':1, 'action_timing':{a:{'frames':c['duration']*60,'speed':1,'loop':c['loop']} for a,c in clips.items()},
        'placement':{'scale':1,'yaw_degrees':0}, 'complete_pose_channels':True,
        'status':'exported_for_review', 'runtime_approved':False,'appearance_approved':False,'battle_approved':False,
        'maximum_pose_extent':12, 'source_visibility_policy':'Archived own-rig membership',
        'recovery_evidence':evidence,
        'review_poses':[[a,f,v] for a,f,v in [('idle',0,'front'),('idle',.5,'back'),('idle',.5,'side'),
            ('physical_attack',.5,'front'),('physical_attack_2',.5,'front'),('special_attack',.5,'front'),
            ('sleep',.5,'front'),('faint_start',1,'front'),('faint_loop',.5,'front')] if a in clips]}
    return entry

def size_placement(row, result):
    """Apply the centre of the native size interval, keeping source geometry intact."""
    if not row['species'].startswith(('pumpkaboo-', 'gourgeist-')):
        return result
    from scvi_tracm import _Buffer
    path = Path(row['source_directory']) / (row['resource'] + '.trpokecfg')
    b = _Buffer(path.read_bytes()); root = b.u32(0)
    minimum, maximum = [b.scalar(root, i, lambda o: struct.unpack_from('<f', b.data, o)[0]) for i in (1, 2)]
    assert 0 < minimum <= maximum < 3
    scale = round((minimum + maximum) / 2, 6)
    proof = {'path':str(path), 'sha256':sha(path), 'minimum':minimum, 'maximum':maximum,
             'placement_scale':scale, 'policy':'centre-of-native-size-interval',
             'schema':'https://github.com/pkZukan/PokeDocs/blob/main/SV/Flatbuffers/model/trpokecfg.fbs'}
    write(WORK/'size-proofs'/(row['species']+'.json'), proof)
    for variant in result['variants']:
        variant.setdefault('placement', {})['scale'] = scale
        variant.setdefault('recovery_evidence', {})['size_proof_sha256'] = sha(WORK/'size-proofs'/(row['species']+'.json'))
    return result


def materials(rows):
    from alternate_forms_material_sources import prepare
    for row in rows:
        name=row['species'];status=WORK/'status/material'/(name+'.json')
        try:
            if status.exists() and read(status)['status']=='candidate':
                cached=read(status)
                for variant in cached['variants']:
                    assert sha(variant['path'])==variant['glb_sha256'], 'Cached GLB changed'
                if 'source' in row:
                    assert sha(row['source']['path'])==row['source']['sha256'], 'Archive source changed'
                else:
                    batch.verify(row,SOURCE)
                # Palette worker receipts are rechecked again before admission.
                continue
            if row['route']=='sawsbuck-order': result=read(PREVIOUS/'status/material'/(name+'.json'))
            elif row['route']=='archive-unown': result=unown(row)
            elif row['route'] in ('archive-silvally','archive-native-palette'):
                module='alternate_forms_recovery_silvally' if row['route']=='archive-silvally' else 'alternate_forms_recovery_legacy'
                exported,normal,shiny,evidence=importlib.import_module(module).build(row)
                result={'species':name,'status':'candidate','variants':[model_entry(name,v,p,read(exported/'export.json'),row,evidence) for v,p in [('normal',normal),('shiny',shiny)]]}
            else:
                batch.verify(row,SOURCE)
                exported=batch.export(row,SOURCE,WORK)
                write(WORK/'status/export'/(name+'.json'), {'status':'exported','export':exported})
                if row.get('material_selector'):
                    result=importlib.import_module('alternate_forms_recovery_palette').build(row)
                else:
                    prepared=prepare(row)
                    result={**batch.material(prepared,SOURCE,WORK),'status':'candidate'}
        except Exception as error: result={'species':name,'status':'held','reason':type(error).__name__+': '+str(error)}
        if result['status']=='candidate': result=size_placement(row,result)
        write(status,result)
        print('RECOVERY_MATERIAL',name,result['status'],result.get('reason',''),flush=True)
    write(WORK/'material-status-native.json',{'entries':[read(WORK/'status/material'/(r['species']+'.json')) for r in rows]})



def ordered_seasons(rows):
    """Reproduce the declared ordering repair before the shared runtime checks."""
    for row in rows:
        if row['route']!='sawsbuck-order':continue
        name=row['species'];output=WORK/'runtime-jobs'/name/'native'
        report=output/'report.json'
        if report.exists():
            assert all(r.get('opaque_order_changes') for r in read(report))
            continue
        source=PREVIOUS/'runtime-jobs'/name/'native/report.json'
        entries=read(source)
        for entry in entries:assert sha(entry['runtime_path'])==entry['runtime_sha256']
        output.mkdir(parents=True,exist_ok=True)
        job=output/'order-input.json';write(job,entries)
        with (output.parent/'ordering.log').open('w') as log:
            subprocess.run(['godot','--headless','--path',str(ROOT),'--script',
                'res://tools/sprite_factory/alternate_forms_recovery_order_runtime.gd','--',str(job),str(report)],
                stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
        assert 'RECOVERY_OPAQUE_ORDER_OK' in (output.parent/'ordering.log').read_text()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=['setup','materials','runtime','appearance','battle','delivery','contacts'])
    parser.add_argument('--only'); args=parser.parse_args()
    assert os.environ.get('POKEAETHER_SLOT')==ROOT.parent.name
    if args.phase=='setup':setup();return
    rows=context(set(args.only.split(',')) if args.only else None)
    if args.phase=='materials':materials(rows)
    elif args.phase=='appearance':importlib.import_module('alternate_forms_recovery_appearance').main(rows)
    elif args.phase=='battle':importlib.import_module('alternate_forms_recovery_battle').main()
    elif args.phase=='contacts':importlib.import_module('alternate_forms_contacts').appearance(WORK/'contacts')
    elif args.phase=='delivery':
        mod=importlib.import_module('alternate_forms_delivery')
        for row in rows:
            name=row['species']
            try: result=mod.qualify(name)
            except Exception as error:result={'species':name,'status':'held','reason':type(error).__name__+': '+str(error)}
            write(WORK/'status/delivery'/(name+'.json'),result)
            print('RECOVERY_DELIVERY',name,result['status'],result.get('reason',''),flush=True)
    else:
        ordered_seasons(rows)
        importlib.import_module('alternate_forms_runtime_queue').main()


if __name__=='__main__':main()
