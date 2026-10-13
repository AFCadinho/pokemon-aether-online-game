"""Isolate pinned legacy source geometry in a disposable Blender scene.

Missing Ash textures are authored review proposals, never recovered pixels.
"""
import hashlib,json,sys,math
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent))
from source_review_rigs import material_images

def main(job):
    source=Path(job['source']);assert hashlib.sha256(source.read_bytes()).hexdigest()==job['source_sha256']
    bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
    rig=bpy.data.objects[job['rig']];assert rig.type=='ARMATURE'
    members=[o for o in bpy.data.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
    assert members
    keep=set(members+[rig]); parent=rig.parent
    while parent:keep.add(parent);parent=parent.parent
    for o in list(bpy.data.objects):
        if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
    def visible(collection):
        collection.exclude=False;collection.hide_viewport=False
        for child in collection.children:visible(child)
    visible(bpy.context.view_layer.layer_collection)
    for c in bpy.data.collections:c.hide_render=False;c.hide_viewport=False
    for o in keep:o.hide_set(False);o.hide_render=False;o.hide_viewport=False
    used={name for o in members for mat in o.data.materials if mat for name in material_images(mat.node_tree)}
    authored=[]
    for image in list(bpy.data.images):
        if image.name not in used and image.type!='RENDER_RESULT':bpy.data.images.remove(image);continue
        if image.name not in used or image.packed_file:continue
        if min(image.size)>0:image.pack();continue
        assert job['species']=='greninja-ash', 'Unexplained missing source image'
        # Explicit first-pass painted texture proposal at 512 px. This is a new
        # texture, since the archive contains only broken image references.
        n=image.name; replacement=bpy.data.images.new('PAO_AUTHORED_'+n,width=512,height=512,alpha=True)
        colour=(.035,.29,.57,1)
        if 'BodyB' in n:colour=(.84,.36,.47,1)
        if 'BodyC' in n:colour=(.02,.75,.92,1)
        data=[]
        for y in range(512):
            for x in range(512):
                c=colour
                if 'Eye' in n:
                    u=(x/511-.5);v=(y/511-.5)
                    c=(.96,.96,.88,1)
                    if (u/.16)**2+(v/.30)**2<1:c=(.75,.045,.09,1)
                    if (u/.065)**2+(v/.24)**2<1:c=(.015,.02,.03,1)
                    if (u+.04)**2+(v-.1)**2<.002:c=(1,1,1,1)
                data.extend(c)
        replacement.pixels=data;replacement.pack();image.user_remap(replacement);bpy.data.images.remove(image)
        authored.append(n)
    recovered=[]
    if job['species']=='greninja-ash':
        original=bpy.data.actions['model_skeleton']
        for identifier in ['OBidle','OBattack1','OBattack3','OBhit','OBdown']:
            clone=original.copy();clone.name='RECOVERED_'+identifier
            for slot in list(clone.slots):
                if slot.identifier!=identifier:clone.slots.remove(slot)
            assert len(clone.slots)==1
            curves=[c for l in clone.layers for s in l.strips for b in s.channelbags for c in b.fcurves]
            assert len(curves)==618
            clone.use_fake_user=True
            recovered.append({'slot':identifier,'action':clone.name,'curves':len(curves),'range':list(clone.frame_range)})
    out=Path(job['output']);out.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out),check_existing=False)
    report={'runtime_approved':False,'source_sha256':job['source_sha256'],'prepared_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),
        'rig':rig.name,'meshes':[{'name':o.name,'materials':[m.name for m in o.data.materials],'vertices':len(o.data.vertices)} for o in members],
        'authored_missing_textures':authored,'recovered_action_slots':recovered,'worker_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    out.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main(json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text()))
