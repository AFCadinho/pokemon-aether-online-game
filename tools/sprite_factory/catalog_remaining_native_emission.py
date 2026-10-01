"""Bake pinned source colour/alpha/emission over actual UV domains for review."""
import argparse
import copy
import hashlib
import json
import math
import re
from pathlib import Path
import zipfile
from concurrent.futures import ThreadPoolExecutor
from PIL import Image

from catalog_native_uv_domain_recovery import used_domains
from catalog_remaining_eye_bake import append_png, chunks, write_glb
from catalog_shiny_za_17_probe import run_flatpak
from phase5_variant_parity import compare

HERE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')


def recover(row, output):
    directory = output / row['species']
    directory.mkdir()
    source_name = Path(row['source']['member']).name
    if re.fullmatch(r'pm\d{4}\.blend', source_name):
        source_name = source_name[:-6] + '_00.blend'
    source = directory / source_name
    try:
        original = Path(row['normal_path'])
        if sha(original) != row['normal_glb_sha256']:
            raise ValueError('Pinned original GLB changed')
        document, binary = chunks(original)
        probe = copy.deepcopy(document)
        for material in probe['materials']:
            texture = material.setdefault('pbrMetallicRoughness', {}).setdefault('baseColorTexture', {'index': 0})
            if texture.get('texCoord', 0) != 0 or texture.get('extensions', {}).get('KHR_texture_transform', {}).get('texCoord', 0) != 0:
                raise ValueError('Native review requires the selected source UV0')
            # Re-evaluate the full native shader, including its own mappings,
            # over raw mesh UVs. The previous GLB's texture-only approximation
            # is replaced, not composed a second time into this full bake.
            texture.get('extensions', {}).pop('KHR_texture_transform', None)
        domains = {r['material_index']: r for r in used_domains(probe, binary)}
        with zipfile.ZipFile(row['source']['archive']) as archive:
            info = archive.getinfo(row['source']['member'])
            if info.file_size != row['source']['bytes'] or f'{info.CRC:08x}' != row['source']['crc32']:
                raise ValueError('Archived source member changed')
            source.write_bytes(archive.read(info))
        if sha(source) != row['source_sha256']:
            raise ValueError('Source SHA-256 differs')
        materials = []
        for i, material in enumerate(document['materials']):
            item = {'name': material['name'], 'output': str(directory / f'colour-{i}.png'),
                    'glow_output': str(directory / f'glow-{i}.png')}
            if i in domains:
                item['source_uv_domain'] = domains[i]['source_uv_domain']
            if material['name'] in row.get('preserve_glass_materials', []):
                item['preserve_surface'] = 'BSDF_GLASS'
            if row.get('official_shiny_review'):
                item.update(row['official_shiny_review']['materials'].get(material['name'], {}))
            materials.append(item)
        job = {'source': str(source), 'source_sha256': row['source_sha256'],
               'idle_action': row['actions']['idle'], 'materials': materials,
               'constant_colour_review': True, 'receipt': str(directory / 'shader-receipt.json')}
        if row.get('official_shiny_review'):
            for key in ('normal_table', 'normal_table_sha256', 'rare_table', 'rare_table_sha256'):
                job[key] = row['official_shiny_review'][key]
        write(directory / 'bake-job.json', job)
        grants = [(directory, ''), (HERE, ':ro')]
        if row.get('official_shiny_review'):
            grants += [(parent, ':ro') for parent in sorted({
                Path(job[key]).resolve().parent for key in ('normal_table', 'rare_table')})]
        run_flatpak(HERE / 'catalog_animation_material_worker.py', directory / 'bake-job.json',
                    grants, directory / 'bake.log')
        receipts = json.loads((directory / 'shader-receipt.json').read_text())
        if [r['material'] for r in receipts] != [m['name'] for m in materials]:
            raise ValueError('Native shader receipt incomplete')
        binary = bytearray(binary)
        document.setdefault('textures', [])
        document.setdefault('samplers', [{'wrapS': 10497, 'wrapT': 10497}])
        if not document['samplers']:
            document['samplers'].append({'wrapS': 10497, 'wrapT': 10497})
        for i, (material, item, receipt) in enumerate(zip(document['materials'], materials, receipts)):
            if receipt.get('preserved_source_surface') == 'BSDF_GLASS':
                # Compatibility cannot render this glass eye cover through the
                # source transmission extension. A review-only thin cover uses
                # normal-incidence reflectance derived from the actual IOR.
                ior = receipt['source_glass_ior']
                if not math.isfinite(ior) or not 1 < ior < 4:
                    raise ValueError('Glass IOR outside thin-cover review range')
                colour = receipt['source_glass_colour']
                if any(abs(v - 1) > 1e-6 for v in colour[:3]):
                    raise ValueError('Tinted glass needs separate reconstruction')
                reflectance = ((ior - 1) / (ior + 1)) ** 2
                pbr = material.setdefault('pbrMetallicRoughness', {})
                pbr['baseColorFactor'] = [*colour[:3], reflectance]
                pbr['roughnessFactor'] = receipt['source_glass_roughness']
                material['alphaMode'] = 'BLEND'
                material.get('extensions', {}).pop('KHR_materials_transmission', None)
                receipt['compatibility_thin_cover_review'] = {'normal_incidence_reflectance': reflectance,
                    'limitation': 'Approximate clear cover; refraction and angle-dependent Fresnel are not reproduced'}
                continue
            pbr = material.setdefault('pbrMetallicRoughness', {})
            previous = pbr.get('baseColorTexture', {})
            sampler = document['textures'][previous['index']].get('sampler', 0) if previous else 0
            def texture(path, name):
                result = {'index': append_png(document, binary, Path(path).read_bytes(), name, sampler)}
                if i in domains:
                    result['extensions'] = {'KHR_texture_transform': {k: domains[i][k] for k in ('offset', 'scale')}}
                    used = document.setdefault('extensionsUsed', [])
                    if 'KHR_texture_transform' not in used:
                        used.append('KHR_texture_transform')
                return result
            pbr['baseColorTexture'] = texture(item['output'], material['name'] + '_native_colour')
            pbr['baseColorFactor'] = [1, 1, 1, 1]
            with Image.open(item['output']) as baked:
                if baked.getchannel('A').getextrema()[0] < 255:
                    material['alphaMode'] = 'BLEND'
                    material.pop('alphaCutoff', None)
            material.pop('emissiveTexture', None)
            material.pop('emissiveFactor', None)
            material.get('extensions', {}).pop('KHR_materials_emissive_strength', None)
            if not receipt['native_emission_output_zero']:
                material['emissiveTexture'] = texture(item['glow_output'], material['name'] + '_native_emission')
                material['emissiveFactor'] = [1, 1, 1]
                material.setdefault('extensions', {})['KHR_materials_emissive_strength'] = {
                    'emissiveStrength': receipt['emission_strength']}
                used = document.setdefault('extensionsUsed', [])
                if 'KHR_materials_emissive_strength' not in used:
                    used.append('KHR_materials_emissive_strength')
        target = directory / 'model.glb'
        write_glb(target, document, binary)
        parity = compare(original, target)
        exported = json.loads(original.with_name('export.json').read_text())
        exported.update(path=str(target), glb_sha256=sha(target), bytes=target.stat().st_size,
                        geometry_motion_sha256=parity, runtime_approved=False,
                        native_shader_receipt=receipts, native_uv_domains=list(domains.values()),
                        native_bake_worker_sha256=sha(HERE / 'catalog_animation_material_worker.py'),
                        source_glb_sha256=row['normal_glb_sha256'])
        write(directory / 'export.json', exported)
        return {'species': row['species'], 'status': 'normal_review_candidate',
                'path': str(target), 'glb_sha256': sha(target), 'geometry_motion_sha256': parity,
                'emissive_materials': [r['material'] for r in receipts if r.get('native_emission_output_zero') is False],
                'runtime_approved': False}
    except Exception as error:
        return {'species': row['species'], 'status': 'held', 'reason': str(error), 'runtime_approved': False}
    finally:
        source.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--intake', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    rows = json.loads(args.intake.read_text())['entries']
    assert len({r['species'] for r in rows}) == len(rows)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    results = []
    with ThreadPoolExecutor(max_workers=2) as pool:
        for result in pool.map(lambda row: recover(row, output), rows):
            results.append(result)
            write(output / 'status.json', {'total': len(rows), 'processed': len(results),
                                          'runtime_approved': False, 'entries': results})
            print(result['species'], result['status'], flush=True)


if __name__ == '__main__':
    main()
