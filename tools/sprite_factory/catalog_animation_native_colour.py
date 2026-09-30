"""Restore authored Biochao normal colours, preserving geometry and native clips."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

from catalog_remaining_eye_bake import append_png, write_glb
from catalog_remaining_shiny_glb import read_glb
from phase5_variant_parity import compare


HERE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def restore(row, normal_root, output):
    name = row['species']
    place = output / name
    place.mkdir(parents=True, exist_ok=True)
    source = None
    try:
        normal = normal_root / f"{row['national_dex']:04d}-{name}" / 'model.glb'
        if sha(normal) != row['normal_glb_sha256']:
            raise ValueError('Pinned normal GLB changed')
        document, binary = read_glb(normal)
        binary = bytearray(binary)
        member = row['source']['member']
        filename = Path(member).name
        if re.fullmatch(r'pm\d{4}\.blend', filename):
            filename = filename[:-6] + '_00.blend'
        source = place / filename
        with zipfile.ZipFile(row['source']['archive']) as archive:
            with archive.open(member) as stream, source.open('wb') as target:
                while chunk := stream.read(1024 * 1024):
                    target.write(chunk)
        if sha(source) != row['source_sha256']:
            raise ValueError('Archived source hash changed')
        materials = [{'name': m['name'], 'output': str(place / f'material-{i:03d}.png')}
                     for i, m in enumerate(document['materials'])]
        job = {'source': str(source), 'source_sha256': row['source_sha256'],
               'idle_action': row['actions']['idle'], 'materials': materials,
               'receipt': str(place / 'shader-receipt.json')}
        job_path = place / 'bake-job.json'
        job_path.write_text(json.dumps(job, indent=2) + '\n')
        worker = HERE / 'catalog_animation_material_worker.py'
        command = ['flatpak', 'run', '--unshare=network', '--nofilesystem=host',
                   '--filesystem=' + str(output), '--filesystem=' + str(HERE) + ':ro',
                   'org.blender.Blender', '--background', '--factory-startup',
                   '--disable-autoexec', '--python-exit-code', '1', '--python',
                   str(worker), '--', str(job_path)]
        with (place / 'bake.log').open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
        textures = []
        shader_receipt = json.loads((place / 'shader-receipt.json').read_text())
        if shader_receipt != [{'material': item['name'], 'native_emission_strength': 0}
                              for item in materials]:
            raise ValueError('Incomplete native shader evidence')
        for material, item in zip(document['materials'], materials):
            png = Path(item['output'])
            pbr = material['pbrMetallicRoughness']
            previous = pbr['baseColorTexture']
            old_texture = document['textures'][previous['index']]
            index = append_png(document, binary, png.read_bytes(),
                               material['name'] + '_native_source_colour', old_texture.get('sampler', 0))
            pbr['baseColorTexture'] = {'index': index, 'texCoord': previous.get('texCoord', 0)}
            pbr['baseColorFactor'] = [1, 1, 1, 1]
            # Blender exported a mask as emission despite zero authored strength.
            # Remove it only after the native graph proved emission disabled.
            material.pop('emissiveTexture', None)
            material.pop('emissiveFactor', None)
            material.get('extensions', {}).pop('KHR_materials_emissive_strength', None)
            textures.append({'material': material['name'], 'bake_sha256': sha(png)})
        target = place / 'model.glb'
        write_glb(target, document, binary)
        parity = compare(normal, target)
        export = json.loads(normal.with_name('export.json').read_text())
        export.update(path=str(target), glb_sha256=sha(target), runtime_approved=False,
                      authored_colour_bakes=textures, geometry_motion_sha256=parity)
        export['native_shader_receipt'] = shader_receipt
        (place / 'export.json').write_text(json.dumps(export, indent=2) + '\n')
        (place / 'job.json').write_text(json.dumps({'species': name,
            'source_sha256': row['source_sha256'], 'actions': row['actions']}, indent=2) + '\n')
        return {'species': name, 'status': 'exported', 'report': str(place / 'export.json'),
                'glb_sha256': sha(target), 'geometry_motion_sha256': parity,
                'runtime_approved': False}
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        return {'species': name, 'status': 'held', 'reason': str(error), 'runtime_approved': False}
    finally:
        if source is not None:
            source.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidates', type=Path, required=True)
    parser.add_argument('--normal-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--workers', type=int, choices=(1, 2), default=2)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    rows = json.loads(args.candidates.read_text())['entries']
    results = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for result in pool.map(lambda row: restore(row, args.normal_root.resolve(), output), rows):
            results.append(result)
            (output / 'status.json').write_text(json.dumps({'schema': 1,
                'runtime_approved': False, 'total': len(rows), 'processed': len(results),
                'entries': results}, indent=2) + '\n')
            print(result['species'], result['status'], result.get('reason', ''), flush=True)


if __name__ == '__main__':
    main()
