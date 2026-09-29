"""Recover Marshadow's source-driven colour mask as embedded albedo frames.

Review-only: source skeletal clips, meshes and visibility are unchanged. Sample
native UV keys at their source frame rate and bake per mesh, because alternate
head meshes share an atlas but have different second UV sets.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops
from catalog_remaining_eye_bake import chunks, linear_to_srgb
from catalog_uv_mask_bake import raster
from effect_uv_samples import channel_samples
from scvi_material_probe import inspect_materials
from scvi_tracm import inspect_tracm
from scvi_uv_probe import read_uv_tracks


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def motion_samples(path, timing):
    config = inspect_tracm(path)
    if abs((config['frames']-1)/config['fps']-timing['frames']/60) > 1e-6 or config['loop'] != timing['loop']:
        raise ValueError('Source material and skeletal clocks differ')
    data = read_uv_tracks(path, parameters=('UVScaleOffsetLayerMask',))
    if data['actual_timeline_counts'] != data['declared_timeline_counts'] or any(
            c != [data['config_flag'], data['frames'], data['fps']] for c in data['nested_timing']):
        raise ValueError('Independent or inconsistent material timeline')
    tracks = [t for t in data['tracks'] if t['material'] == 'body_a']
    if not tracks or any(t != tracks[0] for t in tracks):
        raise ValueError('Missing or conflicting source mask tracks')
    values = list(zip(*(channel_samples(c, data['frames']-1) for c in tracks[0]['channels']), strict=True))
    if any(v[:3] != (1, 1, 0) for v in values):
        raise ValueError('Only the verified source vertical mask translation is supported')
    return {'fps': data['fps'], 'values': values}


def colour(base, mask, row):
    rgb = base.convert('RGB')
    for i, channel in enumerate(mask.split(), 1):
        values = row['colors']['BaseColorLayer' + str(i)]
        tint = Image.new('RGB', base.size, tuple(linear_to_srgb(v) for v in values[:3]))
        rgb = Image.composite(ImageChops.multiply(base.convert('RGB'), tint), rgb,
                              channel.point(lambda v: min(255, v*2)))
    rgb.putalpha(base.getchannel('A'))
    return rgb


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipt', type=Path, required=True)
    parser.add_argument('--motion', type=Path, required=True)
    parser.add_argument('--materials', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    prior = json.loads(args.receipt.read_text())
    pins = {**prior['input_sha256'], **prior['artifact_sha256']}
    used = {}

    def verify(path):
        path = Path(path).resolve()
        actual = digest(path)
        if pins.get(str(path)) != actual:
            raise ValueError('Unpinned or changed source: ' + str(path))
        used[str(path)] = actual
        return path

    candidates = [r for r in prior['variants'] if r['species'] == 'marshadow']
    if {r['variant'] for r in candidates} != {'normal', 'shiny'} or len(candidates) != 2:
        raise ValueError('Expected the pinned normal/shiny pair')
    if candidates[0]['action_timing'] != candidates[1]['action_timing']:
        raise ValueError('Normal and shiny skeletal clocks differ')
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    motion = {}
    for action, timing in candidates[0]['action_timing'].items():
        suffix = {'idle': '00001_battlewait01_loop', 'sleep': '00281_sleep01_loop',
                  'physical_attack': '00400_attack01', 'special_attack': '00450_rangeattack01',
                  'damage': '00500_damage01', 'faint_start': '00520_down01_start',
                  'faint_loop': '00521_down01_loop'}[action]
        path = verify(args.motion / ('pm0883_00_00_' + suffix + '.tracm'))
        motion[action] = {**motion_samples(path, timing), 'source': str(path), 'sha256': digest(path)}
    states = sorted({v for clip in motion.values() for v in clip['values']})
    result = {'schema': 1, 'runtime_approved': False, 'review_required': True, 'variants': []}
    masks = {}
    for candidate in candidates:
        variant = candidate['variant']
        verify(candidate['path']); verify(candidate['runtime_path'])
        table = verify(args.materials / ('pm0883_00_00' + ('_rare' if variant == 'shiny' else '') + '.trmtr'))
        row = next(r for r in inspect_materials(table) if r['name'] == 'body_a')
        base_path = verify(table.parent / Path(row['textures']['BaseColorMap']).with_suffix('.png').name)
        mask_path = verify(table.parent / Path(row['textures']['LayerMaskMap']).with_suffix('.png').name)
        if row['alpha_type'] != 'Opaque' or any(row['floats'].get('EmissionIntensityLayer'+str(i), 0) for i in range(1, 5)):
            raise ValueError('Expected the audited opaque nonemissive head material')
        if any(row['floats'].get('SpecularLayer'+str(i)+'Intensity', -1) != 0 for i in range(1, 5)):
            raise ValueError('Nonzero layer specular requires a separate animated specular bake')
        base = Image.open(base_path).convert('RGBA').resize((512, 512))
        source_mask = Image.open(mask_path).convert('RGBA')
        doc, binary = chunks(candidate['path'])
        indices = [i for i, m in enumerate(doc['materials']) if m['name'] == 'body_a']
        if len(indices) != 1:
            raise ValueError('Ambiguous material')
        material = indices[0]
        record = {**candidate, 'bindings': []}
        for node in doc['nodes']:
            if 'mesh' not in node:
                continue
            mesh = doc['meshes'][node['mesh']]
            if not any(p['material'] == material for p in mesh['primitives']):
                continue
            subset = {**doc, 'meshes': [mesh]}
            frames = []
            folder = args.output / variant / node['name']
            folder.mkdir(parents=True)
            for i, state in enumerate(states):
                key = digest(mask_path), hashlib.sha256(binary).hexdigest(), node['name'], state
                if key not in masks:
                    masks[key] = raster(subset, binary, material, source_mask, state, padding=8)
                mask, audit = masks[key]
                path = folder / ('frame-%03d.png' % i)
                colour(base, mask, row).save(path)
                frames.append({'path': str(path), 'sha256': digest(path), 'uv': list(state), **audit})
            clips = {}
            for action, clip in motion.items():
                keys = [[i/clip['fps'], states.index(v)] for i, v in enumerate(clip['values'])
                        if i == 0 or v != clip['values'][i-1]]
                timing = candidate['action_timing'][action]
                clips[action] = {'duration': timing['frames']/60, 'loop': timing['loop'],
                                 'source_sha256': clip['sha256'], 'keys': keys}
            record['bindings'].append({'mesh': node['name'], 'material': 'body_a', 'source_layer_specular': 0, 'frames': frames, 'clips': clips})
            print(variant, node['name'], 'frames=', len(frames), flush=True)
        if len(record['bindings']) != 4:
            raise ValueError('Expected four source head/effect mesh bindings')
        result['variants'].append(record)
    if any(digest(path) != value for path, value in used.items()):
        raise ValueError('Source changed during bake')
    result['source_sha256'] = used
    result['source_receipt_sha256'] = digest(args.receipt)
    (args.output / 'manifest.json').write_text(json.dumps(result, indent=2)+'\n')
    print('PREPARED', args.output / 'manifest.json', flush=True)


if __name__ == '__main__':
    main()
