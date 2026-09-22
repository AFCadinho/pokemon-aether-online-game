"""Isolated Blender A/B skeleton diagnostic; emits JSON, never a usable model.

The sole intervention is a read-only redirection of the selected TRSKL read.
This is not an identity-gate bypass or a production import path.
"""
import builtins
import hashlib
import json
import sys
from pathlib import Path
import bpy

sys.path.insert(0,str(Path(__file__).parent))
from scvi_import_worker import load_importer
from blender_action_state import select_action
from source_clip_timing import preserve_constant_pose
from scvi_identity import sha


def digest(value):
    return hashlib.sha256(json.dumps(value,separators=(',',':'),allow_nan=False).encode()).hexdigest()


def matrix(m):
    return [list(row) for row in m]


def main(job):
    output=Path(job['output'])
    if output.exists():raise ValueError('New diagnostic output required')
    sys.path.insert(0,job['dependencies'])
    load_importer(Path(job['importer']))
    from pokeaether_scvi_importer.PokemonSwitch import from_trmdlsv
    from pokeaether_scvi_importer.gfbanm_importer import import_animation
    from pokeaether_scvi_importer.GFLib.Anim.Animation import AnimationT
    entry=job['entry'];rid=entry['identity'];directory=Path(entry['model_dir']).resolve()
    original=directory/(rid+'.trskl');reference=Path(entry['motion_dir'])/(rid+'.trskl')
    paths=[p for p in directory.iterdir() if p.is_file()]+[reference]+[Path(p) for p in entry['motions'].values() if p]
    hashes={str(p):sha(p) for p in paths}
    results=[]
    for variant in ('model','romfs'):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        with bpy.data.libraries.load(str(Path(job['importer'])/'SCVIShader.blend'),link=False) as (_, dest):
            dest.materials=['PokemonShader']
        saved_open=builtins.open
        reads=[]
        def redirected(file,mode='r',*args,**kwargs):
            if isinstance(file,(str,Path)) and Path(file).resolve()==original:
                if mode!='rb':raise ValueError('Skeleton access must be read-only')
                reads.append(str(reference if variant=='romfs' else original))
                file=reference if variant=='romfs' else original
            return saved_open(file,mode,*args,**kwargs)
        try:
            builtins.open=redirected
            from_trmdlsv(str(directory),rid+'.trmdl',False,False,True,False,True,False)
        finally:
            builtins.open=saved_open
        if len(reads)!=1:raise ValueError('Unexpected skeleton read count')
        rigs=[o for o in bpy.data.objects if o.type=='ARMATURE']
        if len(rigs)!=1:raise ValueError('Expected one source rig')
        rig=rigs[0]
        bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
        rest=digest([(b.name,b.parent.name if b.parent else None,matrix(b.matrix_local)) for b in rig.data.bones])
        mesh=digest([(o.name,[list(v.co) for v in o.data.vertices],
                      [[(g.group,g.weight) for g in v.groups] for v in o.data.vertices])
                     for o in sorted(bpy.data.objects,key=lambda o:o.name) if o.type=='MESH'])
        clips={}
        for category,path in entry['motions'].items():
            if not path:continue
            import_animation(bpy.context,path,False,0,False,False)
            native=AnimationT.InitFromPackedBuf(Path(path).read_bytes())
            action=bpy.data.actions[Path(path).stem]
            preserve_constant_pose(action,native.info,bpy.context.scene.render.fps)
            select_action(rig,action)
            for track in rig.animation_data.nla_tracks:track.mute=True
            poses=[]
            for frame in range(native.info.keyFrames):
                bpy.context.scene.frame_set(frame)
                poses.append([(b.name,matrix(b.matrix)) for b in rig.pose.bones])
            clips[category]={'frames':native.info.keyFrames,'fps':native.info.frameRate,'poses_sha256':digest(poses)}
        results.append({'variant':variant,'skeleton_read':reads[0],'rest_sha256':rest,'mesh_sha256':mesh,'clips':clips})
    if any(sha(p)!=h for p,h in hashes.items()):raise ValueError('Source mutated during diagnostic')
    a,b=results
    report={'schema':1,'species':entry['species'],'runtime_approved':False,'scope':'isolated_importer_behavior_not_original_game_semantics',
            'source_sha256':hashes,'importer_consumer_sha256':sha(Path(job['importer'])/'PokemonSwitch.py'),
            'rest_equal':a['rest_sha256']==b['rest_sha256'],'mesh_equal':a['mesh_sha256']==b['mesh_sha256'],
            'clips_equal':a['clips']==b['clips'],'entries':results}
    with output.open('x') as out:json.dump(report,out,indent=2)
    print('SKELETON_AB',report['rest_equal'],report['mesh_equal'],report['clips_equal'])


if __name__=='__main__':main(json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text()))
