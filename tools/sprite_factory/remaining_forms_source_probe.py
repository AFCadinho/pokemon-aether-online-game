"""Read archived visibility, nested custom properties and non-bone animation channels."""
import hashlib
import json
from pathlib import Path
import sys
import bpy


def plain(value):
    if hasattr(value,'to_dict'):return {k:plain(v) for k,v in value.items()}
    if hasattr(value,'to_list'):return [plain(v) for v in value]
    if isinstance(value,(str,int,float,bool)) or value is None:return value
    try:return [plain(v) for v in value]
    except TypeError:return repr(value)


def props(owner):
    return {k:plain(v) for k,v in owner.items()}


def animation(owner):
    data=owner.animation_data
    if not data:return None
    return {'action':data.action.name if data.action else None,
            'drivers':[{'path':c.data_path,'index':c.array_index,'expression':c.driver.expression,
                        'variables':[{'name':v.name,'type':v.type,'targets':[{'id':t.id.name if t.id else None,'path':t.data_path,'bone':t.bone_target} for t in v.targets]} for v in c.driver.variables]} for c in data.drivers],
            'nla':[{'name':t.name,'mute':t.mute,'strips':[{'name':s.name,'action':s.action.name if s.action else None,'start':s.frame_start,'end':s.frame_end} for s in t.strips]} for t in data.nla_tracks]}


def main(job):
    for source in job['sources']:
        path=Path(source['path']);pin=hashlib.sha256(path.read_bytes()).hexdigest();assert pin==source['sha256']
        out=Path(source['output']);out.parent.mkdir(parents=True,exist_ok=True)
        assert not out.exists()
        bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False,use_scripts=False)
        result={'source':str(path),'source_sha256':pin,'worker_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'objects':[{'name':o.name,'type':o.type,'parent':o.parent.name if o.parent else None,'properties':props(o),
                        'hide_render':o.hide_render,'hide_viewport':o.hide_viewport,'hide_get':o.hide_get(),
                        'collections':[c.name for c in o.users_collection],'animation':animation(o),
                        'modifiers':[{'name':m.name,'type':m.type,'show_render':m.show_render,'show_viewport':m.show_viewport} for m in o.modifiers]} for o in bpy.data.objects],
            'collections':[{'name':c.name,'hide_render':c.hide_render,'hide_viewport':c.hide_viewport} for c in bpy.data.collections],
            'materials':[{'name':m.name,'properties':props(m),'animation':animation(m),'node_animation':animation(m.node_tree) if m.node_tree else None} for m in bpy.data.materials],
            'node_groups':[{'name':t.name,'properties':props(t),'animation':animation(t)} for t in bpy.data.node_groups],
            'images':[{'name':i.name,'size':list(i.size),'colorspace':i.colorspace_settings.name,'packed_sha256':hashlib.sha256(i.packed_file.data).hexdigest() if i.packed_file else None} for i in bpy.data.images],
            'actions':[]}
        for a in bpy.data.actions:
            curves=[c for l in a.layers for s in l.strips for b in s.channelbags for c in b.fcurves]
            extra=[{'path':c.data_path,'index':c.array_index,'keys':[[list(k.co),k.interpolation] for k in c.keyframe_points]} for c in curves if not c.data_path.startswith('pose.bones[')]
            result['actions'].append({'name':a.name,'range':list(a.frame_range),'curve_count':len(curves),'non_bone_curves':extra})
        out.write_text(json.dumps(result,indent=2)+'\n');print('SOURCE_DETAIL',path.name,flush=True)


if __name__=='__main__':main(json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text()))
