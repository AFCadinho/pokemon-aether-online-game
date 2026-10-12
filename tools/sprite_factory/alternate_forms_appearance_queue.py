"""Render each completed pair in the isolated diagnostic project; never approve it."""
import os
import subprocess
import time
from alternate_forms_batch import ROOT, INTAKE, WORK, read, write, sha, cohort_rows


def main():
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name
    names = {r['species'] for r in cohort_rows()}
    expected = len(names)
    command=[str(ROOT.parents[2]/'ops/worktrees/slot-env'),ROOT.parent.name,'--','godot',
        '--path',str(WORK/'runtime-project'),'--rendering-method','gl_compatibility',
        '--script','res://tools/sprite_factory/catalog_urshifu_appearance_review.gd']
    done={}
    while len(done)<expected:
        progressed=False
        for source in sorted((WORK/'status/runtime').glob('*.json')):
            row=read(source); name=row['species']
            if name not in names: continue
            if name in done: continue
            if row['status']=='held':
                record={'species':name,'status':'held','reason':'runtime: '+row['reason']}
            else:
                output=WORK/'appearance'/name;output.mkdir(parents=True,exist_ok=True)
                report=output/'godot-review.json'
                entries = [dict(r) for r in row['runtime_scenes']]
                if name in ('palkia-origin', 'zygarde-complete'):
                    # These large source models exceed the 12-unit diagonal guard in attacks.
                    # The generic 12-unit guard assumed a smaller model family.
                    # Review at half scale; native geometry and battle scale stay intact.
                    for entry in entries: entry['review_scale'] = .5
                if report.exists():
                    assert read(output/'catalog.json')['entries']==entries, 'Appearance cache belongs to a different runtime revision'
                write(output/'catalog.json',{'entries':entries})
                try:
                    if not report.exists():
                        with (output/'render.log').open('w') as log:
                            subprocess.run(command,env=dict(os.environ,POKEAETHER_PHASE5_REVIEW=str(output)),
                                stdout=log,stderr=subprocess.STDOUT,timeout=600,check=True)
                    review=read(report)
                    assert len(review['entries'])==2
                    failures={r['species']:r['errors'] for r in review['entries'] if r['errors']}
                    record={'species':name,'status':'rendered' if not failures else 'held',
                        'appearance_report_sha256':sha(report),'failures':failures,'visual_approved':False}
                except Exception as error:
                    record={'species':name,'status':'held','reason':str(error)}
            done[name]=record;progressed=True
            write(WORK/'status/appearance'/(name+'.json'),record)
            write(WORK/('appearance-status-'+os.environ.get('POKEAETHER_FORM_BATCH_COHORT','native')+'.json'),{'runtime_approved':False,'entries':sorted(done.values(),key=lambda r:r['species'])})
            print('APPEARANCE',name,record['status'],record.get('reason',record.get('failures',{})),flush=True)
        if not progressed:time.sleep(5)


if __name__=='__main__':main()
