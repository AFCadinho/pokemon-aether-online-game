"""Bounded eye UV clips for opt-in review models; no independent runtime clock."""
import hashlib
import math
from pathlib import Path
from effect_uv_samples import channel_samples
from scvi_material_probe import inspect_materials
from scvi_uv_probe import read_uv_tracks
from scvi_eyelid_binding import source_layers


def prepare(job, animations, glb_hash):
    intake = job['identity_intake']
    table = Path(job.get('official_rare_material_source', job['material_source']))
    source_materials = inspect_materials(table)
    materials = [m for m in source_materials if m['shaders'] and
                 all(s['name'] in ('Eye','EyeClearCoat') for s in m['shaders'])]
    extra = intake.get('source_eye_uv_materials', [])
    if not isinstance(extra, list) or len(set(extra)) != len(extra):
        raise ValueError('Invalid extra eye UV materials')
    for name in extra:
        matches = [m for m in source_materials if m['name'] == name]
        if (intake.get('source_emission_diagnostic') is not True or len(matches) != 1
                or [shader['name'] for shader in matches[0]['shaders']] != ['Standard']
                or not any(matches[0]['floats'].get('EmissionIntensityLayer' + str(i), 0) > 0 for i in range(1,5))
                or matches[0] in materials):
            raise ValueError('Unsupported extra emissive eye UV material')
        materials.append(matches[0])
    records = []
    for material in materials:
        has_lids = intake['source_eye_material_diagnostic'] == 'eyelid_source_uv'
        layers = source_layers(material) if has_lids else []
        names = ['UVScaleOffset'] + ['UVScaleOffset' + str(index) for _, index, _, _ in layers]
        defaults = {key:material['colors'][key] for key in names}
        record = {'material':material['name'],'defaults':defaults,'clips':{},'lids':[],
                  'repeat_uv': intake.get('source_emission_diagnostic') is True}
        if has_lids:
            for _, index, channel, colour in layers:
                parameter = 'UVScaleOffset' + str(index)
                path = table.parent / Path(material['textures'][channel]).with_suffix('.png')
                record['lids'].append({'parameter':parameter,'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'colour':material['colors'][colour]})
        for action, timing in animations.items():
            path = Path(intake['motion_channels'][action]);digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if digest != intake['identity_evidence']['source_sha256'].get(str(path)):
                raise ValueError('Eye animation source changed')
            data = read_uv_tracks(path, parameters=tuple(names))
            tracks = [t for t in data['tracks'] if t['material'] == material['name']]
            duration = timing['duration']
            values = {key:[[0.0,default]] for key,default in defaults.items()}
            seen = {}
            for track in tracks:
                key = track['parameter']
                if (not 1 <= data['fps'] <= 240
                        or abs((data['frames']-1)/data['fps'] - duration) > 1e-5
                        or any(c != [data['config_flag'],data['frames'],data['fps']] for c in data['nested_timing'])):
                    raise ValueError('Eye clip clock or target mismatch')
                if key in seen:
                    if track != seen[key]:
                        raise ValueError('Conflicting duplicate eye UV track')
                    continue  # Exact duplicate source timelines carry the same keys.
                seen[key] = track
                channels = [channel_samples(c,data['frames']-1) for c in track['channels']]
                frames = [list(v) for v in zip(*channels,strict=True)]
                if any(v[0] <= 0 or v[1] <= 0 or not all(math.isfinite(x) for x in v) for v in frames):
                    raise ValueError('Invalid animated eye UV')
                # Preserve native frame samples. Adjacent identical values need
                # only the first/last key; do not fit away changes or steps.
                values[key] = [[i/data['fps'],v] for i,v in enumerate(frames)
                               if i in (0,len(frames)-1) or v != frames[i-1] or v != frames[i+1]]
            record['clips'][action]={'duration':duration,'loop':timing['loop'],'source_sha256':digest,'parameters':values}
        records.append(record)
    return {'schema':1,'glb_sha256':glb_hash,'materials':records,'review_required':True,
            'limitations':'PBR eye layers and native UV samples; native clearcoat/shadow-mask shader is approximated'}
