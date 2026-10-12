"""Qualify the visually accepted Zygarde preview locally, without publication."""
import argparse
import os
import subprocess
from pathlib import Path
from catalog_galar_birds_candidates import read, write, sha

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
WORK = ROOT/'.tmp/zygarde-battle-v4'
PREVIEW = ROOT/'.tmp/zygarde-preview-v1'
NAME = 'zygarde-10'


def setup():
    receipt = read(HERE/'zygarde_preview_result.json')
    assert receipt['status'] == 'local_visual_preview' and not receipt['published']
    for path, digest in receipt['code_sha256'].items():
        assert sha(ROOT/path) == digest
    assert sha(PREVIEW/'stage.json') == receipt['stage_sha256']
    for renderer in receipt['renderers'].values():
        assert sha(renderer['report']) == renderer['sha256']
        assert all(not row['errors'] for row in read(renderer['report'])['entries'])
    rows = read(PREVIEW/'catalog.json')['entries']
    assert len(rows) == 2
    for row in rows:
        assert sha(row['runtime_path']) == row['runtime_sha256']
        assert sha(row['path']) == row['glb_sha256']
        row['action_timing'] = {a: {'frames':c['duration']*60, 'speed':1, 'loop':c['loop']}
                               for a,c in row['animations'].items()}
    WORK.mkdir(parents=True,exist_ok=True)
    write(WORK/'status/appearance'/(NAME+'.json'), {'species':NAME,'status':'rendered'})
    write(WORK/'intake.json', {'entries':[{'species':NAME,'national_dex':718}]})
    write(WORK/'visual-acceptance.json', {'species':NAME,'accepted':True,
        'user_statement':'ziet er goed uit', 'scope':'local preview normal and shiny; reconstructed core and shell',
        'preview_receipt_sha256':sha(HERE/'zygarde_preview_result.json'),
        'runtime_approved':False,'published':False})
    project = WORK/'runtime-project'
    if not project.exists():
        project.mkdir()
        for name in ('tools','scripts','resources','data'):
            (project/name).symlink_to(ROOT/name,target_is_directory=True)
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Zygarde battle qualification"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    print('ZYGARDE_BATTLE_SETUP_OK',flush=True)


def context():
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name
    import alternate_forms_batch as batch
    batch.WORK=WORK
    batch.INTAKE=WORK/'intake.json'
    batch.cohort_rows=lambda:read(batch.INTAKE)['entries']


def run(label, args, env=None):
    log=WORK/(label+'.log')
    command=[str(ROOT.parents[2]/'ops/worktrees/slot-env'),ROOT.parent.name,'--','godot']
    with log.open('w') as handle:
        subprocess.run(command+args,env=env,stdout=handle,stderr=subprocess.STDOUT,check=True,timeout=600)
    contents=log.read_text()
    assert 'ERROR:' not in contents and 'SCRIPT ERROR' not in contents, str(log)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=['setup','prepare','battle','delivery','ui'])
    args=parser.parse_args()
    context()
    if args.phase=='setup': setup()
    elif args.phase=='prepare':
        run('prepare', ['--headless','--path',str(WORK/'runtime-project'),
            '--script','res://tools/sprite_factory/zygarde_battle_prepare.gd','--',
            str(PREVIEW/'catalog.json'),str(WORK/'runtime-jobs'/NAME/'native')])
    elif args.phase=='ui':
        for renderer in ('gl_compatibility','mobile'):
            output=WORK/('ui-v3-'+renderer)
            env=dict(os.environ, POKEAETHER_FORM_BUNDLE_WORK=str(WORK/'delivery'/NAME),
                POKEAETHER_ZYGARDE_UI_OUTPUT=str(output),
                POKEAETHER_ZYGARDE_NATIVE=str(WORK/'runtime-jobs'/NAME/'native/report.json'))
            run('ui-'+renderer,['--path',str(ROOT),'--rendering-method',renderer,
                '--script','res://tests/battle_3d_zygarde_check.gd'],env)
            assert read(output/'report.json')['complete']
    elif args.phase=='battle':
        import alternate_forms_recovery_battle
        alternate_forms_recovery_battle.main(only={NAME})
        assert read(WORK/'status/battle'/(NAME+'.json'))['status']=='measured'
    elif args.phase=='delivery':
        import alternate_forms_delivery
        result=alternate_forms_delivery.qualify(NAME)
        write(WORK/'status/delivery'/(NAME+'.json'),result)
        print('ZYGARDE_DELIVERY_OK',flush=True)


if __name__=='__main__': main()
