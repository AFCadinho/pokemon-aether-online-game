"""Bounded eye UV clips for opt-in review models; no independent runtime clock."""
import hashlib
import math
from pathlib import Path
from effect_uv_samples import channel_samples
from scvi_material_probe import inspect_materials
from scvi_uv_probe import read_uv_tracks


def prepare(job, animations, glb_hash):
    intake = job['identity_intake']
    table = Path(job.get('official_rare_material_source', job['material_source']))
    materials = [m for m in inspect_materials(table) if m['shaders'] and
                 all(s['name'] in ('Eye','EyeClearCoat') for s in m['shaders'])]
    records = []
    for material in materials:
        has_lids = intake['source_eye_material_diagnostic'] == 'eyelid_source_uv'
        names = ['UVScaleOffset'] + (['UVScaleOffset3','UVScaleOffset4'] if has_lids else [])
        defaults = {key:material['colors'][key] for key in names}
        record = {'material':material['name'],'defaults':defaults,'clips':{},'lids':[]}
        if has_lids:
            for channel,parameter,colour in [('UpperEyelidColorMap','UVScaleOffset3','BaseColorLayer7'),('LowerEyelidColorMap','UVScaleOffset4','BaseColorLayer8')]:
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
            seen = set()
            for track in tracks:
                key = track['parameter']
                if (key in seen or not 1 <= data['fps'] <= 240
                        or abs((data['frames']-1)/data['fps'] - duration) > 1e-5
                        or any(c != [data['config_flag'],data['frames'],data['fps']] for c in data['nested_timing'])):
                    raise ValueError('Eye clip clock or target mismatch')
                seen.add(key)
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
