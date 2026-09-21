"""Direct GLB diagnostic export. Trusted worker, never saves source Blend files."""
import hashlib
import json
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).parent))
from blender_worker import inspect
from blender_action_state import select_action
from source_review_rigs import isolate


def run(job):
    source = Path(job['source'])
    if hashlib.sha256(source.read_bytes()).hexdigest() != job['source_sha256']:
        raise ValueError('Source hash changed')
    profiles = []
    effects = []
    if source.with_name('import.json').exists() and not job.get('material_source'):
        raise ValueError('Imported source needs material provenance; rerun source review')
    if job.get('material_source'):
        from material_profiles import read_profiles, unsupported
        profiles = read_profiles(job['material_source'], job['material_source_sha256'])
        if unsupported(profiles):
            raise ValueError('Unsupported material profiles: ' + repr(unsupported(profiles)))
        if any(p.get('requires_effect_payload') for p in profiles):
            from material_effect_export import prepare
            effects = prepare(job)
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    rig, rig_selection = isolate(source)
    from source_repairs import apply as apply_repair
    source_repair = apply_repair(job['source_sha256'], job['actions'].values())
    replacements = []
    for replacement in job.get('verified_texture_replacements', []):
        from array import array
        normal, rare = Path(replacement['normal']), Path(replacement['rare'])
        for path, key in ((normal, 'normal_sha256'), (rare, 'rare_sha256')):
            if hashlib.sha256(path.read_bytes()).hexdigest() != replacement[key]:
                raise ValueError('Variant texture source changed')
        matches = [image for image in bpy.data.images if image.name == normal.name]
        if len(matches) != 1:
            raise ValueError('Ambiguous embedded normal texture')
        existing = matches[0]
        reference = bpy.data.images.load(str(normal), check_existing=False)
        reference.colorspace_settings.name = existing.colorspace_settings.name
        if tuple(existing.size) != tuple(reference.size):
            raise ValueError('Embedded normal dimensions differ')
        a, b = array('f', [0]) * len(existing.pixels), array('f', [0]) * len(reference.pixels)
        existing.pixels.foreach_get(a)
        reference.pixels.foreach_get(b)
        if a != b:
            raise ValueError('Embedded normal pixels differ from official source; UV binding not proven')
        shiny = bpy.data.images.load(str(rare), check_existing=False)
        shiny.colorspace_settings.name = existing.colorspace_settings.name
        if tuple(shiny.size) != tuple(existing.size):
            raise ValueError('Rare texture dimensions differ')
        existing.user_remap(shiny)
        shiny.pack()
        replacements.append(replacement)
    inspection = inspect()
    if inspection['libraries'] or any(w.startswith('missing_texture:') for w in inspection['warnings']):
        raise ValueError('Source is not self-contained')
    baked = []
    response = None
    if job.get('scvi_pbr_probe'):
        materials = {m for o in bpy.context.scene.objects if o.type == 'MESH' for m in o.data.materials}
        matching = [m for m in materials if m.node_tree and any(
            n.type == 'GROUP' and 'BaseColorBake' in n.outputs for n in m.node_tree.nodes)]
        if matching and len(matching) != len(materials):
            raise ValueError('Mixed importer graphs require explicit review')
        if matching:
            # Bake at deterministic idle, not the pose left in the saved source.
            select_action(rig, bpy.data.actions[job['actions']['idle']])
            for track in rig.animation_data.nla_tracks:
                track.mute = True
            bpy.context.scene.frame_set(int(rig.animation_data.action.frame_range[0]))
            from scvi_response_bake import bake
            response = bake(Path(job['output']) / 'response', exclude={e['material'] for e in effects})
            from battle_3d_export_probe import bake_color_materials
            baked = bake_color_materials(pbr=True)
    effect_payload = None
    if effects:
        from material_effect_export import finish
        effect_payload = finish(effects, Path(job['output']) / 'effects')
    rig.animation_data_create()
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    for track in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(track)
    timing = {}
    fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    for name, original in job['actions'].items():
        action = bpy.data.actions[original]
        start, end = action.frame_range
        if end <= start:
            raise ValueError('Empty action: ' + name)
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        if len(action.slots) != 1:
            raise ValueError('Ambiguous action slot')
        strip.action_slot = action.slots[0]
        strip.action_frame_start, strip.action_frame_end = start, end
        strip.frame_start, strip.frame_end = 0, end - start
        track.mute = True
        timing[name] = {'source_action': original, 'duration': (end - start) / fps,
                        'fps': fps, 'loop': name in ('idle', 'sleep', 'faint_loop')}
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.context.scene.objects:
        if obj.type in ('MESH', 'ARMATURE'):
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.context.scene.frame_set(0)
    path = Path(job['output']) / 'model.glb'
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
        export_animation_mode='NLA_TRACKS', export_animations=True, export_force_sampling=True,
        export_frame_range=False, export_reset_pose_bones=True, export_frame_step=1,
        export_cameras=False, export_lights=False, export_materials='EXPORT', export_yup=True,
        export_tangents=bool(baked))
    payload = path.read_bytes()
    length = struct.unpack_from('<I', payload, 12)[0]
    gltf = json.loads(payload[20:20 + length])
    actual = {a['name'] for a in gltf.get('animations', [])}
    if actual != set(timing):
        raise ValueError('Exported clips differ: ' + str(actual))
    if hashlib.sha256(source.read_bytes()).hexdigest() != job['source_sha256']:
        raise ValueError('Source modified during export')
    report = {'status': 'exported_for_review', 'path': str(path),
        'glb_sha256': hashlib.sha256(payload).hexdigest(), 'bytes': len(payload),
        'animations': timing, 'source_warnings': inspection['warnings'], 'verified_texture_replacements': replacements,
        'rig_selection': rig_selection,
        'source_repair': source_repair,
        'material_profiles': profiles,
        'materials': gltf.get('materials', []), 'runtime_approved': False, 'baked_materials': baked,
        'material_limitations': ('PBR plus supported shadow-colour response baked at idle; alpha, emission and material animation remain unported'
            if baked else 'Direct glTF translation: source shader graphs and material animation are not certified')}
    if response is not None:
        response['glb_sha256'] = report['glb_sha256']
        response['source_sha256'] = job['source_sha256']
        report['material_response'] = response
    if effect_payload is not None:
        effect_payload['glb_sha256'] = report['glb_sha256']
        report['material_effects'] = effect_payload
        report['material_limitations'] = ('PBR response plus source-driven layered smoke/fire reconstruction; '
            'colour-domain baking and mask/displacement semantics are not bit-exact original-game shader parity')
    (Path(job['output']) / 'export.json').write_text(json.dumps(report, indent=2))


if __name__ == '__main__':
    run(json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text()))
