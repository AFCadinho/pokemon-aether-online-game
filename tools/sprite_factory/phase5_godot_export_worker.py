"""Direct GLB diagnostic export. Trusted worker, never saves source Blend files."""
import hashlib
import json
import math
from pathlib import Path
import re
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
        if job.get('legacy_material_diagnostic') is True:
            from catalog_remaining_legacy_material import validate
            validate(job)
        else:
            from scvi_identity import validate_export_job
            validate_export_job(job)
            from material_profiles import read_profiles, unsupported, TRANSPARENT_PROBE
            profiles = read_profiles(job['material_source'], job['material_source_sha256'],
                                     transparent_review=job.get('source_transparency_diagnostic') is True,
                                     displacement_review=job.get('identity_intake', {}).get('source_lit_displacement_diagnostic') is True)
            if unsupported(profiles):
                raise ValueError('Unsupported material profiles: ' + repr(unsupported(profiles)))
            if any(p.get('requires_effect_payload') for p in profiles):
                from material_effect_export import prepare
                effects = prepare(job)
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    rig, rig_selection = isolate(source, job.get('diagnostic_rig_selection'))
    from source_repairs import apply as apply_repair
    source_repair = apply_repair(job['source_sha256'], job['actions'].values())
    from authored_motion_review import author
    authored_motion = author(rig, job)
    quaternion_repair = []
    quaternion_clips = job.get('identity_intake', {}).get('quaternion_continuity_diagnostic')
    if quaternion_clips:
        from quaternion_continuity import apply as repair_quaternions
        quaternion_repair = repair_quaternions(job['actions'], quaternion_clips)
    float_overrides = job.get('verified_rare_float_overrides', [])
    color_overrides = job.get('verified_rare_color_overrides', [])
    unrepresented_rare_parameters = []
    if float_overrides or color_overrides or job.get('official_rare_material_source'):
        rare_table = Path(job['official_rare_material_source'])
        normal_table = Path(job['material_source'])
        if rare_table != normal_table.with_stem(normal_table.stem + '_rare'):
            raise ValueError('Rare material table is outside the verified source resource')
        if hashlib.sha256(rare_table.read_bytes()).hexdigest() != job['official_rare_material_sha256']:
            raise ValueError('Official rare material table changed')
        from scvi_material_probe import inspect_materials
        normal_rows = {row['name']: row for row in inspect_materials(Path(job['material_source']))}
        rare_rows = {row['name']: row for row in inspect_materials(rare_table)}
        from rare_material_parameters import FLOAT_SOCKETS, UNREPRESENTED_FLOATS
        for override in float_overrides:
            name, key = override['material'], override['key']
            if (name not in normal_rows or name not in rare_rows
                    or normal_rows[name]['floats'].get(key) != override['normal']
                    or rare_rows[name]['floats'].get(key) != override['rare']
                    or not all(math.isfinite(v) for v in (override['normal'], override['rare']))):
                raise ValueError('Rare float override differs from official tables')
            material = bpy.data.materials.get(override['material'])
            if material is None or material.node_tree is None:
                raise ValueError('Unbound rare float override')
            socket_key = FLOAT_SOCKETS.get(key, key)
            nodes = [node for node in material.node_tree.nodes if node.type == 'GROUP'
                     and socket_key in node.inputs]
            if override.get('mode') == 'unrepresented' and key in UNREPRESENTED_FLOATS:
                if nodes:
                    raise ValueError('Rare source float unexpectedly has a shader input')
                unrepresented_rare_parameters.append({'material': name, 'key': key,
                                                       'kind': 'float', 'reason': 'source_input_absent'})
                continue
            if override.get('mode') != 'apply' or key not in FLOAT_SOCKETS:
                raise ValueError('Unsupported rare float override')
            if len(nodes) != 1 or nodes[0].inputs[socket_key].is_linked:
                if job.get('legacy_material_diagnostic') is True:
                    unrepresented_rare_parameters.append({'material': name, 'key': key,
                                                           'kind': 'float', 'reason': 'source_input_unbound'})
                    continue
                raise ValueError('Ambiguous rare float shader input')
            socket = nodes[0].inputs[socket_key]
            if not math.isclose(socket.default_value, override['normal'], rel_tol=0, abs_tol=1e-5):
                raise ValueError('Embedded normal float differs from official source')
            socket.default_value = override['rare']
        from rare_material_parameters import COLOR_SOCKETS, UNREPRESENTED_COLORS, color_socket
        for override in color_overrides:
            name, key = override['material'], override['key']
            allowed = set(COLOR_SOCKETS) | UNREPRESENTED_COLORS
            if (key not in allowed or name not in normal_rows or name not in rare_rows
                    or normal_rows[name]['colors'].get(key) != override['normal']
                    or rare_rows[name]['colors'].get(key) != override['rare']
                    or len(override['normal']) != 4 or len(override['rare']) != 4
                    or override['normal'][3] != override['rare'][3]
                    or not 0.0 <= override['normal'][3] <= 1.0
                    or (color_socket(key, name) is not None and override['normal'][3] != 1.0)
                    or not all(math.isfinite(v) for v in override['normal'] + override['rare'])):
                raise ValueError('Rare colour override differs from supported official tables')
            material = bpy.data.materials.get(name)
            socket_key = color_socket(key, name) or key
            nodes = [n for n in material.node_tree.nodes if n.type == 'GROUP' and socket_key in n.inputs] if material and material.node_tree else []
            if override.get('mode') == 'unrepresented' and color_socket(key, name) is None:
                if material is None or nodes:
                    raise ValueError('Unrepresented colour unexpectedly has a shader input')
                unrepresented_rare_parameters.append({'material': name, 'key': key,
                                                       'kind': 'color', 'reason': 'source_input_absent'})
                continue
            if override.get('mode') != 'apply' or color_socket(key, name) is None:
                raise ValueError('Unsupported colour override mode')
            if len(nodes) != 1 or nodes[0].inputs[socket_key].is_linked:
                if job.get('legacy_material_diagnostic') is True:
                    unrepresented_rare_parameters.append({'material': name, 'key': key,
                                                           'kind': 'color', 'reason': 'source_input_unbound'})
                    continue
                raise ValueError('Unbound or ambiguous rare colour input')
            socket = nodes[0].inputs[socket_key]
            if not all(math.isclose(a, b, rel_tol=0, abs_tol=1e-5) for a, b in zip(socket.default_value, override['normal'], strict=True)):
                raise ValueError('Embedded normal colour differs from official source: ' + name + '/' + key)
            socket.default_value = override['rare']
    replacements = []
    unrepresented_textures = []
    for replacement in job.get('verified_texture_replacements', []):
        from array import array
        normal, rare = Path(replacement['normal']), Path(replacement['rare'])
        for path, key in ((normal, 'normal_sha256'), (rare, 'rare_sha256')):
            if hashlib.sha256(path.read_bytes()).hexdigest() != replacement[key]:
                raise ValueError('Variant texture source changed')
        # Blender may retain only the in-use .001 copy when the source Blend
        # is reopened. Verify every matching packed copy against official
        # normal pixels before remapping any of them to the rare texture.
        matches = [image for image in bpy.data.images if re.fullmatch(
            re.escape(normal.name) + r'(?:\.\d{3})?', image.name)]
        if replacement.get('unrepresented_channel'):
            from rare_material_parameters import unrepresented_eye_normal
            owners = [(row, channel) for row in normal_rows.values()
                      for channel, texture in row['textures'].items()
                      if Path(texture).with_suffix('.png').name == normal.name]
            if (replacement['unrepresented_channel'] != 'NormalMap1' or matches or not owners
                    or not all(unrepresented_eye_normal(row, channel)
                               and unrepresented_eye_normal(rare_rows[row['name']], channel)
                               and Path(rare_rows[row['name']]['textures'][channel]).with_suffix('.png').name in (normal.name, rare.name)
                               for row, channel in owners)):
                raise ValueError('Unrepresented eye normal map has an unexpected binding')
            unrepresented_textures.append(replacement)
            continue
        if not matches:
            raise ValueError('Embedded normal texture missing: ' + normal.name)
        reference = bpy.data.images.load(str(normal), check_existing=False)
        if any(image.colorspace_settings.name != matches[0].colorspace_settings.name for image in matches):
            raise ValueError('Embedded normal copies use different colour spaces')
        reference.colorspace_settings.name = matches[0].colorspace_settings.name
        b = array('f', [0]) * len(reference.pixels)
        reference.pixels.foreach_get(b)
        for existing in matches:
            if tuple(existing.size) != tuple(reference.size):
                raise ValueError('Embedded normal dimensions differ')
            a = array('f', [0]) * len(existing.pixels)
            existing.pixels.foreach_get(a)
            if a != b:
                raise ValueError('Embedded normal pixels differ from official source; UV binding not proven')
        shiny = bpy.data.images.load(str(rare), check_existing=False)
        shiny.colorspace_settings.name = matches[0].colorspace_settings.name
        # UV coordinates are normalized and the rare material table names this
        # exact replacement for the same channel. Official rare textures may
        # use a different resolution (Meloetta's layer mask is 128x256 rather
        # than 512x512); resizing them would change the authored pixels.
        bindings = replacement.get('material_bindings')
        if bindings is not None:
            if not isinstance(bindings, list) or not bindings or len(set(bindings)) != len(bindings):
                raise ValueError('Invalid material-specific texture binding list')
            expected = []
            for name, row in normal_rows.items():
                targets = {Path(rare_rows[name]['textures'][channel]).with_suffix('.png').name
                           for channel, texture in row['textures'].items()
                           if Path(texture).with_suffix('.png').name == normal.name}
                if len(targets) > 1:
                    raise ValueError('Shared texture needs different channels within one material')
                if targets == {rare.name}:
                    expected.append(name)
            if set(bindings) != set(expected):
                raise ValueError('Material-specific binding differs from official tables')
            nodes_to_replace = []
            for name in bindings:
                material = bpy.data.materials.get(name)
                nodes = [n for n in material.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image in matches] if material and material.node_tree else []
                if not nodes:
                    raise ValueError('Material-specific texture has no direct image binding: ' + name)
                nodes_to_replace.extend(nodes)
            for node in nodes_to_replace:
                node.image = shiny
        else:
            for existing in matches:
                existing.user_remap(shiny)
        shiny.pack()
        replacements.append(replacement)
    eye_material_repair = []
    eye_mode = job.get('identity_intake', {}).get('source_eye_material_diagnostic')
    if eye_mode:
        from scvi_eye_material_repair import apply as repair_eye_material
        eye_material_repair = repair_eye_material(
            Path(job.get('official_rare_material_source', job['material_source'])), eye_mode)
    inspection = inspect()
    if inspection['libraries'] or any(w.startswith('missing_texture:') for w in inspection['warnings']):
        raise ValueError('Source is not self-contained')
    baked = []
    response = None
    transparent = [p for p in profiles if p['profile'] == TRANSPARENT_PROBE] if profiles else []
    if job.get('identity_intake', {}).get('source_emission_diagnostic') is True:
        from scvi_material_probe import inspect_materials
        table = Path(job.get('official_rare_material_source', job['material_source']))
        expected = job.get('official_rare_material_sha256', job['material_source_sha256'])
        if hashlib.sha256(table.read_bytes()).hexdigest() != expected:
            raise ValueError('Emissive material source changed')
        source_materials = {m['name']: m for m in inspect_materials(table)}
        for profile in transparent:
            # The importer connects texture alpha but omits the native constant
            # BaseColor alpha. These thin lenses otherwise hide the LED meshes.
            alpha = source_materials[profile['material']]['colors']['BaseColor'][3]
            if not math.isfinite(alpha) or not 0 <= alpha <= 1:
                raise ValueError('Invalid native transparent base alpha')
            profile['source_base_alpha'] = alpha
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
            if not transparent and job.get('identity_intake', {}).get('source_emission_diagnostic') is not True and job.get('identity_intake', {}).get('source_pbr_metallic_diagnostic') is not True:
                from scvi_response_bake import bake
                response = bake(Path(job['output']) / 'response', exclude={e['material'] for e in effects})
            from battle_3d_export_probe import bake_color_materials
            baked = bake_color_materials(pbr=True, transparent={p['material'] for p in transparent},
                emissive=job.get('identity_intake', {}).get('source_emission_diagnostic') is True,
                metallic=job.get('identity_intake', {}).get('source_pbr_metallic_diagnostic') is True)
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
    excluded_by_source_view_layer = [obj.name for obj in bpy.context.scene.objects
                                     if obj.name not in bpy.context.view_layer.objects]
    for obj in bpy.context.view_layer.objects:
        if obj.type in ('MESH', 'ARMATURE'):
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.context.scene.frame_set(0)
    path = Path(job['output']) / 'model.glb'
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
        export_animation_mode='NLA_TRACKS', export_animations=True, export_force_sampling=True,
        export_hierarchy_flatten_bones=(job.get('native_flatten_bone_hierarchy_diagnostic') is True
            or job.get('identity_intake', {}).get('flatten_bone_hierarchy_diagnostic') is True),
        export_frame_range=False, export_reset_pose_bones=True, export_frame_step=1,
        export_cameras=False, export_lights=False, export_materials='EXPORT', export_yup=True,
        export_tangents=bool(baked))
    payload = path.read_bytes()
    length = struct.unpack_from('<I', payload, 12)[0]
    gltf = json.loads(payload[20:20 + length])
    actual = {a['name'] for a in gltf.get('animations', [])}
    if actual != set(timing):
        raise ValueError('Exported clips differ: ' + str(actual))
    if transparent:
        materials_by_name = {m.get('name'): m for m in gltf.get('materials', [])}
        for profile in transparent:
            material = materials_by_name.get(profile['material'])
            if material is None or material.get('alphaMode') != 'BLEND':
                raise ValueError('Transparent source surface lost GLB alpha: ' + profile['material'])
    if hashlib.sha256(source.read_bytes()).hexdigest() != job['source_sha256']:
        raise ValueError('Source modified during export')
    report = {'status': 'exported_for_review', 'path': str(path),
        'excluded_by_source_view_layer': excluded_by_source_view_layer,
        'glb_sha256': hashlib.sha256(payload).hexdigest(), 'bytes': len(payload),
        'animations': timing, 'source_warnings': inspection['warnings'], 'verified_texture_replacements': replacements,
        'rig_selection': rig_selection,
        'source_repair': source_repair,
        'authored_motion_review': authored_motion,
        'unrepresented_rare_textures': unrepresented_textures,
        'quaternion_continuity_repair': quaternion_repair,
        'flatten_bone_hierarchy': (job.get('native_flatten_bone_hierarchy_diagnostic') is True
            or job.get('identity_intake', {}).get('flatten_bone_hierarchy_diagnostic') is True),
        'eye_material_repair': eye_material_repair,
        'verified_rare_float_overrides': float_overrides,
        'verified_rare_color_overrides': color_overrides,
        'unrepresented_rare_parameters': unrepresented_rare_parameters,
        'material_profiles': profiles,
        'materials': gltf.get('materials', []), 'runtime_approved': False, 'baked_materials': baked,
        'material_limitations': ('PBR alpha diagnostic from source albedo; source refraction and view-dependent Fresnel are not reproduced'
            if transparent else 'PBR plus supported shadow-colour response baked at idle; alpha, emission and material animation remain unported'
            if baked else 'Direct glTF translation: source shader graphs and material animation are not certified')}
    if response is not None:
        response['glb_sha256'] = report['glb_sha256']
        response['source_sha256'] = job['source_sha256']
        report['material_response'] = response
    if transparent:
        report['transparent_diagnostic'] = {'schema': 1, 'materials': transparent,
                                            'visual_review_required': True,
                                            'glb_sha256': report['glb_sha256']}
    if eye_material_repair:
        from scvi_eye_motion import prepare as prepare_eye_motion
        report['eye_motion'] = prepare_eye_motion(job, timing, report['glb_sha256'])
        # Native PBR materials retain their animated UV and eyelid next-passes.
        # The optional response renderer replaces materials and loses those
        # properties, so these review scenes use the existing PBR runtime path.
        report.pop('material_response', None)
        report['material_limitations'] = report['eye_motion']['limitations']
    if job.get('identity_intake', {}).get('source_emission_diagnostic') is True:
        from led_eye_export import prepare as prepare_led
        report['led_eyes'] = prepare_led(job, timing, report['glb_sha256'])
        from scvi_eye_motion import prepare as prepare_emissive_eye_motion
        motion_job = {**job, 'identity_intake': {**job['identity_intake'], 'source_eye_material_diagnostic': 'emissive_source_uv'}}
        eye_motion = prepare_emissive_eye_motion(motion_job, timing, report['glb_sha256'])
        if eye_motion['materials']:
            report['eye_motion'] = eye_motion
        report['material_limitations'] = 'Source colour/emission and animated LED masks; interior parallax and native lighting are approximated'
    if job.get('identity_intake', {}).get('source_refraction_alpha_diagnostic') is True:
        if not transparent:
            raise ValueError('Alpha refraction diagnostic requires transparent source materials')
        report['transparent_diagnostic']['refraction_approximation'] = 'alpha_mix'
    if job.get('identity_intake'):
        report['identity_evidence'] = job['identity_intake']['identity_evidence']
        from visibility_export import prepare as prepare_visibility
        report['visibility'] = prepare_visibility(job['identity_intake'], timing, gltf,
                                                   report['glb_sha256'])
    if effect_payload is not None:
        effect_payload['glb_sha256'] = report['glb_sha256']
        report['material_effects'] = effect_payload
        report['material_limitations'] = ('PBR response plus source-driven layered smoke/fire reconstruction; '
            'colour-domain baking and mask/displacement semantics are not bit-exact original-game shader parity')
    if unrepresented_textures:
        report['material_limitations'] += '; secondary EyeClearCoat normal maps omitted by pinned importer in both variants'
    if unrepresented_rare_parameters:
        report['material_limitations'] += '; official rare shader parameters absent in Biochao source and require visual review'
    (Path(job['output']) / 'export.json').write_text(json.dumps(report, indent=2))


if __name__ == '__main__':
    run(json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text()))
