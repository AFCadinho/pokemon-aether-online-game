"""Export source-driven affine UV/displacement effect profiles, no species rules."""
import hashlib
import json
import math
from pathlib import Path
from material_profiles import classify, LAYERED, UNLIT
from scvi_material_probe import inspect_materials
from scvi_uv_probe import read_uv_tracks, validate_loop, affine_channel


def prepare(job):
    source = Path(job['material_source'])
    if hashlib.sha256(source.read_bytes()).hexdigest() != job['material_source_sha256']:
        raise ValueError('Effect material provenance changed')
    materials = [m for m in inspect_materials(source) if classify(m).get('requires_effect_payload')]
    if not materials:
        return []
    directory = Path(job.get('effect_motion_dir', ''))
    if not directory.is_absolute() or not directory.is_dir():
        raise ValueError('Effect profile requires an explicit auxiliary motion directory')
    result = []
    for material in materials:
        profile = classify(material)
        candidates = []
        for path in sorted(directory.glob('*loop01_loop.tracm')):
            data = read_uv_tracks(path)
            data['tracks'] = [t for t in data['tracks'] if t['material'] == material['name']]
            if not data['tracks']:
                continue
            validate_loop(data)
            tracks = {t['parameter']: [affine_channel(c, data['frames']-1) for c in t['channels']] for t in data['tracks']}
            if set(tracks) != {'UVScaleOffset', 'UVScaleOffset3'}:
                raise ValueError('Effect needs both reviewed UV tracks')
            for values in tracks.values():
                # Constant scale and integer offset cycles ensure a seamless repeat.
                if any(a != b or a <= 0 for a,b in values[:2]) or any(abs((b-a)-round(b-a)) > 1e-5 for a,b in values[2:]):
                    raise ValueError('Nonperiodic effect UV loop')
            candidates.append((path, {'loop_seconds': (data['frames']-1)/data['fps'], 'tracks': tracks}))
        if not candidates or len({json.dumps(c[1], sort_keys=True) for c in candidates}) != 1:
            raise ValueError('Missing or ambiguous auxiliary effect loop: ' + material['name'])
        record = {'material': material['name'], 'profile': profile['profile'], **candidates[0][1],
                  'motion_sources': [{'path': str(p), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p,_ in candidates],
                  'use_uv2': profile['profile'] == LAYERED,
                  'height': material['floats']['DisplacementHeight'],
                  'intensity': material['floats']['EmissionIntensity'],
                  'alpha_cutoff': material['floats']['DiscardValue'] if profile['alpha_test'] else 0.0}
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
        if not meshes or any(len(o.data.uv_layers) < (2 if record['use_uv2'] else 1) for o in meshes):
            raise ValueError('Effect mesh missing required native UV set')
    return {'schema':1, 'records':records,
            'scope':'source-driven layered effect reconstruction; not bit-exact original-game shader parity'}
