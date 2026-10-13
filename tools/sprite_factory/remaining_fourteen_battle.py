"""Qualify the fourteen accepted colour/visibility forms locally; never publish."""
import argparse
import os
import subprocess
from pathlib import Path
from catalog_galar_birds_candidates import read, write, sha
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
WORK = ROOT/'.tmp/remaining-fourteen-battle-v1'
PREVIEW = ROOT/'.tmp/remaining-colour-visibility-v1'
SLEEP = ROOT/'.tmp/remaining-forms-sleep-v1'
NAMES = ['burmy-sandy','burmy-trash','wormadam-sandy','wormadam-trash','cherrim-sunshine',
    'minior-blue','minior-green','minior-indigo','minior-meteor','minior-orange','minior-violet','minior-yellow',
    'cramorant-gorging','cramorant-gulping']
DEX = {'burmy':412,'wormadam':413,'cherrim':421,'minior':774,'cramorant':845}


def context():
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name
    import alternate_forms_batch as batch
    batch.WORK=WORK
    batch.INTAKE=WORK/'intake.json'
    batch.cohort_rows=lambda:read(batch.INTAKE)['entries']


def run(label, args, env=None):
    data=ROOT.parent/'.runtime/remaining-fourteen'/label/'xdg-data'
    data.mkdir(parents=True,exist_ok=True)
    command=[str(ROOT.parents[2]/'ops/worktrees/slot-env'),ROOT.parent.name,'--','env','XDG_DATA_HOME='+str(data),'godot']
    log=WORK/(label+'.log')
    with log.open('w') as handle:
        subprocess.run(command+args,env=env,stdout=handle,stderr=subprocess.STDOUT,check=True,timeout=1200)
    contents=log.read_text()
    assert 'ERROR:' not in contents and 'SCRIPT ERROR' not in contents,str(log)


def setup():
    preview=read(HERE/'remaining_forms_preview_result.json')
    sleep=read(HERE/'remaining_forms_sleep_result.json')
    for receipt in (preview,sleep):
        for path,digest in receipt['code_sha256'].items():
            target=ROOT/path if (ROOT/path).exists() else HERE/path
            assert sha(target)==digest, path
    assert sha(sleep['catalog']['path'])==sleep['catalog']['sha256']
    assert sha(sleep['check']['path'])==sleep['check']['sha256']
    rows=[]
    for catalog in (PREVIEW/'colour-review-v2/catalog.json',PREVIEW/'visibility-review-v2/catalog.json'):
        for row in read(catalog)['entries']:
            if row['species'] not in sleep['entries']:
                assert row['runtime_sha256']==preview['entries'][row['species']]['runtime_sha256']
                rows.append(row)
    rows+=read(sleep['catalog']['path'])['entries']
    assert len(rows)==28 and {r['base_species'] for r in rows}==set(NAMES)
    for row in rows:
        assert sha(row['runtime_path'])==row['runtime_sha256']
        assert sha(row['path'])==row['glb_sha256']
    WORK.mkdir(parents=True,exist_ok=True)
    write(WORK/'intake.json',{'entries':[{'species':n,'national_dex':DEX[n.split('-')[0]]} for n in NAMES]})
    write(WORK/'visual-acceptance.json',{'accepted':True,'user_statement':'is goed',
        'scope':'Previously approved colours/static form visibility plus repaired closed eyes and Cramorant sleep poses.',
        'preview_receipt_sha256':sha(HERE/'remaining_forms_preview_result.json'),
        'sleep_receipt_sha256':sha(HERE/'remaining_forms_sleep_result.json'),
        'previous_approval_sha256':sha(HERE/'remaining_forms_visual_approval.json'),
        'scenes':{r['species']:r['runtime_sha256'] for r in rows},'published':False})
    for name in NAMES:
        pair=sorted([r for r in rows if r['base_species']==name],key=lambda r:r['species'])
        assert len(pair)==2
        write(WORK/'candidates'/(name+'.json'),{'entries':pair})
        write(WORK/'status/appearance'/(name+'.json'),{'species':name,'status':'rendered'})
        if name.startswith('minior-'):write(WORK/'battle-retries'/(name+'.json'),{'all_clip_clearance_pad':.001})
    project=WORK/'runtime-project'
    if not project.exists():
        project.mkdir()
        for name in ('tools','scripts','resources','data'):
            (project/name).symlink_to(ROOT/name,target_is_directory=True)
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Fourteen forms qualification"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    print('FOURTEEN_SETUP_OK',flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=['setup','prepare','battle','delivery','ui','preview-parity'])
    parser.add_argument('--only',nargs='+',choices=NAMES)
    args=parser.parse_args();context()
    names=args.only or NAMES
    if args.phase=='setup':setup()
    elif args.phase=='prepare':
        for name in names:
            folder=WORK/'runtime-jobs'/name/'native'
            if (folder/'report.json').exists():continue
            run('prepare-'+name,(['--rendering-method','gl_compatibility'] if name.startswith('cramorant-') else ['--headless'])+['--path',str(WORK/'runtime-project'),
                '--script','res://tools/sprite_factory/'+('remaining_cramorant_eyes.gd' if name.startswith('cramorant-') else 'remaining_fourteen_prepare.gd'),'--',
                str(WORK/'candidates'/(name+'.json')),str(folder)])
            print('PREPARED',name,flush=True)
    elif args.phase=='battle':
        import alternate_forms_recovery_battle
        alternate_forms_recovery_battle.main(only=set(names))
        assert all(read(WORK/'status/battle'/(n+'.json'))['status']=='measured' for n in names)
    elif args.phase=='delivery':
        import alternate_forms_delivery
        for name in names:
            result=alternate_forms_delivery.qualify(name)
            write(WORK/'status/delivery'/(name+'.json'),result)
            print('DELIVERY_OK',name,flush=True)
    elif args.phase=='preview-parity':
        for name in names:
            assert name.startswith('cramorant-')
            native=read(WORK/'runtime-jobs'/name/'native/report.json')
            job=WORK/('preview-parity-'+name+'.json')
            write(job,{'fixture':str(WORK/'delivery'/name/'runtime-fixture.json'),'models':[
                {'identity':name+('@shiny' if r['variant']=='shiny' else ''),
                 'source_path':r['preview_runtime_path'],'source_sha256':r['preview_runtime_sha256'],
                 'candidate_path':r['runtime_path'],'candidate_sha256':r['runtime_sha256']} for r in native]})
            run('preview-parity-'+name,['--path',str(ROOT),'--rendering-method','mobile',
                '--script','res://tools/sprite_factory/remaining_cramorant_render.gd','--',str(job),
                str(WORK/'preview-parity'/name)])
            print('PREVIEW_PARITY_OK',name,flush=True)
    elif args.phase=='ui':
        for name in names:
            for renderer in ('gl_compatibility','mobile'):
                output=WORK/'ui'/name/renderer
                if (output/'report.json').exists():
                    assert read(output/'report.json')['complete']
                    log=WORK/('ui-'+name+'-'+renderer+'.log')
                    assert 'ERROR:' not in log.read_text() and 'SCRIPT ERROR' not in log.read_text()
                    continue
                env=dict(os.environ,POKEAETHER_FORM_BUNDLE_WORK=str(WORK/'delivery'/name),
                    POKEAETHER_FOURTEEN_UI_OUTPUT=str(output),
                    POKEAETHER_FOURTEEN_NATIVE=str(WORK/'runtime-jobs'/name/'native/report.json'))
                run('ui-'+name+'-'+renderer,['--path',str(ROOT),'--rendering-method',renderer,
                    '--script','res://tests/battle_3d_fourteen_check.gd'],env)
                assert read(output/'report.json')['complete']
                print('UI_OK',name,renderer,flush=True)


if __name__=='__main__':main()
