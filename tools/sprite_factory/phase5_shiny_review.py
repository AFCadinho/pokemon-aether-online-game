"""Offline shiny imports/exports for the eligible SCVI cohort; never publishes art."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from types import SimpleNamespace

from scvi_batch import import_one


def legacy_variant(normal_root, output, model_dir):
    from scvi_material_probe import inspect_materials
    catalog_path = output / 'catalog.json'
    catalog = json.loads(catalog_path.read_text())
    held = [e for e in catalog['entries'] if e['status'] == 'held']
    if len(held) != 1 or held[0]['species'] != 'snorlax':
        raise ValueError('Expected the held Snorlax variant')
    normal_materials = inspect_materials(model_dir / 'pm0143_00_00.trmtr')
    rare_materials = inspect_materials(model_dir / 'pm0143_00_00_rare.trmtr')
    replacements = []
    for normal, rare in zip(normal_materials, rare_materials, strict=True):
        if {k: v for k, v in normal.items() if k != 'textures'} != {k: v for k, v in rare.items() if k != 'textures'}:
            raise ValueError('Rare material settings differ; manual shader review required')
        for channel, name in normal['textures'].items():
            other = rare['textures'][channel]
            if other == name:
                continue
            if channel != 'BaseColorMap' or Path(name).name != name or Path(other).name != other:
                raise ValueError('Only explicit base-colour replacement is supported')
            a, b = model_dir / Path(name).with_suffix('.png'), model_dir / Path(other).with_suffix('.png')
            replacements.append({'normal': str(a), 'rare': str(b),
                'normal_sha256': hashlib.sha256(a.read_bytes()).hexdigest(),
                'rare_sha256': hashlib.sha256(b.read_bytes()).hexdigest()})
    if not replacements:
        raise ValueError('No official rare material differences')
    directory = output / 'snorlax'
    directory.mkdir()
    job = json.loads((normal_root / 'snorlax/job.json').read_text())
    job.update(output=str(directory), verified_texture_replacements=replacements)
    path = directory / 'job.json'
    path.write_text(json.dumps(job, indent=2))
    worker = Path(__file__).with_name('phase5_godot_export_worker.py').resolve()
    command = ['flatpak', 'run', '--unshare=network', '--nofilesystem=host',
        '--filesystem=' + str(output), '--filesystem=' + str(worker.parent) + ':ro',
        '--filesystem=' + str(Path(job['source']).parent) + ':ro', '--filesystem=' + str(model_dir) + ':ro',
        'org.blender.Blender', '--background', '--factory-startup', '--disable-autoexec',
        '--python-exit-code', '1', '--python', str(worker), '--', str(path)]
    with (directory / 'export.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=600, check=True)
    report = json.loads((directory / 'export.json').read_text())
    base = next(e for e in json.loads((normal_root / 'catalog.json').read_text())['entries'] if e['species'] == 'snorlax')
    catalog['entries'] = [e if e['species'] != 'snorlax' else {**base, **report, 'variant': 'shiny'} for e in catalog['entries']]
    catalog_path.write_text(json.dumps(catalog, indent=2))
    print('SHINY_REVIEW_EXPORTED snorlax; embedded normal pixel identity verified')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('normal', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--legacy-model', type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if args.legacy_model:
        legacy_variant(args.normal.resolve(), output, args.legacy_model.resolve())
        return
    output.mkdir(parents=True, exist_ok=False)
    decisions = json.loads((Path(__file__).parents[2] / 'docs/phase5b-review-decisions.json').read_text())
    catalog = json.loads((args.normal / 'catalog.json').read_text())
    results = []
    for decision in decisions['entries']:
        if decision['status'] != 'eligible_for_5c_normal':
            continue
        species = decision['species']
        normal = next(e for e in catalog['entries'] if e['species'] == species)
        source = Path(normal['source'])
        import_path = source.parent / 'job.json'
        original = json.loads(import_path.read_text())
        if 'importer' not in original:
            results.append({'species': species, 'status': 'held',
                            'reason': 'Biochao source: no reviewed shiny material binding; SCVI texture existence is insufficient'})
            continue
        intake = json.loads((source.parents[3] / 'intake.json').read_text())
        (output / 'intake.json').write_text(json.dumps(intake, indent=2))
        import_one(SimpleNamespace(output=output, species=species, variant='shiny',
            importer=Path(original['importer']), python_deps=Path(original['python_deps']),
            model_root=Path(original['model_dir']).parents[1],
            motion_root=Path(next(p for p in original['motions'].values() if p)).parents[2]))
        shiny = output / 'sources' / species / 'shiny' / source.name
        directory = output / species
        directory.mkdir()
        job = json.loads((args.normal / species / 'job.json').read_text())
        job.update(source=str(shiny), source_sha256=hashlib.sha256(shiny.read_bytes()).hexdigest(), output=str(directory))
        rare_material = Path(original['model_dir']) / (original['identity'] + '_rare.trmtr')
        job.update(material_source=str(rare_material),
                   material_source_sha256=hashlib.sha256(rare_material.read_bytes()).hexdigest())
        job_path = directory / 'job.json'
        job_path.write_text(json.dumps(job, indent=2))
        worker = Path(__file__).with_name('phase5_godot_export_worker.py').resolve()
        command = ['flatpak', 'run', '--unshare=network', '--nofilesystem=host',
            '--filesystem=' + str(output), '--filesystem=' + str(worker.parent) + ':ro',
            '--filesystem=' + str(rare_material.parent) + ':ro',
            'org.blender.Blender', '--background', '--factory-startup', '--disable-autoexec',
            '--python-exit-code', '1', '--python', str(worker), '--', str(job_path)]
        with (directory / 'export.log').open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=600, check=True)
        report = json.loads((directory / 'export.json').read_text())
        results.append({**normal, **report, 'source': str(shiny), 'variant': 'shiny'})
        print('SHINY_REVIEW_EXPORTED', species, flush=True)
        (output / 'catalog.json').write_text(json.dumps({'runtime_approved': False, 'entries': results}, indent=2))
    (output / 'catalog.json').write_text(json.dumps({'runtime_approved': False, 'entries': results}, indent=2))


if __name__ == '__main__':
    main()
