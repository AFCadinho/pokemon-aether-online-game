"""Convert and test completed native pairs individually; retain every hold."""
import os
from pathlib import Path
import subprocess
import time
from alternate_forms_batch import ROOT, HERE, INTAKE, WORK, read, write, sha, cohort_rows


def main():
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name
    rows = cohort_rows()
    project = WORK / 'runtime-project'; project.mkdir(exist_ok=True)
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Alternate forms qualification"\n[display]\nwindow/size/viewport_width=1152\nwindow/size/viewport_height=648\nwindow/vsync/vsync_mode=0\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    for name in ['tools','scripts','resources','data','tests','release']:
        link=project/name
        if not link.exists(): link.symlink_to(ROOT/name, target_is_directory=True)
    command = [str(ROOT.parents[2]/'ops/worktrees/slot-env'), ROOT.parent.name, '--', 'godot', '--headless', '--path', str(project)]
    results = {}
    while len(results) < len(rows):
        progressed = False
        for row in rows:
            name = row['species']
            if name in results: continue
            material_path = WORK/'status/material'/(name+'.json')
            if not material_path.exists(): continue
            material = read(material_path)
            if material['status'] != 'candidate':
                # Material fixes may still be running; don't snapshot a temporary hold
                # until both producer queues have reached every native entry.
                completed=WORK/('material-status-'+os.environ.get('POKEAETHER_FORM_BATCH_COHORT','native')+'.json')
                if not completed.exists(): continue
                done=read(completed)
                if len(done['entries']) != len(rows): continue
                result={'species':name,'status':'held','reason':'material: '+material['reason']}
            else:
                job=WORK/'runtime-jobs'/name; job.mkdir(parents=True,exist_ok=True)
                stage=job/'stage.json'; write(stage,material['variants'])
                output=job/'native'; report=output/'report.json'
                env=dict(os.environ,POKEAETHER_3D_STAGE_REPORT=str(stage),POKEAETHER_3D_RUNTIME_OUTPUT=str(output))
                try:
                    if not report.exists():
                        if output.exists(): raise ValueError('Previous conversion hold retained; use a new revision for retry')
                        with (job/'conversion.log').open('w') as log:
                            subprocess.run(command+['--script','res://tools/sprite_factory/alternate_forms_runtime.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
                    native=read(report)
                    assert len(native)==2
                    expected_glbs={v['species']:v['glb_sha256'] for v in material['variants']}
                    assert {v['species']:v['glb_sha256'] for v in native}==expected_glbs, 'Cached runtime is for a different material revision'
                    for entry in native:
                        assert sha(entry['path'])==entry['glb_sha256'] and sha(entry['runtime_path'])==entry['runtime_sha256']
                    transitions=job/'transitions.json'
                    env.update(POKEAETHER_FORM_BATCH_RUNTIME=str(report),POKEAETHER_FORM_BATCH_TRANSITIONS=str(transitions))
                    if not transitions.exists():
                        with (job/'transitions.log').open('w') as log:
                            subprocess.run(command+['--script','res://tools/sprite_factory/alternate_forms_transition_check.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
                    assert not read(transitions)['failures']
                    result={'species':name,'status':'native_candidate','runtime_scenes':native,
                        'source_material_status_sha256':sha(material_path),'transition_report_sha256':sha(transitions)}
                except Exception as error:
                    result={'species':name,'status':'held','reason':str(error)}
            results[name]=result; progressed=True
            write(WORK/'status/runtime'/(name+'.json'),result)
            write(WORK/('runtime-status-'+os.environ.get('POKEAETHER_FORM_BATCH_COHORT','native')+'.json'),{'runtime_approved':False,'entries':sorted(results.values(),key=lambda r:r['species'])})
            print('NATIVE',name,result['status'],result.get('reason',''),flush=True)
        if not progressed: time.sleep(5)


if __name__=='__main__': main()
