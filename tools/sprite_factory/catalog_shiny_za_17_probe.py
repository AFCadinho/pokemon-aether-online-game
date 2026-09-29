"""Diagnostic ZA geometry import for the 17 incompatible older-mesh shiny holds.

Every species is isolated: an import, export, or material failure holds only
that species. Output is for visual review and is never catalog admission.
"""

import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path
import shutil
import subprocess
import sys

from PIL import Image, ImageChops

from catalog_remaining_eye_bake import append_png, chunks, linear_to_srgb, write_glb
from catalog_shiny_151_material_probe import rebuild
from phase5_variant_parity import compare
from scvi_material_probe import inspect_materials
from scvi_batch import source_entry

ROOT = Path(__file__).resolve().parents[2]
SLOT = ROOT.parent
HERE = Path(__file__).resolve().parent
IMPORTER = SLOT / '.tmp/scvi-importer'
DEPS = SLOT / '.tmp/scvi-python-deps'
NAMES = ('pidgey', 'farfetchd', 'cubone', 'marowak', 'staryu', 'mawile',
         'manectric', 'sharpedo', 'absol', 'purrloin', 'munna', 'audino',
         'cofagrigus', 'trubbish', 'vanilluxe', 'emolga', 'stunfisk')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2) + '\n')


def restore_fresnel(path, table, *, emission=False):
    """Restore ZA Fresnel colour without changing the prior SCVI receipt's baker."""
    document, binary = chunks(path)
    rows = {row['name']: row for row in inspect_materials(table)}
    restored = []
    for material in document['materials']:
        row = rows[material['name']]
        if not any(shader['name'] == 'FresnelEffect' for shader in row['shaders']):
            continue
        tint = row['colors'].get('BaseColorLayer1')
        if tint is None or len(tint) != 4:
            raise ValueError(row['name'] + ': Fresnel surface has no first colour layer')
        base = Image.open(table.parent / Path(row['textures']['BaseColorMap']).with_suffix('.png').name).convert('RGBA')
        colour = ImageChops.multiply(base.convert('RGB'), Image.new('RGB', base.size,
                                 tuple(linear_to_srgb(value) for value in tint[:3])))
        colour.putalpha(base.getchannel('A'))
        packed = BytesIO(); colour.save(packed, format='PNG')
        pbr = material['pbrMetallicRoughness']
        old = pbr['baseColorTexture']
        sampler = document['textures'][old['index']].get('sampler', 0)
        pbr['baseColorTexture'] = {**old, 'index': append_png(document, binary, packed.getvalue(),
                                    row['name'] + '_za_fresnel_colour', sampler)}
        if emission:
            intensity = row['floats'].get('EmissionIntensityLayer1', 0)
            emissive = row['colors'].get('EmissionColorLayer1', tint)
            if intensity > 0:
                material['emissiveFactor'] = [min(1.0, max(0.0, value * intensity))
                                              for value in emissive[:3]]
        restored.append(row['name'])
    if restored:
        write_glb(path, document, binary)
    return restored


def run_flatpak(worker, job, grants, log):
    cmd = ['flatpak', 'run', '--unshare=network', '--nofilesystem=host']
    cmd += ['--filesystem=' + str(path) + suffix for path, suffix in grants]
    cmd += ['org.blender.Blender', '--background', '--factory-startup', '--disable-autoexec',
            '--python-exit-code', '1', '--python', str(worker), '--', str(job)]
    with log.open('w') as output:
        subprocess.run(cmd, stdout=output, stderr=subprocess.STDOUT, timeout=600, check=True)


def probe(row, source_root, output):
    name, ident = row['species'], row['resource_id']
    place = output / name
    place.mkdir(parents=True, exist_ok=True)
    entry = source_entry({'species': name, 'pm': int(ident[2:]),
                          'target_game_height_px': 100}, source_root, source_root)
    holds = [x for x in entry['warnings'] if x.startswith(('motion_bank_hold:', 'missing_action:'))]
    if holds:
        raise ValueError('; '.join(holds))
    directory = Path(entry['model_dir'])
    normal_table = directory / (entry['identity'] + '.trmtr')
    rare_table = directory / (entry['identity'] + '_rare.trmtr')
    if not normal_table.is_file() or not rare_table.is_file():
        raise ValueError('matched ZA normal/rare table missing')
    motions = {k: v for k, v in entry['motions'].items() if v}
    channels = {k: entry['motion_channels'][k] for k in motions}
    # The first 15 visual approvals used the rest pose; keep their pinned
    # import unchanged. Vanilluxe needs its explicit open-eye donor for the
    # missing eyelid tracks on the smaller face.
    baseline_code = '20010' if name == 'vanilluxe' else '00010'
    baseline = directory / (entry['identity'] + '_' + baseline_code + '_defaultidle01.tranm')
    baseline = str(baseline) if baseline.is_file() else None
    core = [p for p in directory.iterdir() if p.is_file() and
            (p.suffix in ('.trmdl', '.trmmt', '.trmsh', '.trmbf', '.trmtr', '.trskl', '.png')
             or p.name.endswith('.trpokecfg'))]
    used = core + [Path(p) for p in motions.values()] + [Path(p) for p in channels.values() if p]
    if baseline:
        used.append(Path(baseline))
    imports = place / 'import'
    imports.mkdir(exist_ok=True)
    prepared = imports / (entry['identity'] + '-ready.blend')
    report_path = imports / 'import.json'
    job = {'species': name, 'identity': entry['identity'], 'variant': 'normal',
           'model_dir': str(directory), 'motions': motions, 'motion_channels': channels,
           'facial_baseline': baseline, 'facial_baseline_categories':
           ['idle', 'physical_attack', 'physical_attack_2', 'special_attack', 'damage'],
           'restore_all_eyelids': False, 'output': str(prepared), 'report': str(report_path),
           'importer': str(IMPORTER), 'python_deps': str(DEPS),
           'importer_commit': 'b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04',
           'shader_sha256': sha(IMPORTER / 'SCVIShader.blend'),
           'source_files': {str(p): sha(p) for p in used}}
    write(imports / 'job.json', job)
    if not report_path.is_file():
        run_flatpak(HERE / 'scvi_import_worker.py', imports / 'job.json',
                    [(source_root, ':ro'), (IMPORTER, ':ro'), (DEPS, ':ro'),
                     (HERE, ':ro'), (place, '')], imports / 'import.log')
    imported = json.loads(report_path.read_text())
    if imported['prepared_sha256'] != sha(prepared) or imported['importer_commit'] != job['importer_commit']:
        raise ValueError('ZA imported Blend provenance mismatch')
    for path, expected in imported['source_files'].items():
        if sha(path) != expected:
            raise ValueError('ZA imported source changed: ' + path)
    exported = place / 'export'
    exported.mkdir(exist_ok=True)
    # This diagnostic direct GLB export intentionally does not claim material
    # provenance. Both variants are reconstructed with the matched ZA tables
    # only after the importer provenance above and exporter report are pinned.
    isolated = exported / 'input.blend'
    if not isolated.is_file():
        shutil.copyfile(prepared, isolated)
    if sha(isolated) != sha(prepared):
        raise ValueError('isolated Blend changed')
    mapping = {k: value['name'] for k, value in imported['actions'].items() if value}
    export_job = {'species': name, 'source': str(isolated), 'source_sha256': sha(isolated),
                  'actions': mapping, 'output': str(exported), 'scvi_pbr_probe': False}
    write(exported / 'job.json', export_job)
    if not (exported / 'export.json').is_file():
        run_flatpak(HERE / 'phase5_godot_export_worker.py', exported / 'job.json',
                    [(exported, ''), (HERE, ':ro')], exported / 'export.log')
    exp = json.loads((exported / 'export.json').read_text())
    raw = exported / 'model.glb'
    if exp['status'] != 'exported_for_review' or exp['glb_sha256'] != sha(raw):
        raise ValueError('ZA diagnostic GLB changed')
    variants = {}
    for variant, table in (('normal', normal_table), ('shiny', rare_table)):
        target = place / variant / 'model.glb'
        records = rebuild(raw, target, table)
        fresnel = restore_fresnel(target, table, emission=name == 'vanilluxe')
        compare(raw, target)
        variants[variant] = {'path': str(target), 'sha256': sha(target),
                             'table': str(table), 'table_sha256': sha(table),
                             'materials': records, 'fresnel_restored': fresnel}
    geometry = compare(place / 'normal/model.glb', place / 'shiny/model.glb')
    if variants['normal']['sha256'] == variants['shiny']['sha256']:
        raise ValueError('ZA normal and rare reconstruct identically')
    return {'species': name, 'status': 'review_candidate', 'runtime_approved': False,
            'import_report_sha256': sha(report_path), 'export_report_sha256': sha(exported / 'export.json'),
            'geometry_motion_sha256': geometry, 'variants': variants,
            'animations': exp['animations'], 'warnings': imported.get('channel_warnings', []) +
            imported.get('facial_inheritance_warnings', [])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', type=Path, required=True)
    parser.add_argument('--source-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.source_root = args.source_root.resolve()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    inventory = {r['species']: r for r in json.loads(args.inventory.read_text())['entries']}
    results = []
    for name in NAMES:
        try:
            result = probe(inventory[name], args.source_root, args.output)
        except (OSError, ValueError, KeyError, IndexError, subprocess.SubprocessError) as exc:
            result = {'species': name, 'status': 'held', 'reason': str(exc), 'runtime_approved': False}
        results.append(result)
        write(args.output / 'status.json', {'schema': 1, 'runtime_approved': False, 'entries': results})
        print(name, result['status'], result.get('reason', ''), flush=True)


if __name__ == '__main__':
    main()
