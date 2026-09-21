"""Breadth-first, source-only review. Never enables models or approves variants."""
import argparse
import concurrent.futures
import hashlib
import json
import re
import subprocess
import zipfile
from pathlib import Path
from types import SimpleNamespace

from scvi_batch import import_one


def run_entry(entry, args):
    species = entry['species']
    directory = args.output / 'review' / species
    directory.mkdir(parents=True)
    try:
        if entry['review_route'] == 'scvi_candidate':
            source_root = args.prepared_from or args.output
            source_dir = source_root / 'sources' / species / 'normal'
            if args.prepared_from and (not (source_dir / 'import.json').is_file() or
                                      not (source_dir / (entry['identity'] + '-ready.blend')).is_file()):
                raise ValueError('Prepared source missing; read-only reuse cannot import into old output')
            options = {**vars(args), 'output': source_root, 'species': species, 'variant': 'normal'}
            import_one(SimpleNamespace(**options))
            source = source_dir / (entry['identity'] + '-ready.blend')
            imported = json.loads((source_dir / 'import.json').read_text())
            actions = {name: value['name'] for name, value in imported['actions'].items() if value}
        elif entry['legacy_candidate']:
            legacy = entry['legacy_candidate']
            filename = f"pm{entry['pm']:04d}_00.blend"
            expected = legacy['member']
            if expected not in (filename, 'Gen1/' + filename):
                raise ValueError('Unexpected legacy archive member')
            source = directory / Path(expected).name
            with zipfile.ZipFile(legacy['archive']) as archive:
                info = archive.getinfo(expected)
                if info.file_size > 536870912 or info.file_size != legacy['bytes']:
                    raise ValueError('Legacy candidate size changed or exceeds review limit')
                if 'crc32' in legacy and f'{info.CRC:08x}' != legacy['crc32']:
                    raise ValueError('Legacy candidate CRC changed since inventory')
                payload = archive.read(expected) # Validate CRC before creating a source file.
                with source.open('xb') as target:
                    target.write(payload)
            actions = {} # Worker only accepts unambiguous action candidates.
        else:
            raise ValueError('No source candidate')
        job = {'species': species, 'source': str(source), 'output': str(directory),
               'actions': actions, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest()}
        if getattr(args, 'layer_mask_probe', False):
            from scvi_material_probe import inspect_materials, eligible, POLICY
            job['material_probe_policy'] = POLICY
            job['displacement_probe'] = getattr(args, 'displacement_probe', False)
            if entry['review_route'] == 'scvi_candidate':
                material_path = Path(entry['model_dir']) / (entry['identity'] + '.trmtr')
                job['material_probe_source'] = str(material_path)
                job['material_probe_sha256'] = hashlib.sha256(material_path.read_bytes()).hexdigest()
                job['material_probe_metadata'] = inspect_materials(material_path)
                if job['displacement_probe']:
                    for material in job['material_probe_metadata']:
                        if not eligible(material):
                            continue
                        name = material['textures']['DisplacementMap']
                        if Path(name).name != name:
                            raise ValueError('Unexpected displacement texture path')
                        path = material_path.parent / Path(name).with_suffix('.png')
                        material['displacement_image'] = str(path)
                        material['displacement_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
            else:
                job['material_probe_metadata'] = []
        job_path = directory / 'job.json'
        job_path.write_text(json.dumps(job, indent=2))
        worker = Path(__file__).with_name('phase5_source_review_worker.py').resolve()
        command = ['flatpak', 'run', '--unshare=network', '--nofilesystem=host',
                   '--filesystem=' + str(args.output), '--filesystem=' + str(worker.parent) + ':ro',
                   '--filesystem=' + str(source) + ':ro',
                   '--filesystem=' + str(args.model_root) + ':ro',
                   'org.blender.Blender', '--background', '--factory-startup', '--disable-autoexec',
                   '--python-exit-code', '1', '--python', str(worker), '--', str(job_path)]
        with (directory / 'review.log').open('w') as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=600)
        if result.returncode:
            raise RuntimeError('Blender review failed; see review.log')
        return {'species': species, 'status': 'source_review_only', 'report': str(directory / 'review.json')}
    except Exception as error:
        return {'species': species, 'status': 'blocked', 'error': str(error)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('inventory', 'model-root', 'motion-root', 'importer', 'python-deps', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--prepared-from', type=Path, help='Read-only reuse of this tool\'s existing imports')
    parser.add_argument('--layer-mask-probe', action='store_true',
                        help='Experimental opacity-only A/B review; never approves shader parity')
    parser.add_argument('--displacement-probe', action='store_true',
                        help='Also test native displacement texture with UV2 and centered height (unverified hypothesis)')
    args = parser.parse_args()
    if args.displacement_probe and not args.layer_mask_probe:
        parser.error('--displacement-probe requires --layer-mask-probe')
    for name, value in vars(args).items():
        if isinstance(value, Path):
            setattr(args, name, value.resolve())
    entries = json.loads(args.inventory.read_text())['entries']
    names = [entry['species'] for entry in entries]
    if len(set(names)) != len(names) or any(not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', name) for name in names):
        raise ValueError('Invalid or duplicate review identities')
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / 'intake.json').write_text(json.dumps({'entries': entries}, indent=2))
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda entry: run_entry(entry, args), entries))
    (args.output / 'catalog.json').write_text(json.dumps({'schema': 1, 'approval': False,
        'material_probe': args.layer_mask_probe,
        'displacement_probe': args.displacement_probe,
        'scope': 'source_materials_not_godot_conversion', 'entries': results}, indent=2))
    from phase5_review_gallery import build
    build(args.output)
    for result in results:
        print(result, flush=True)


if __name__ == '__main__':
    main()
