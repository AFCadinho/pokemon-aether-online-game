"""Prepare sourced alternate-form battle models for review only.

The tool pins source identities, imports native SCVI clips where available,
and exports isolated GLB candidates. It never approves or activates content.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SLOT = ROOT.parent
WORK = ROOT / '.tmp/battle-forms-next-seven-v1'
SOURCE = Path('/run/media/adinho/AFC_Adinho/3d_models/Pokémon SCVI Base + DLC Model Dump')
MOTIONS = Path('/run/media/adinho/AFC_Adinho/3d_models/SV Every File/romfs/pokemon/data')
IMPORTER = SLOT / '.tmp/scvi-importer'
DEPS = SLOT / '.tmp/scvi-python-deps'
IMPORTER_COMMIT = 'b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04'
SCVI = {
    'mimikyu-busted': ('pm0819_12_00', 'pm0819'),
    'palafin-hero': ('pm1038_12_00', 'pm1038'),
    'eiscue-noice': ('pm0975_12_00', 'pm0975'),
}
CLIPS = {
    'idle': ('00001_battlewait01_loop',),
    'physical_attack': ('00400_attack01',),
    'physical_attack_2': ('00410_attack02',),
    'special_attack': ('00450_rangeattack01',),
    'damage': ('00500_damage01',),
    'sleep': ('00281_sleep01_loop',),
    'faint_start': ('00520_down01_start',),
    'faint_loop': ('00521_down01_loop',),
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def write(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, allow_nan=False) + '\n')


def runner():
    sys.path.insert(0, str(HERE))
    from catalog_shiny_za_17_probe import run_flatpak
    return run_flatpak


def native_row(slug):
    identity, pm = SCVI[slug]
    model_dir = SOURCE / pm / identity
    motion_dir = MOTIONS / pm / identity
    if not (model_dir / (identity + '.trmdl')).is_file():
        raise FileNotFoundError(f'{slug}: source model missing')
    motions = {}
    for category, suffixes in CLIPS.items():
        suffix = suffixes[0]
        clip_identity = identity
        # Skeletal `.tranm` files are the clean subset of the combined `.tracm`
        # bundle. The latter can also contain unnamed visibility/material
        # tracks that this pinned Blender importer cannot consume directly.
        path = motion_dir / (clip_identity + '_' + suffix + '.tranm')
        if not path.is_file() and slug == 'eiscue-noice' and category == 'sleep':
            # Both Eiscue resources use the exact same skeleton file. Reuse only
            # this missing sleep loop, never attacks or faint poses.
            base = pm + '_11_00'
            path = MOTIONS / pm / base / (base + '_00281_sleep01_loop.tranm')
        if path.is_file():
            motions[category] = str(path)
    required = {'idle', 'physical_attack', 'special_attack', 'damage', 'faint_start', 'faint_loop'}
    if not required.issubset(motions):
        raise ValueError(f'{slug}: missing native action categories {sorted(required - motions.keys())}')
    return {'species': slug, 'identity': identity, 'model_dir': model_dir,
            'motion_dir': motion_dir, 'motions': motions}


def import_candidate(slug):
    row = native_row(slug)
    folder = WORK / 'import' / slug
    prepared = folder / 'prepared.blend'
    report_path = folder / 'import.json'
    folder.mkdir(parents=True, exist_ok=True)
    if report_path.is_file() and prepared.is_file():
        report = read(report_path)
        if report.get('prepared_sha256') == sha(prepared):
            return report
    source_files = {str(p): sha(p) for p in row['model_dir'].iterdir() if p.is_file()}
    source_files.update({str(p): sha(p) for p in (Path(p) for p in row['motions'].values())})
    job = {'species': slug, 'identity': row['identity'], 'variant': 'normal',
           'model_dir': str(row['model_dir']), 'motions': row['motions'], 'motion_channels': {},
           'restore_all_eyelids': False, 'output': str(prepared), 'report': str(report_path),
           'importer': str(IMPORTER), 'python_deps': str(DEPS),
           'importer_commit': IMPORTER_COMMIT, 'shader_sha256': sha(IMPORTER / 'SCVIShader.blend'),
           'source_files': source_files}
    write(folder / 'job.json', job)
    run_flatpak = runner()
    run_flatpak(HERE / 'scvi_import_worker.py', folder / 'job.json',
                [(WORK, ''), (HERE, ':ro'), (SOURCE, ':ro'), (MOTIONS, ':ro'),
                 (IMPORTER, ':ro'), (DEPS, ':ro')],
                folder / 'import.log')
    report = read(report_path)
    if report.get('prepared_sha256') != sha(prepared):
        raise ValueError(f'{slug}: prepared Blender source hash mismatch')
    for path, expected in report['source_files'].items():
        if sha(path) != expected:
            raise ValueError(f'{slug}: source changed during import: {path}')
    return report


def export_candidate(slug):
    report = import_candidate(slug)
    source = WORK / 'import' / slug / 'prepared.blend'
    actions = {category: info['name'] for category, info in report['actions'].items() if info}
    exports = {}
    for kind in ('hierarchical', 'flat'):
        folder = WORK / 'export' / slug / kind
        folder.mkdir(parents=True, exist_ok=True)
        isolated = folder / 'input.blend'
        if not isolated.exists():
            shutil.copyfile(source, isolated)
        if sha(isolated) != sha(source):
            raise ValueError(f'{slug}: isolated {kind} source does not match import')
        job = {'species': slug, 'source': str(isolated), 'source_sha256': sha(isolated),
               'actions': actions, 'output': str(folder), 'scvi_pbr_probe': False,
               'native_flatten_bone_hierarchy_diagnostic': kind == 'flat'}
        write(folder / 'job.json', job)
        export_report = folder / 'export.json'
        if not export_report.is_file():
            runner()(HERE / 'phase5_godot_export_worker.py', folder / 'job.json',
                     [(folder, ''), (HERE, ':ro')], folder / 'export.log')
        result = read(export_report)
        model = folder / 'model.glb'
        if result.get('status') != 'exported_for_review' or result.get('glb_sha256') != sha(model):
            raise ValueError(f'{slug}: {kind} exported GLB receipt mismatch')
        exports[kind] = result
    return {'species': slug, 'runtime_approved': False, 'appearance_approved': False,
            'source_sha256': sha(source), 'import_sha256': sha(WORK / 'import' / slug / 'import.json'),
            'export_sha256': {kind: sha(WORK / 'export' / slug / kind / 'export.json') for kind in exports},
            'model_path': str(WORK / 'export' / slug / 'flat' / 'model.glb'),
            'model_sha256': sha(WORK / 'export' / slug / 'flat' / 'model.glb'),
            'actions': actions, 'exports': exports,
            'source_warnings': report.get('facial_inheritance_warnings', [])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('import', 'export'))
    parser.add_argument('--species', nargs='*', choices=tuple(SCVI))
    args = parser.parse_args()
    WORK.mkdir(parents=True, exist_ok=True)
    rows = list(args.species or SCVI.keys())
    results = []
    for slug in rows:
        try:
            result = import_candidate(slug) if args.phase == 'import' else export_candidate(slug)
            results.append({'species': slug, 'status': 'review_candidate', **result})
        except Exception as error:
            results.append({'species': slug, 'status': 'held', 'reason': str(error),
                            'runtime_approved': False, 'appearance_approved': False})
        write(WORK / (args.phase + '-status.json'), {'schema': 1, 'entries': results,
              'runtime_approved': False, 'appearance_approved': False})
        print(args.phase, slug, results[-1]['status'], results[-1].get('reason', ''), flush=True)
    if any(item['status'] == 'held' for item in results):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
