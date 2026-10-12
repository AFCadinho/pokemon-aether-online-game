"""Source-pinned renderer/state repair trials for the last three selected forms."""
import argparse
import copy
import os
from pathlib import Path
import subprocess
from remaining_forms_repair import ROOT,HERE,WORK,MODELS,SOURCE,read,write,sha,context
from scvi_material_probe import inspect_materials

PREVIOUS=ROOT/'.tmp/alternate-forms-batch-v1'


def rotom():
    context({'rotom-fan'})
    from alternate_forms_material_sources import prepare
    from catalog_galar_birds_candidates import material,verify
    row=next(r for r in read(HERE/'alternate_forms_source_intake.json')['entries'] if r['species']=='rotom-fan')
    verify(row,SOURCE)
    target=WORK/'export/rotom-fan'
    if not target.exists():target.symlink_to(PREVIOUS/'export/rotom-fan',target_is_directory=True)
    row=prepare(row)
    def native_colour(m,directory):
        assert m['colors']['UVScaleOffset']==[1,1,0,0]
        assert m['colors']['UVScaleOffset3']==[1,1,0,0]
        assert m['floats']['DisplacementHeight']==0 and m['floats']['EmissionIntensity']==1
        return (directory/Path(m['textures']['BaseColorMap']).with_suffix('.png')).read_bytes()
    result=material(row,SOURCE,WORK,static_effect_colour=native_colour)
    for entry in result['variants']:
        variant='shiny' if entry['species'].endswith('-shiny') else 'normal'
        table=WORK/'material-sources/rotom-fan'/('pm0479_15_00'+('_rare' if variant=='shiny' else '')+'.trmtr')
        materials={m['name']:m for m in inspect_materials(table)}
        records=[]
        for effect in entry['material_effects']['records']:
            assert effect['static_source_material'] and effect['height']==0 and effect['intensity']==1
            m=materials[effect['material']]
            native=table.parent/Path(m['textures']['BaseColorMap']).with_suffix('.png')
            assert sha(effect['color']['path'])==sha(native)
            records.append({'material':m['name'],**{f'layer_{i}':m['colors'][f'BaseColorLayer{i}'] for i in range(1,5)},
                            'layer_scales':[m['floats'][f'LayerMaskScale{i}'] for i in range(1,5)],
                            'base_sha256':sha(native),'mask_sha256':effect['LayerMaskMap']['sha256']})
        entry['independent_layer_sampling']=records
        entry['material_limitations']='Native independent base/layer-mask sampling; no texture resampling'
    result['status']='candidate'
    write(WORK/'status/material/rotom-fan.json',result)
    write(WORK/'renderer-sources/rotom-fan.json',row)
    print('ROTOM_LAYERED_CANDIDATES',len(result['variants']),flush=True)


def xerneas_material():
    context({'xerneas-neutral'})
    from alternate_forms_material_sources import prepare
    from catalog_galar_birds_candidates import material,verify
    from scvi_uv_probe import read_uv_tracks
    from effect_uv_samples import channel_samples
    import scvi_eye_motion
    row=read(WORK/'renderer-sources/xerneas-neutral.json');verify(row,SOURCE)
    row=prepare(row)
    result=material(row,SOURCE,WORK)
    directory=Path(row['source_directory'])
    neutral=directory/(row['actions']['idle']+'.tracm')
    for entry in result['variants']:
        neutral_tracks=copy.deepcopy(entry['visibility']['clips']['idle']['tracks'])
        assert all(len(t['keys'])==1 for t in neutral_tracks)
        for action,clip in entry['visibility']['clips'].items():
            clip.update(tracks=copy.deepcopy(neutral_tracks),source_path=str(neutral),source_sha256=sha(neutral))
        channels={a:str(directory/(motion+'.tracm')) for a,motion in row['actions'].items()}
        # ZA uses the generic IkCharacter label for its eye graph. Require its
        # explicit eye flag and identical base/shadow UV tracks before binding
        # the existing eye sampler to the whole baked eye surface.
        for path in channels.values():
            tracks=read_uv_tracks(Path(path),parameters=('UVScaleOffset','UVScaleOffset1'))
            for eye in ('l_eye','r_eye'):
                values={t['parameter']:[channel_samples(c,tracks['frames']-1) for c in t['channels']]
                        for t in tracks['tracks'] if t['material']==eye}
                assert values['UVScaleOffset']==values['UVScaleOffset1'], eye+' independently moving shadow UV'
        variant='_rare' if entry['species'].endswith('-shiny') else ''
        table=WORK/'material-sources/xerneas-neutral'/('pm0768_00_00'+variant+'.trmtr')
        original=scvi_eye_motion.inspect_materials
        def eye_labels(path):
            rows=original(path)
            for m in rows:
                if m['name'] in ('l_eye','r_eye'):
                    assert m['shaders'][0]['name']=='IkCharacter' and m['shaders'][0]['values']['EnableEyeOptions']=='True'
                    assert not any(k in m['textures'] for k in ('UpperEyelidColorMap','LowerEyelidColorMap'))
                    m['shaders']=[{'name':'Eye','values':{'EyelidType':'None'}}]
            return rows
        scvi_eye_motion.inspect_materials=eye_labels
        try:
            entry['eye_motion']=scvi_eye_motion.prepare({'material_source':str(table),'identity_intake':{
                'source_eye_material_diagnostic':'eyelid_source_uv','motion_channels':channels,
                'identity_evidence':{'source_sha256':{p:sha(p) for p in channels.values()}}}},entry['animations'],entry['glb_sha256'])
        finally: scvi_eye_motion.inspect_materials=original
        assert len(entry['eye_motion']['materials'])==2
        entry['neutral_state']={'source_path':str(neutral),'sha256':sha(neutral),'policy':'Keep source defaultwait neutral visibility in every action; retain all source geometry and own animations'}
    result['status']='candidate';write(WORK/'status/material/xerneas-neutral.json',result)
    print('XERNEAS_NEUTRAL_CANDIDATES',len(result['variants']),flush=True)


def runtime(name):
    job=WORK/'runtime-jobs'/name;job.mkdir(parents=True,exist_ok=True)
    material=read(WORK/'status/material'/(name+'.json'))
    stage=job/'stage.json';write(stage,material['variants'])
    output=job/'native'
    assert not output.exists(),'Use a new diagnostic revision for a retry'
    command=[str(ROOT.parents[2]/'ops/worktrees/slot-env'),ROOT.parent.name,'--','godot','--headless',
             '--path',str(WORK/'runtime-project'),'--script','res://tools/sprite_factory/remaining_forms_runtime.gd']
    env=dict(os.environ,POKEAETHER_3D_STAGE_REPORT=str(stage),POKEAETHER_3D_RUNTIME_OUTPUT=str(output))
    with (job/'conversion.log').open('w') as log:
        subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('phase',choices=['rotom','runtime','xerneas-export','xerneas-material']);p.add_argument('--only',default='rotom-fan');a=p.parse_args()
    assert os.environ.get('POKEAETHER_SLOT')==ROOT.parent.name
    if a.phase=='runtime': runtime(a.only)
    elif a.phase=='rotom': rotom()
    elif a.phase=='xerneas-material': xerneas_material()
    else:
        from catalog_galar_birds_candidates import export
        export(read(WORK/'renderer-sources/xerneas-neutral.json'), PREVIOUS/'za-sources', WORK)
