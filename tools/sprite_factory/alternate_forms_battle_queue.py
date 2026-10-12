"""Measure every native candidate independently; retain placement failures."""
import os
import argparse
import subprocess
import time
from alternate_forms_batch import ROOT, INTAKE, WORK, read, write, sha, cohort_rows
from catalog_mega_battle_calibrate import calibrate


def main(shard=0, shards=1, only=None):
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name
    names = sorted(r['species'] for r in cohort_rows() if not only or r['species'] in only)
    selected = set(names[shard::shards])
    expected = len(selected)
    control = next(r for r in read(ROOT/'.tmp/urshifu-models-v1/battle/catalog.json')['entries'] if r['species']=='dragonite')
    assert sha(control['path']) == control['glb_sha256']
    command = [str(ROOT.parents[2]/'ops/worktrees/slot-env'), ROOT.parent.name, '--', 'godot',
        '--path', str(WORK/'runtime-project'), '--rendering-method', 'gl_compatibility']
    done = {}
    while len(done) < expected:
        progressed = False
        for source in sorted((WORK/'status/appearance').glob('*.json')):
            state = read(source); name = state['species']
            if name not in selected: continue
            if name in done: continue
            if state['status'] != 'rendered':
                record = {'species':name, 'status':'held', 'reason':'Appearance check did not pass'}
            else:
                output = WORK/'battle'/name; output.mkdir(parents=True,exist_ok=True)
                runtime = WORK/'runtime-jobs'/name/'native/report.json'
                rows = read(runtime)
                for row in rows:
                    assert sha(row['runtime_path']) == row['runtime_sha256']
                    row['battle_review_poses'] = [[a,f] for a,f in [('idle',0),('physical_attack',.5),
                        ('physical_attack_2',.5),('special_attack',.5),('sleep',.5),('faint_start',1),('faint_loop',.5)] if a in row['animations']]
                if (output/'baseline/battle-review.json').exists():
                    assert read(output/'catalog.json')['entries']==rows+[control], 'Battle cache belongs to a different runtime revision'
                write(output/'catalog.json', {'entries':rows+[control]})
                env = dict(os.environ, POKEAETHER_PHASE5_REVIEW=str(output),
                    POKEAETHER_PHASE5_FRONTEND=str(ROOT), POKEAETHER_PHASE5_RUNTIME_REPORT=str(runtime))
                try:
                    for phase in ('baseline','final'):
                        report = output/phase/'battle-review.json'
                        if not report.exists():
                            env['POKEAETHER_PHASE5_BATTLE_OUTPUT'] = str(report.parent)
                            script = 'catalog_mega_battle_review.gd'
                            if phase == 'final':
                                env.update(POKEAETHER_PHASE5_CANDIDATES=str(output/'placement.json'),
                                    POKEAETHER_MEGA_MEASUREMENT_BASELINE=str(output/'baseline/battle-review.json'))
                                script = 'catalog_urshifu_battle_review.gd'
                            with (output/(phase+'.log')).open('w') as log:
                                subprocess.run(command+['--script','res://tools/sprite_factory/'+script],
                                    env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1200)
                        measured = read(report)
                        assert measured['complete']
                        if phase == 'baseline':
                            proposal = calibrate(measured, expected_pairs=1)
                            assert not proposal['motion_holds'], proposal['motion_holds']
                            retry = WORK/'battle-retries'/(name+'.json')
                            if retry.exists():
                                adjustment=read(retry)
                                assert adjustment=={'attack_clearance_pad':.02}
                                # Fixed conservative attack margin, independently
                                # checked against all native 120 Hz samples below.
                                for profile in proposal['motion'].values():
                                    for action,clip in profile['clips'].items():
                                        if action.startswith(('physical_attack','special_attack')):
                                            clip['offsets']=[v+.02 for v in clip['offsets']]
                                proposal['attack_clearance_pad']=.02
                            # Native floating poses already retain their source altitude.
                            # Additional hover is a separate review decision, never inferred.
                            proposal['hover'] = {r['species']:0.0 for r in rows}
                            write(output/'placement.json',proposal)
                    checked = [r for r in measured['entries'] if 'clips' in r]
                    assert len(checked)==2
                    for row in checked:
                        assert all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in row['shots'])
                        assert min(c['minimum_y'] for c in row['corrected_clearance_120hz'].values()) >= .025-1e-5
                    record = {'species':name,'status':'measured','visual_approved':False,
                        'battle_report_sha256':sha(report),'placement_sha256':sha(output/'placement.json')}
                except Exception as error:
                    record = {'species':name,'status':'held','reason':type(error).__name__+': '+str(error)}
            done[name]=record; progressed=True
            write(WORK/'status/battle'/(name+'.json'),record)
            write(WORK/f'battle-status-{os.environ.get("POKEAETHER_FORM_BATCH_COHORT","native")}-{shard}.json',{'runtime_approved':False,'entries':sorted(done.values(),key=lambda r:r['species'])})
            print('BATTLE',name,record['status'],record.get('reason',''),flush=True)
        if not progressed: time.sleep(5)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--shard',type=int,default=0)
    parser.add_argument('--shards',type=int,default=1)
    parser.add_argument('--only', help='Comma-separated subset of this cohort')
    args=parser.parse_args()
    assert 0 <= args.shard < args.shards <= 4
    main(args.shard,args.shards,set(args.only.split(',')) if args.only else None)
