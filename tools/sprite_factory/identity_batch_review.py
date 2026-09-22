"""Run a fixed identity-gated cohort through source review and GLB export.

Existing imports may be reused read-only when their complete source provenance
and action selection still agree. Every source pose review and export runs again.
"""
import argparse
import concurrent.futures
import json
import subprocess
from pathlib import Path
from types import SimpleNamespace

from phase5_source_review import run_entry
from scvi_identity import export_read_paths, validate_entry, validate_export_job


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')


def process(entry, args):
    root = args.output / 'source'
    old = args.prepared_from
    if old and not (old / 'sources' / entry['species'] / 'normal' /
                    (entry.get('identity', '') + '-ready.blend')).is_file():
        old = None
    options = SimpleNamespace(**{**vars(args), 'output': root, 'prepared_from': old,
                                 'animation_bank': None, 'layer_mask_probe': False})
    raw = run_entry(entry, options)
    row = {'species': entry['species'], 'runtime_approved': False,
           'identity_evidence': entry.get('identity_evidence'),
           'identity_error': entry.get('identity_error')}
    if raw['status'] != 'source_review_only':
        return raw, {**row, 'status': 'blocked', 'reason': raw.get('error', 'Source review failed')}
    path = Path(raw['report'])
    review = json.loads(path.read_text())
    job = json.loads(path.with_name('job.json').read_text())
    destination = args.output / 'export' / entry['species']
    destination.mkdir()
    job.update(output=str(destination), actions=review['review_mapping'], scvi_pbr_probe=True)
    try:
        validate_export_job(job)
        write(destination / 'job.json', job)
        tools = Path(__file__).resolve().parent
        command = ['flatpak', 'run', '--unshare=network', '--nofilesystem=host',
                   '--filesystem=' + str(args.output), '--filesystem=' + str(tools) + ':ro',
                   '--filesystem=' + str(Path(job['source']).parent) + ':ro']
        command += ['--filesystem=' + p + ':ro' for p in export_read_paths(job)]
        command += ['org.blender.Blender', '--background', '--factory-startup', '--disable-autoexec',
                    '--python-exit-code', '1', '--python', str(tools / 'phase5_godot_export_worker.py'),
                    '--', str(destination / 'job.json')]
        with (destination / 'export.log').open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=600, check=True)
        report = json.loads((destination / 'export.json').read_text())
        return raw, {**row, **report, 'missing_actions': sorted(
            {'idle', 'physical_attack', 'special_attack', 'damage', 'sleep', 'faint_start', 'faint_loop'} - set(review['review_mapping']))}
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        return raw, {**row, 'status': 'blocked', 'reason': str(error), 'log': str(destination / 'export.log')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('inventory', 'model-root', 'motion-root', 'importer', 'python-deps', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--prepared-from', type=Path)
    args = parser.parse_args()
    for key, value in vars(args).items():
        if isinstance(value, Path):
            setattr(args, key, value.resolve())
    entries = json.loads(args.inventory.read_text())['entries']
    for row in entries:
        if row['review_route'] == 'scvi_candidate':
            validate_entry(row)
        elif row['review_route'] != 'identity_blocked':
            raise ValueError('Use identity-gated inventory for this batch runner')
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / 'source').mkdir()
    (args.output / 'export').mkdir()
    write(args.output / 'source/intake.json', {'entries': entries})
    source, exports = [], []
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        for raw, result in pool.map(lambda e: process(e, args), entries):
            source.append(raw)
            exports.append(result)
            write(args.output / 'source/catalog.json', {'runtime_approved': False, 'entries': source})
            write(args.output / 'export/catalog.json', {'runtime_approved': False, 'entries': exports})
            print(result['species'], result['status'], result.get('identity_error') or '', flush=True)


if __name__ == '__main__':
    main()
