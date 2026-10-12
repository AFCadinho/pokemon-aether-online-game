"""Prepare source-exact compressed pair packs; approval remains a separate step."""
import copy
import os
from pathlib import Path
import struct
import subprocess
import sys
from alternate_forms_batch import ROOT, WORK, INTAKE, read, write, sha
sys.path.insert(0,str(ROOT/'tools'))
from package_optional_3d_bundle_prototype import encoded
from native_resource_compression_probe import Zstd, decode, encode
from probe_v13_compression import pack_pck, digest
from qualify_shared_model_catalog import compare


def prepare(name):
    destination=WORK/'delivery'/name;destination.mkdir(parents=True,exist_ok=True)
    native=read(WORK/'runtime-jobs'/name/'native/report.json')
    review=read(WORK/'battle'/name/'final/battle-review.json')
    placement=read(WORK/'battle'/name/'placement.json')
    assert review['complete'] and not placement['motion_holds']
    measured={r['species']:r for r in review['entries'] if 'clips' in r}
    fixture={'models':{},'profiles':{}}; inputs=[]
    for row in native:
        species=row['species'];m=measured[species]
        assert sha(row['path'])==row['glb_sha256']==m['glb_sha256']
        assert sha(row['runtime_path'])==row['runtime_sha256']
        assert all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in m['shots'])
        assert min(c['minimum_y'] for c in m['corrected_clearance_120hz'].values())>=.025-1e-5
        motion=copy.deepcopy(placement['motion'][species])
        assert motion['sha256']==row['glb_sha256']
        assert abs(motion['lift']-m['candidate_lift'])<.001 and abs(motion['scale']-m['scale'])<1e-6
        motion['sha256']=row['runtime_sha256']
        variant='shiny' if species.endswith('-shiny') else 'normal'
        identity=name+('@shiny' if variant=='shiny' else '')
        position={k:motion[k] for k in ('scale','yaw_degrees')}
        position['hover_height']=placement['hover'][species]
        normal=measured[name]
        bounds={a:{'min':[v/normal['scale'] for v in c['envelope_min']],
            'size':[v/normal['scale'] for v in c['envelope_size']]} for a,c in normal['clips'].items()}
        fixture['models'][identity]={'sha256':row['runtime_sha256'],'glb_sha256':row['glb_sha256'],'profile':name+'-'+variant}
        fixture['profiles'][name+'-'+variant]={'action_timing':row['action_timing'],'placement':position,
            'grounding':dict(position,lift=motion['lift']),'motion':motion,'bounds':bounds,
            'attack_family_actions':{'body_charge':'physical_attack_2'} if 'physical_attack_2' in row['animations'] else {}}
        inputs.append({'identity':identity,'path':row['runtime_path'],'sha256':row['runtime_sha256']})
    assert len(inputs)==2
    a,b=[copy.deepcopy(fixture['profiles'][name+'-'+v]) for v in ('normal','shiny')]
    a['motion'].pop('sha256');b['motion'].pop('sha256');assert a==b
    write(destination/'runtime-fixture.json',fixture)
    write(destination/'texture-input.json',{'models':inputs,'production_namespace':True,
        'source_index_sha256':sha(destination/'runtime-fixture.json')})
    return destination


def packs(name,destination,generated):
    codec=Zstd();pair=read(generated)['pairs'][0]
    assert pair['species']==name and len(pair['models'])==2
    policy_path=destination/'packing-policy.json'
    policy=read(policy_path) if policy_path.exists() else {'mode':'shared-textures'}
    assert policy['mode'] in ('shared-textures','native-scenes')
    output=destination/'shared';(output/'packs').mkdir(parents=True,exist_ok=True)
    files={};appearances=[];render={'models':[],'packs':[]}
    for row in pair['models']:
        assert sha(row['candidate_path'])==row['candidate_sha256'] and sha(row['source_path'])==row['source_sha256']
        scene_path=row['source_path'] if policy['mode']=='native-scenes' else row['candidate_path']
        raw=decode(Path(scene_path).read_bytes(),codec)
        native=encode(raw,262144,19,codec);assert decode(native,codec)==raw
        path='models/'+row['variant']+'.scn';files[path]=native
        appearances.append({'variant':row['variant'],'runtime_identity':row['identity'],'runtime_path':path,
            'runtime_sha256':digest(native),'bytes':len(native),'source_sha256':row['source_sha256'],
            'cache_source_bytes':Path(row['source_path']).stat().st_size,'semantic_sha256':row['semantic_sha256']})
        render['models'].append({'identity':row['identity'],'source_path':row['source_path'],'source_sha256':row['source_sha256'],
            'candidate_path':pair['namespace']+'/'+path,'candidate_sha256':digest(native)})
    for path in sorted((Path(pair['directory'])/'textures').glob('*.res')):
        if policy['mode']=='native-scenes':continue
        raw=decode(path.read_bytes(),codec);native=encode(raw,262144,19,codec)
        assert decode(native,codec)==raw;files['textures/'+path.name]=native
    manifest={'schema':1,'kind':'pokeaether-model-pair','asset_id':'pokemon_3d:'+name+':base','species_id':name,
        'form_id':'base','version':1,'dependencies':[],'appearances':appearances,'resource_root':pair['namespace'],
        'files':[{'path':n,'bytes':len(b),'sha256':digest(b),'decoded_bytes':struct.unpack_from('<I',b,12)[0]} for n,b in sorted(files.items())]}
    files['bundle.json']=encoded(manifest);data=pack_pck(files,pair['namespace'])
    filename='v1-'+digest(data)+'.pck';path=output/'packs'/filename;path.write_bytes(data)
    dex=next(r['national_dex'] for r in read(INTAKE)['entries'] if r['species']==name)
    asset={k:manifest[k] for k in ('asset_id','species_id','form_id','version','dependencies','appearances')}
    asset.update(format='model-pair-pck-v1',national_dex=dex,pair_manifest=manifest,sha256=digest(data),size_bytes=len(data),
        object_key='optional-assets/pokemon_3d/'+name+'/base/'+filename)
    if policy['mode']=='native-scenes':asset['packing_mode']=policy['mode']
    index={'schema':1,'kind':'pokeaether-optional-asset-index','catalog_revision':'alternate-forms-local-v1',
        'runtime_contract':{'pokemon_3d':2,'godot':'4.6'},'assets':[asset]}
    pin={'path':str(path),'asset':asset};render['packs']=[pin]
    write(output/'index.json',index);write(output/'render-input.json',render)
    write(output/'validate-input.json',{'jobs':[{'asset_id':asset['asset_id'],'packs':{'shared':pin},'models':pair['models']}]})


def qualify(name):
    destination=prepare(name)
    data=ROOT.parent/'.runtime/alternate-forms'/name/'xdg-data'
    data.mkdir(parents=True,exist_ok=True)
    command=[str(ROOT.parents[2]/'ops/worktrees/slot-env'),ROOT.parent.name,'--',
        'env','XDG_DATA_HOME='+str(data),'godot']
    project=WORK/'runtime-project';shared=destination/'shared'
    env=dict(os.environ,POKEAETHER_FORM_BUNDLE_WORK=str(destination),POKEAETHER_FORM_BATCH_SHARED='1',
        POKEAETHER_CATALOG_WORK_ROOT=str(WORK))
    def run(label,arguments):
        with (destination/(label+'.log')).open('w') as log:
            subprocess.run(command+arguments,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
        contents=(destination/(label+'.log')).read_text()
        assert 'ERROR:' not in contents and 'SCRIPT ERROR' not in contents, label
    generated=project/'.tmp/texture-pairs'/name
    if not (generated/'report.json').exists():
        run('textures',['--headless','--path',str(project),'--script','res://tools/sprite_factory/model_pair_texture_probe.gd','--',
            str(destination/'texture-input.json'),str(generated)])
    packs(name,destination,generated/'report.json')
    if not (shared/'validated/receipts.jsonl').exists():
        run('validate',['--headless','--path',str(project),'--script','res://tools/sprite_factory/shared_model_catalog_probe.gd','--',
            'validate',str(shared/'validate-input.json'),str(shared/'validated')])
    checked=[__import__('json').loads(line) for line in (shared/'validated/receipts.jsonl').read_text().splitlines()]
    assert len(checked)==1 and checked[0]['packs']['shared']['ok']
    if not (shared/'render-qualified/report.json').exists():
        run('pixels',['--path',str(ROOT),'--rendering-method','mobile','--script','res://tools/sprite_factory/alternate_forms_pair_render.gd','--',
            str(shared/'render-input.json'),str(shared/'render-qualified')])
    pixels=compare(shared/'render-qualified')
    assert len(pixels)==2 and all(r['pixels_exact'] for r in pixels), 'Pixel equality failed: '+str([r['identity'] for r in pixels if not r['pixels_exact']])
    write(shared/'pixel-comparison.json',{'complete':True,'models':pixels,'exact_frames':sum(len(r['frames']) for r in pixels)})
    marker='FORM_BATCH_RUNTIME_OK'
    if not (destination/'runtime-check.log').exists() or marker not in (destination/'runtime-check.log').read_text():
        run('runtime-check',['--path',str(ROOT),'--rendering-method','mobile','--script','res://tests/battle_3d_alternate_form_check.gd'])
    assert marker in (destination/'runtime-check.log').read_text()
    return {'species':name,'status':'delivery_checked','runtime_approved':False,'visual_approved':False,
        'index_sha256':sha(shared/'index.json'),'pixel_report_sha256':sha(shared/'pixel-comparison.json'),
        'runtime_check_sha256':sha(destination/'runtime-check.log')}


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('names',nargs='+');args=parser.parse_args()
    for name in args.names:
        try:result=qualify(name)
        except Exception as error:result={'species':name,'status':'held','reason':type(error).__name__+': '+str(error)}
        write(WORK/'status/delivery'/(name+'.json'),result)
        print('DELIVERY',name,result['status'],result.get('reason',''),flush=True)
