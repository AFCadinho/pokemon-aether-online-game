"""Export source-driven UV/displacement effect profiles, no species rules."""
import hashlib
import json
import math
from pathlib import Path
from material_profiles import classify, LAYERED, UNLIT_UV2, LIT
from scvi_material_probe import inspect_materials
from scvi_uv_probe import read_uv_tracks, validate_loop


def prepare(job):
    source = Path(job['material_source'])
    if hashlib.sha256(source.read_bytes()).hexdigest() != job['material_source_sha256']:
        raise ValueError('Effect material provenance changed')
    lit_review = job.get('identity_intake', {}).get('source_lit_displacement_diagnostic') is True
    materials = [m for m in inspect_materials(source) if classify(m, displacement_review=lit_review).get('requires_effect_payload')]
    stable_surface = job.get('identity_intake', {}).get('stable_surface_review_materials', [])
    if (not isinstance(stable_surface, list) or any(not isinstance(v, str) for v in stable_surface)
            or len(set(stable_surface)) != len(stable_surface)
            or set(stable_surface) - {m['name'] for m in materials}):
        raise ValueError('Invalid stable surface review selection')
    if not materials:
        return []
    directory = Path(job.get('effect_motion_dir', ''))
    if not directory.is_absolute() or not directory.is_dir():
        raise ValueError('Effect profile requires an explicit auxiliary motion directory')
    result = []
    for material in materials:
        profile = classify(material, displacement_review=lit_review)
        candidates = []
        for path in sorted(directory.glob('*loop01_loop.tracm')):
            data = read_uv_tracks(path)
            data['tracks'] = [t for t in data['tracks'] if t['material'] == material['name']]
            if not data['tracks']:
                continue
            default_audit = {}
            if material['name'] in job.get('identity_intake', {}).get('source_effect_uv_defaults_diagnostic', []):
                from effect_source_defaults import complete
                data, default_audit = complete(data, material, job, directory)
            from effect_uv_samples import sample_tracks
            allow_reset = job.get('identity_intake', {}).get('source_loop_reset_diagnostic') is True
            samples = sample_tracks(data, allow_endpoint_jump=allow_reset)
            tracks = {name: [[frames[0][i], frames[-1][i]] for i in range(4)] for name, frames in samples.items()}
            if set(tracks) != {'UVScaleOffset', 'UVScaleOffset3'}:
                raise ValueError('Effect needs both reviewed UV tracks')
            for values in tracks.values():
                # Constant scale and integer offset cycles ensure a seamless repeat.
                if any(a != b or a <= 0 for a,b in values[:2]) or (not allow_reset and any(abs((b-a)-round(b-a)) > 1e-5 for a,b in values[2:])):
                    raise ValueError('Nonperiodic effect UV loop')
            payload = {'loop_seconds': (data['frames']-1)/data['fps'], 'tracks': tracks, **default_audit}
            try:
                validate_loop(data)
            except ValueError:
                # Keep existing affine exports on the exact v1 shader. Dense
                # source-key playback has its own versioned runtime shader.
                payload['uv_samples'] = samples
            if allow_reset:
                payload.update(uv_samples=samples, source_loop_endpoint_reset=True)
            candidates.append((path, payload))
        if not candidates:
            # A few sources keep a constant effect transform on their selected
            # idle clip instead of supplying a separate auxiliary loop. This
            # fallback is valid only when every sampled UV value is constant.
            intake = job.get('identity_intake', {})
            idle_name = intake.get('motion_channels', {}).get('idle')
            idle = Path(idle_name) if idle_name else None
            hashes = intake.get('identity_evidence', {}).get('source_sha256', {})
            if (idle is not None and idle.is_file() and idle.parent.resolve() == directory.resolve()
                    and hashlib.sha256(idle.read_bytes()).hexdigest() == hashes.get(str(idle))):
                data = read_uv_tracks(idle)
                data['tracks'] = [t for t in data['tracks'] if t['material'] == material['name']]
                if data['tracks']:
                    from effect_uv_samples import sample_tracks
                    samples = sample_tracks(data)
                    if (set(samples) == {'UVScaleOffset', 'UVScaleOffset3'}
                            and all(frames and all(frame == frames[0] for frame in frames)
                                    and frames[0][0] > 0 and frames[0][1] > 0
                                    for frames in samples.values())):
                        tracks = {name: [[frames[0][i], frames[-1][i]] for i in range(4)]
                                  for name, frames in samples.items()}
                        candidates.append((idle, {'loop_seconds': (data['frames']-1)/data['fps'],
                                                  'tracks': tracks, 'uv_samples': samples}))
        if (not candidates and material['name'] in job.get('identity_intake', {}).get(
                'static_effect_material_diagnostic', [])):
            # Explicit review of source-static effects: retain native displacement
            # and prove no material UV track exists in this identity-bound bank.
            # Do not invent scrolling when the source has none.
            hashes = job['identity_intake']['identity_evidence']['source_sha256']
            paths = sorted(directory.glob('*.tracm'))
            if not paths:
                raise ValueError('Static effect requires a motion bank')
            for path in paths:
                if hashlib.sha256(path.read_bytes()).hexdigest() != hashes.get(str(path)):
                    raise ValueError('Static effect motion provenance changed')
                tracks = [t for t in read_uv_tracks(path)['tracks'] if t['material'] == material['name']]
                zero_displacement = (job.get('identity_intake', {}).get('zero_displacement_static_diagnostic') is True
                                     and material['floats'].get('DisplacementHeight') == 0.0
                                     and all(t['parameter'] == 'UVScaleOffset3' for t in tracks))
                if tracks and not zero_displacement:
                    raise ValueError('Static effect has an unhandled animated material track')
            values = {key: material.get('colors', {}).get(key)
                      for key in ('UVScaleOffset', 'UVScaleOffset3')}
            if any(not isinstance(v, list) or len(v) != 4 or
                   not all(math.isfinite(x) for x in v) or min(v[:2]) <= 0
                   for v in values.values()):
                raise ValueError('Static effect requires explicit finite source UV transforms')
            payload = {'loop_seconds': 1.0, 'static_source_material': True,
                       'tracks': {key: [[x, x] for x in value] for key, value in values.items()}}
            candidates = [(path, payload) for path in paths]
        if not candidates or len({json.dumps(c[1], sort_keys=True) for c in candidates}) != 1:
            raise ValueError('Missing or ambiguous auxiliary effect loop: ' + material['name'])
        record = {'material': material['name'], 'profile': profile['profile'], **candidates[0][1],
                  'motion_sources': [{'path': str(p), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p,_ in candidates],
                  'use_uv2': profile['profile'] in (LAYERED, UNLIT_UV2, LIT),
                  'height': material['floats']['DisplacementHeight'],
                  'intensity': material['floats']['EmissionIntensity'],
                  'alpha_cutoff': material['floats']['DiscardValue'] if profile['alpha_test'] else 0.0}
        if profile['profile'] == LIT and job.get('identity_intake', {}).get('single_uv_displacement_diagnostic') is True:
            record['single_uv_fallback_review'] = True
        if material['name'] in stable_surface:
            if profile['profile'] != LIT or not math.isfinite(record['height']) or record['height'] <= 0:
                raise ValueError('Stable surface review requires displaced lit material')
            record['authored_surface_review'] = {
                'mode': 'skeletal_surface_without_auxiliary_displacement',
                'source_height': record['height'],
                'limitation': 'Auxiliary surface ripple omitted to retain connected mesh seams'}
            record['height'] = 0.0
        reconstruction = job.get('identity_intake', {}).get('authored_effect_reconstruction', {}).get(material['name'])
        if reconstruction is not None:
            if (reconstruction != 'outward_rim_smoke_v1' or profile['profile'] != LAYERED
                    or 'uv_samples' in record or record.get('static_source_material')):
                raise ValueError('Unsupported authored effect reconstruction')
            record['authored_reconstruction'] = reconstruction
        for key in ('height','intensity','alpha_cutoff','loop_seconds'):
            if not math.isfinite(record[key]) or record[key] < 0:
                raise ValueError('Invalid effect scalar')
        for channel in ('LayerMaskMap','DisplacementMap'):
            filename = material['textures'][channel]
            if Path(filename).name != filename:
                raise ValueError('Invalid effect texture name')
            path = source.parent / Path(filename).with_suffix('.png')
            record[channel] = {'path':str(path), 'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        result.append(record)
    return result


def finish(records, output):
    import bpy
    output = Path(output)
    output.mkdir(exist_ok=False)
    for index, record in enumerate(records):
        mat = bpy.data.materials[record['material']]
        bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        links = bsdf.inputs['Base Color'].links
        if len(links) != 1 or links[0].from_node.type != 'TEX_IMAGE':
            raise ValueError('Effect requires a baked colour-domain texture')
        image = links[0].from_node.image
        path = output / f'{index}-color.png'
        image.filepath_raw, image.file_format = str(path), 'PNG'
        image.save()
        record['color'] = {'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and mat in list(o.data.materials)]
        if record.get('single_uv_fallback_review') and record['use_uv2']:
            fallback = []
            for obj in meshes:
                if len(obj.data.uv_layers) == 1:
                    source_uv = [tuple(v.uv) for v in obj.data.uv_layers[0].data]
                    layer = obj.data.uv_layers.new(name='ReviewDisplacementUV')
                    for target, uv in zip(layer.data, source_uv, strict=True):
                        target.uv = uv
                    fallback.append(obj.name)
            if fallback:
                record['authored_uv_binding'] = {'mode': 'duplicate_sole_uv_for_displacement_review',
                                                  'meshes': sorted(fallback)}
        if not meshes or any(len(o.data.uv_layers) < (2 if record['use_uv2'] else 1) for o in meshes):
            raise ValueError('Effect mesh missing required native UV set')
    return {'schema':1, 'records':records,
            'scope':'source-driven layered effect reconstruction; not bit-exact original-game shader parity'}
