"""Recover native material graphs over the UV domains actually used by a GLB.

Review candidates only. Sources, archive members and existing GLBs are pinned;
the material texture transform preserves every geometry/skin/animation accessor.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import math
from pathlib import Path
import struct
import zipfile

from catalog_remaining_eye_bake import append_png, chunks, write_glb
from catalog_shiny_za_17_probe import run_flatpak
from phase5_variant_parity import compare, signature

HERE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')


def used_domains(document, binary):
    points = {}
    for mesh in document['meshes']:
        for primitive in mesh['primitives']:
            index = primitive['material']
            material = document['materials'][index]
            texture = material['pbrMetallicRoughness']['baseColorTexture']
            if texture.get('texCoord', 0) != 0 or texture.get('extensions', {}).get('KHR_texture_transform'):
                raise ValueError('Original UV transform requires explicit composition')
            accessor = document['accessors'][primitive['attributes']['TEXCOORD_0']]
            if accessor['type'] != 'VEC2' or accessor['componentType'] != 5126 or 'sparse' in accessor:
                raise ValueError('Expected an explicit float VEC2 source UV accessor')
            view = document['bufferViews'][accessor['bufferView']]
            if view.get('buffer', 0) != 0:
                raise ValueError('External UV buffer')
            offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
            stride = view.get('byteStride', 8)
            for i in range(accessor['count']):
                uv = struct.unpack_from('<ff', binary, offset + i * stride)
                if not all(math.isfinite(value) for value in uv):
                    raise ValueError('Non-finite source UV')
                points.setdefault(index, []).append(uv)
    result = []
    for index, uv in points.items():
        extrema = [min(p[0] for p in uv), min(p[1] for p in uv),
                   max(p[0] for p in uv), max(p[1] for p in uv)]
        if all(v >= -1e-5 for v in extrema[:2]) and all(v <= 1 + 1e-5 for v in extrema[2:]):
            continue
        bounds = [math.floor(extrema[0]), math.floor(extrema[1]),
                  math.ceil(extrema[2]), math.ceil(extrema[3])]
        for axis in (0, 1):
            if bounds[axis + 2] == bounds[axis]:
                bounds[axis + 2] += 1
        width, height = bounds[2] - bounds[0], bounds[3] - bounds[1]
        # Blender UV V is 1 - glTF V. Baking a separate destination UV layer
        # leaves source shader adjustments active over this exact native domain.
        result.append({'material_index': index, 'material': document['materials'][index]['name'],
                       'used_uv_bounds': extrema, 'glb_uv_domain': bounds,
                       'source_uv_domain': [bounds[0], 1 - bounds[3], bounds[2], 1 - bounds[1]],
                       'offset': [-bounds[0] / width, -bounds[1] / height],
                       'scale': [1 / width, 1 / height]})
    return result


def recover(row, output):
    name = row['species']
    directory = output / name
    directory.mkdir(exist_ok=False)
    temporary = None
    try:
        original = Path(row['path'])
        if sha(original) != row['normal_glb_sha256']:
            raise ValueError('Original normal GLB changed')
        document, binary = chunks(original)
        domains = used_domains(document, binary)
        if not domains:
            return {'species': name, 'status': 'unchanged_first_tile', 'path': str(original),
                    'glb_sha256': sha(original), 'geometry_motion_sha256': signature(original),
                    'runtime_approved': False}
        native_job = json.loads((original.parent / 'bake-job.json').read_text())
        # Multi-rig archives use the original Blend basename as a source variant
        # identity. Preserve it while extracting into this isolated directory.
        source_name = Path(native_job['source']).name
        if Path(source_name).suffix != '.blend':
            raise ValueError('Expected the original native Blend source identity')
        temporary = directory / source_name
        archive = row['source']
        with zipfile.ZipFile(archive['archive']) as source:
            member = source.getinfo(archive['member'])
            if member.file_size != archive['bytes'] or f'{member.CRC:08x}' != archive['crc32']:
                raise ValueError('Original Blend archive member changed')
            temporary.write_bytes(source.read(member))
        if sha(temporary) != native_job['source_sha256']:
            raise ValueError('Pinned native Blend changed')
        items = [{'name': domain['material'], 'source_uv_domain': domain['source_uv_domain'],
                  'output': str(directory / f'material-{i:03d}.png')}
                 for i, domain in enumerate(domains)]
        job = {'source': str(temporary), 'source_sha256': sha(temporary),
               'idle_action': native_job['idle_action'], 'materials': items,
               'receipt': str(directory / 'shader-receipt.json')}
        write(directory / 'bake-job.json', job)
        write(directory / 'uv-bindings.json', domains)
        run_flatpak(HERE / 'catalog_animation_material_worker.py', directory / 'bake-job.json',
                    [(directory, ''), (HERE, ':ro')], directory / 'bake.log')
        packed = bytearray(binary)
        used = document.setdefault('extensionsUsed', [])
        if 'KHR_texture_transform' not in used:
            used.append('KHR_texture_transform')
        for domain, item in zip(domains, items):
            material = document['materials'][domain['material_index']]
            texture = material['pbrMetallicRoughness']['baseColorTexture']
            sampler = document['textures'][texture['index']].get('sampler', 0)
            texture['index'] = append_png(document, packed, Path(item['output']).read_bytes(),
                                          material['name'] + '_native_used_uv_domain', sampler)
            texture.setdefault('extensions', {})['KHR_texture_transform'] = {
                key: domain[key] for key in ('offset', 'scale')}
        target = directory / 'model.glb'
        write_glb(target, document, packed)
        result = {'species': name, 'variant': 'normal', 'status': 'native_uv_domain_candidate',
                  'path': str(target), 'source_sha256': sha(original), 'glb_sha256': sha(target),
                  'geometry_motion_sha256': compare(original, target), 'uv_bindings': domains,
                  'blend_sha256': job['source_sha256'], 'archive_member': archive,
                  'shader_receipt_sha256': sha(directory / 'shader-receipt.json'),
                  'policy': 'connected-native-graph-colour-alpha-over-actual-used-UV-domains-v1',
                  'alpha_policy': 'native evaluation, not identity with the erroneous first-tile bake',
                  'runtime_approved': False}
        write(target.with_suffix('.receipt.json'), result)
        return result
    except Exception as error:
        return {'species': name, 'status': 'held', 'reason': str(error), 'runtime_approved': False}
    finally:
        # Only the disposable extraction made by this invocation is removed.
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--intake', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--workers', type=int, choices=(1, 2), default=2)
    args = parser.parse_args()
    rows = json.loads(args.intake.read_text())['entries']
    if len({r['species'] for r in rows}) != len(rows):
        raise ValueError('Duplicate source identity')
    output = args.output.resolve()
    output.mkdir(exist_ok=False, parents=True)
    results = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for result in pool.map(lambda row: recover(row, output), rows):
            results.append(result)
            write(output / 'status.json', {'schema': 1, 'runtime_approved': False,
                                          'processed': len(results), 'total': len(rows), 'entries': results})
            print(len(results), result['species'], result['status'], result.get('reason', ''), flush=True)


if __name__ == '__main__':
    main()
