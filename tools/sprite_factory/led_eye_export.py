"""Source-bound animated LED eye masks for explicitly reviewed emissive models."""
import hashlib
import math
from pathlib import Path
from scvi_material_probe import inspect_materials
from scvi_uv_probe import read_uv_tracks
from effect_uv_samples import channel_samples

UV_NAMES = ('UVScaleOffset', 'UVScaleOffset1')
SCALARS = ('FlipBookFrame', 'EmissionIntensity', 'LayerMaskScale1')


def prepare(job, animations, glb_hash):
    table = Path(job.get('official_rare_material_source', job['material_source']))
    expected = job.get('official_rare_material_sha256', job['material_source_sha256'])
    if hashlib.sha256(table.read_bytes()).hexdigest() != expected:
        raise ValueError('LED material source changed')
    intake = job['identity_intake']
    records = []
    for material in inspect_materials(table):
        shaders = material['shaders']
        if not any(s['name'] == 'Unlit' and s['values'].get('EnableOpacityMap') == 'True' for s in shaders):
            continue
        if (len(shaders) != 1 or material['alpha_type'] != 'Blend'
                or shaders[0]['values'].get('EnableOpacityMap1') != 'True'
                or shaders[0]['values'].get('EnableBaseColorMap') != 'False'
                or shaders[0]['values'].get('LayerMaskSource') != 'Const'):
            raise ValueError('Unsupported LED eye profile')
        color = material['colors']['BaseColor']
        grid = [material['floats']['FlipBookWidth'], material['floats']['FlipBookHeight']]
        if (len(color) != 4 or color[3] != 1 or not all(math.isfinite(x) and 0 <= x <= 16 for x in color)
                or any(not math.isfinite(x) or not 1 <= x <= 16 or x != int(x) for x in grid)):
            raise ValueError('Invalid LED colour or atlas dimensions')
        record = {'material': material['name'], 'color': color, 'grid': grid, 'textures': {}, 'clips': {}}
        for name in ('OpacityMap', 'OpacityMap1'):
            filename = material['textures'][name]
            if Path(filename).name != filename:
                raise ValueError('Unsafe LED texture path')
            path = table.parent / Path(filename).with_suffix('.png')
            record['textures'][name] = {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
        for action, timing in animations.items():
            path = Path(intake['motion_channels'][action])
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if digest != intake['identity_evidence']['source_sha256'].get(str(path)):
                raise ValueError('LED animation source changed')
            data = read_uv_tracks(path, parameters=UV_NAMES, scalar_parameters=SCALARS)
            if (not 1 <= data['fps'] <= 240 or abs((data['frames'] - 1) / data['fps'] - timing['duration']) > 1e-5
                    or any(c != [data['config_flag'], data['frames'], data['fps']] for c in data['nested_timing'])):
                raise ValueError('LED source clock mismatch')
            values = {k: [[0.0, material['colors'][k]]] for k in UV_NAMES}
            values.update({k: [[0.0, material['floats'][k]]] for k in SCALARS})
            seen = {}
            for track in data['tracks'] + data['scalar_tracks']:
                if track['material'] != material['name']:
                    continue
                key = track['parameter']
                if key in seen:
                    if track != seen[key]:
                        raise ValueError('Conflicting LED tracks')
                    continue
                seen[key] = track
                if key in UV_NAMES:
                    frames = list(map(list, zip(*(channel_samples(c, data['frames'] - 1) for c in track['channels']), strict=True)))
                else:
                    frames = channel_samples(track['keys'], data['frames'] - 1)
                values[key] = [[i / data['fps'], v] for i, v in enumerate(frames)
                               if i in (0, len(frames)-1) or v != frames[i-1] or v != frames[i+1]]
            for key, keys in values.items():
                for _, value in keys:
                    if key in UV_NAMES:
                        valid = len(value) == 4 and all(math.isfinite(x) for x in value) and min(value[:2]) > 0
                    else:
                        valid = math.isfinite(value) and value >= 0
                        if key == 'FlipBookFrame': valid = valid and value == int(value) and value < grid[0]*grid[1]
                    if not valid: raise ValueError('Invalid LED parameter: ' + key)
            record['clips'][action] = {'duration': timing['duration'], 'loop': timing['loop'],
                                      'source_sha256': digest, 'parameters': values}
        records.append(record)
    return {'schema': 1, 'glb_sha256': glb_hash, 'materials': records, 'review_required': True}
