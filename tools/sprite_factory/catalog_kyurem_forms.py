"""Produce isolated Black/White Kyurem pairs for review, never admission."""
import argparse
import json
from pathlib import Path
import zipfile

from catalog_shiny_za_17_probe import run_flatpak, sha, write
from catalog_remaining_normal_export import choose_actions
import catalog_battle_forms_first_five as materials
from scvi_material_probe import inspect_materials
from catalog_remaining_eye_bake import chunks, write_glb
from catalog_dlc_flat_motion import values
from catalog_shiny_151_material_probe import rebuild
from catalog_dlc_layer_emission import restore
from phase5_variant_parity import compare

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
WORK = ROOT / '.tmp/legendary-kyurem-forms-v2'
INTAKE = HERE / 'catalog_legendary_forms_intake.json'


def source():
    spec = json.loads(INTAKE.read_text())['kyurem_archive']
    path = WORK / 'source/pm0646.blend'
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(spec['path']) as archive:
            member = archive.getinfo(spec['member'])
            if member.file_size != spec['bytes'] or f'{member.CRC:08x}' != spec['crc32']:
                raise ValueError('Kyurem archive member changed')
            with archive.open(member) as stream, path.open('xb') as target:
                while chunk := stream.read(1024 * 1024):
                    target.write(chunk)
    if sha(path) != spec['sha256']:
        raise ValueError('Kyurem source digest mismatch')
    return path, spec


def selection(row, digest):
    return {'policy': 'explicit_source_variant_review_v1',
            'rig': row['identity'], 'expected_identity': row['identity'][:-3],
            'source_sha256': digest}


def probe(row):
    path, spec = source()
    folder = WORK / 'probes' / row['species']
    folder.mkdir(parents=True, exist_ok=True)
    job = {'species': row['species'], 'source': str(path),
           'source_sha256': spec['sha256'], 'archive': spec['path'],
           'member': spec['member'], 'output': str(folder / 'report.json'),
           'diagnostic_rig_selection': selection(row, spec['sha256'])}
    write(folder / 'job.json', job)
    if not (folder / 'report.json').exists():
        run_flatpak(HERE / 'catalog_remaining_legacy_worker.py', folder / 'job.json',
                    [(WORK, ''), (HERE, ':ro')], folder / 'probe.log')
    report = json.loads((folder / 'report.json').read_text())
    if report['source_sha256'] != spec['sha256'] or report['rig_name'] != row['identity']:
        raise ValueError('Probe belongs to a different source rig')
    actions, bank = choose_actions(report)
    if actions is None:
        raise ValueError(bank)
    return {'species': row['species'], 'identity': row['identity'],
            'actions': actions, 'bank': bank, 'report_sha256': sha(folder / 'report.json'),
            'runtime_approved': False, 'appearance_approved': False}


def prepare(row):
    report = probe(row)
    path, spec = source()
    folder = WORK / 'motion' / row['species']
    folder.mkdir(parents=True, exist_ok=True)
    job = {'source': str(path), 'source_sha256': spec['sha256'],
           'material_names': [m['name'] for m in inspect_materials(
               Path(json.loads(INTAKE.read_text())['source_root']) / row['model'].replace('.trmdl', '.trmtr'))],
           'diagnostic_rig_selection': selection(row, spec['sha256']),
           'output': str(folder / 'prepared.blend'), 'report': str(folder / 'prepare.json')}
    write(folder / 'job.json', job)
    if not (folder / 'prepare.json').exists():
        run_flatpak(HERE / 'catalog_kyurem_forms_prepare_worker.py', folder / 'job.json',
                    [(WORK, ''), (HERE, ':ro')], folder / 'prepare.log')
    prepared = json.loads((folder / 'prepare.json').read_text())
    if prepared['prepared_sha256'] != sha(folder / 'prepared.blend'):
        raise ValueError('Disposable source changed after rig isolation')
    return {**report, **prepared}


def export(row):
    report = prepare(row)
    src = WORK / 'motion' / row['species'] / 'prepared.blend'
    exports = {}
    for kind in ('hierarchical', 'flat'):
        folder = WORK / 'export' / row['species'] / kind
        folder.mkdir(parents=True, exist_ok=True)
        job = {'species': row['species'], 'source': str(src), 'source_sha256': sha(src),
               'actions': report['actions'], 'output': str(folder), 'scvi_pbr_probe': False,
               'native_flatten_bone_hierarchy_diagnostic': kind == 'flat'}
        write(folder / 'job.json', job)
        if not (folder / 'export.json').exists():
            run_flatpak(HERE / 'phase5_godot_export_worker.py', folder / 'job.json',
                        [(WORK, ''), (HERE, ':ro')], folder / 'export.log')
        exports[kind] = json.loads((folder / 'export.json').read_text())
        if exports[kind]['glb_sha256'] != sha(folder / 'model.glb'):
            raise ValueError('Exported bytes changed')
    return {**report, 'exports': exports}


def material(row):
    export(row)
    materials.WORK = WORK
    materials.INTAKE = INTAKE
    return materials.material(row)


def neutral():
    """Use official layered albedo and a review-only neutral accessory selection.

    The retained Biochao shader bake darkens Black Kyurem's ice arm. Official
    matched texture/table reconstruction preserves its authored blue detail.
    Overdrive cables/lightning have no exported visibility clocks, so they are
    withheld from this neutral-form proposal; no skeleton or clip is altered.
    """
    materials.WORK = WORK
    materials.INTAKE = INTAKE
    intake = json.loads(INTAKE.read_text())
    results = []
    for row in intake['entries'][:2]:
        exp = export(row)['exports']['flat']
        raw = WORK / 'export' / row['species'] / 'flat/model.glb'
        model = materials.material_source(row)
        variants = {}
        for variant in ('normal', 'shiny'):
            table = model.with_suffix('.trmtr')
            if variant == 'shiny':
                table = table.with_stem(table.stem + '_rare')
            if sha(table) != row[('normal' if variant == 'normal' else 'shiny') + '_material_sha256']:
                raise ValueError('Official material table changed')
            folder = WORK / 'neutral' / row['species'] / variant
            folder.mkdir(parents=True, exist_ok=True)
            rebuilt = folder / 'source-albedo.glb'
            translated = rebuild(raw, rebuilt, table)
            lit = folder / 'source-emission.glb'
            emission = restore(rebuilt, lit, table)
            doc, binary = chunks(lit)
            omitted = []
            for node in doc['nodes']:
                if 'mesh' in node and any(part in node.get('name', '')
                                          for part in ('_tube_', '_lightning_')):
                    omitted.append(node['name'])
                    node.pop('mesh')
                    node.pop('skin', None)
            if not omitted:
                raise ValueError('Expected explicitly identified Overdrive accessories')
            target = folder / 'model.glb'
            write_glb(target, doc, binary)
            variants[variant] = {'path': str(target), 'sha256': sha(target),
                'table_sha256': sha(table), 'source_albedo': translated,
                'source_emission': emission, 'omitted_overdrive_meshes': omitted,
                'runtime_approved': False, 'appearance_approved': False}
            write(folder / 'receipt.json', variants[variant])
        results.append({'species': row['species'], 'identity': row['identity'],
            'variants': variants, 'export': exp, 'status': 'review_candidate',
            'geometry_motion_sha256': compare(Path(variants['normal']['path']),
                                               Path(variants['shiny']['path'])),
            'runtime_approved': False, 'appearance_approved': False})
    write(WORK / 'neutral-status.json', {'schema': 1, 'entries': results,
          'runtime_approved': False, 'appearance_approved': False})
    print('Prepared both neutral pairs with official body detail and eye colours')


def stage():
    data = json.loads((WORK / 'neutral-status.json').read_text())
    if len(data['entries']) != 2 or any(r['status'] != 'review_candidate' for r in data['entries']):
        raise ValueError('Both material pairs must succeed before staging')
    entries = []
    poses = [['idle', 0, 'front'], ['idle', .5, 'back']] + [
        [name, 1 if name == 'faint_start' else .5, 'front']
        for name in ('physical_attack', 'physical_attack_2', 'special_attack',
                     'sleep', 'faint_start', 'faint_loop')]
    for row in data['entries']:
        for variant, model in row['variants'].items():
            path = Path(model['path'])
            if sha(path) != model['sha256']:
                raise ValueError('Material candidate changed')
            doc, binary = chunks(path)
            durations = {a['name']: max(v[0] for sampler in a['samplers']
                for v in values(doc, binary, sampler['input'])) for a in doc['animations']}
            clips = row['export']['animations']
            if set(durations) != set(clips) or any(abs(durations[k] - clips[k]['duration']) > 1e-5 for k in clips):
                raise ValueError('Actual clip clocks disagree with export receipt')
            entries.append({'species': row['species'] + ('-shiny' if variant == 'shiny' else ''),
                'path': str(path), 'glb_sha256': model['sha256'], 'status': 'exported_for_review',
                'animations': clips, 'action_timing': {k: {'frames': v['duration'] * 60,
                    'speed': 1.0, 'loop': v['loop']} for k, v in clips.items()},
                'placement': {'scale': 1.0, 'yaw_degrees': 0.0},
                'complete_pose_channels': True, 'review_poses': poses,
                'runtime_approved': False, 'appearance_approved': False})
    write(WORK / 'stage-neutral-v1.json', entries)
    print('Staged four exact Kyurem appearances with eight own-rig clips each')


def main():
    global WORK
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('probe', 'prepare', 'export', 'material', 'neutral', 'stage'))
    parser.add_argument('--work', type=Path, default=WORK,
                        help='Evidence directory under this frontend checkout .tmp')
    args = parser.parse_args()
    WORK = args.work.resolve()
    if not WORK.is_relative_to(ROOT / '.tmp'):
        raise ValueError('Evidence must remain in the assigned frontend .tmp directory')
    if args.phase in ('stage', 'neutral'):
        globals()[args.phase]()
        return
    rows = json.loads(INTAKE.read_text())['entries'][:2]
    results = []
    for row in rows:
        try:
            result = {'status': 'review_candidate', **globals()[args.phase](row)}
        except Exception as error:
            import traceback
            traceback.print_exc()
            result = {'species': row['species'], 'status': 'held', 'reason': str(error)}
        results.append(result)
        write(WORK / (args.phase + '-status.json'), {'schema': 1, 'entries': results,
              'runtime_approved': False, 'appearance_approved': False})
        print(args.phase, row['species'], result['status'], result.get('reason', ''), flush=True)
    if any(row['status'] == 'held' for row in results):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
