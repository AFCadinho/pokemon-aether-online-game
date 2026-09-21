"""Prepare disposable nine-model Godot diagnostics, never runtime approvals."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import subprocess

REQUIRED = {'idle', 'physical_attack', 'special_attack', 'damage', 'sleep', 'faint_start', 'faint_loop'}


def build_gallery(output):
    report = json.loads((output / 'godot-review.json').read_text())
    rows = []
    for entry in report['entries']:
        cells = '<th>' + html.escape(entry['species']) + '<br>' + html.escape(entry.get('status', 'diagnostic only')) + '</th>'
        for pose in entry.get('poses', []):
            label = html.escape(pose['action'] + ' / ' + pose['view'])
            if 'image' in pose:
                cells += '<td>' + label + '<br><img width="240" src="' + html.escape(pose['image'], quote=True) + '"></td>'
            else:
                cells += '<td>' + label + '<br>MISSING</td>'
        notes = entry.get('errors', []) + ['Missing clips: ' + ', '.join(entry.get('missing_actions', [])),
                                         entry.get('material_limitations', '')]
        rows.append('<tr>' + cells + '<td>' + html.escape('; '.join(notes)) + '</td></tr>')
    (output / 'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Phase 5 Godot review</title>'
        '<style>body{background:#18202a;color:white;font:16px sans-serif}td,th{padding:8px;vertical-align:top}</style>'
        '<h1>Godot conversion diagnostic — NOT battle approved</h1>'
        '<p>Native scale, auto-fit camera. No battle placement or HUD certification. '
        'Direct shader translation can lose colours, transparency and material animation. '
        'Controls are fresh diagnostic exports, not replacements for approved runtime assets.</p><table>' + ''.join(rows) + '</table>')


def prepare_entries(catalog):
    expected = {e['species'] for e in json.loads(Path(__file__).with_name('phase5_review_batch.json').read_text())['entries']}
    names = [e['species'] for e in catalog['entries']]
    if len(names) != len(set(names)) or set(names) != expected:
        raise ValueError('Expected the complete, unique ten-model source cohort')
    result = []
    for entry in catalog['entries']:
        name = entry['species']
        if entry['status'] != 'source_review_only':
            raise ValueError('Source review unavailable: ' + name)
        report_path = Path(entry['report'])
        review = json.loads(report_path.read_text())
        job = json.loads(report_path.with_name('job.json').read_text())
        if job.get('material_probe_policy') or review.get('material_probe'):
            raise ValueError('Experimental material probes cannot become conversion sources')
        if job['species'] != name or review['species'] != name:
            raise ValueError('Mismatched source identity')
        digest = hashlib.sha256(Path(job['source']).read_bytes()).hexdigest()
        if digest != job['source_sha256'] or digest != review['source_sha256']:
            raise ValueError('Stale source: ' + name)
        from material_profiles import read_profiles, unsupported
        if job.get('material_source'):
            profiles = read_profiles(job['material_source'], job['material_source_sha256'])
            if unsupported(profiles):
                result.append({'species': name, 'status': 'held',
                               'reason': 'Unsupported material profiles', 'material_profiles': profiles})
                continue
        elif Path(job['source']).with_name('import.json').exists():
            raise ValueError('Imported source needs material provenance; rerun source review')
        actions = review['review_mapping']
        if not actions.get('idle') or set(actions) - REQUIRED:
            raise ValueError('Invalid review action mapping')
        result.append({'species': name, 'status': 'pending', 'source': job['source'],
                       'source_sha256': digest, 'actions': actions,
                       **{k: job[k] for k in ('material_source', 'material_source_sha256', 'effect_motion_dir') if k in job},
                       'missing_actions': sorted(REQUIRED - actions.keys())})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--gallery-only', action='store_true')
    parser.add_argument('--scvi-pbr-probe', action='store_true',
                        help='Use the existing simplified PBR bake on matching importer graphs only')
    args = parser.parse_args()
    if args.gallery_only:
        build_gallery(args.output)
        return
    entries = prepare_entries(json.loads(args.catalog.read_text()))
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    # Isolated project: no game autoloads, network, profiles or runtime registry.
    (output / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Phase 5 offline review"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    worker = Path(__file__).with_name('phase5_godot_export_worker.py').resolve()
    for entry in entries:
        if entry['status'] == 'held':
            continue
        directory = output / entry['species']
        directory.mkdir()
        job = {**entry, 'output': str(directory), 'scvi_pbr_probe': args.scvi_pbr_probe}
        job_path = directory / 'job.json'
        job_path.write_text(json.dumps(job, indent=2))
        command = ['flatpak', 'run', '--unshare=network', '--nofilesystem=host',
                   '--filesystem=' + str(output), '--filesystem=' + str(worker.parent) + ':ro',
                   '--filesystem=' + str(Path(entry['source']).parent) + ':ro',
                   'org.blender.Blender', '--background', '--factory-startup', '--disable-autoexec',
                   '--python-exit-code', '1', '--python', str(worker), '--', str(job_path)]
        if entry.get('material_source'):
            command.insert(5, '--filesystem=' + str(Path(entry['material_source']).parent) + ':ro')
        if entry.get('effect_motion_dir'):
            command.insert(5, '--filesystem=' + entry['effect_motion_dir'] + ':ro')
        try:
            with (directory / 'export.log').open('w') as log:
                subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=600, check=True)
            entry.update(json.loads((directory / 'export.json').read_text()))
        except (subprocess.SubprocessError, OSError) as error:
            entry.update(status='blocked', reason=str(error))
        print(entry['species'], entry['status'], flush=True)
        (output / 'catalog.json').write_text(json.dumps({'runtime_approved': False,
            'scope': 'godot_conversion_diagnostic_not_material_parity', 'entries': entries}, indent=2))
    if any(entry['status'] == 'blocked' for entry in entries):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
