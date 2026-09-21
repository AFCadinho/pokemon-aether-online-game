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
            expected = f"Gen1/pm{entry['pm']:04d}_00.blend"
            if legacy['member'] != expected:
                raise ValueError('Unexpected legacy archive member')
            source = directory / Path(expected).name
            with zipfile.ZipFile(legacy['archive']) as archive:
                info = archive.getinfo(expected)
                if info.file_size > 536870912 or info.file_size != legacy['bytes']:
                    raise ValueError('Legacy candidate size changed or exceeds review limit')
                payload = archive.read(expected) # Validate CRC before creating a source file.
                with source.open('xb') as target:
                    target.write(payload)
            actions = {} # Worker only accepts unambiguous action candidates.
        else:
            raise ValueError('No source candidate')
        job = {'species': species, 'source': str(source), 'output': str(directory),
               'actions': actions, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest()}
        job_path = directory / 'job.json'
        job_path.write_text(json.dumps(job, indent=2))
        worker = Path(__file__).with_name('phase5_source_review_worker.py').resolve()
        command = ['flatpak', 'run', '--unshare=network', '--nofilesystem=host',
                   '--filesystem=' + str(args.output), '--filesystem=' + str(worker.parent) + ':ro',
                   '--filesystem=' + str(source) + ':ro',
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
    args = parser.parse_args()
    for name, value in vars(args).items():
        if value is not None:
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
        'scope': 'source_materials_not_godot_conversion', 'entries': results}, indent=2))
    from phase5_review_gallery import build
    build(args.output)
    for result in results:
        print(result, flush=True)


if __name__ == '__main__':
    main()
