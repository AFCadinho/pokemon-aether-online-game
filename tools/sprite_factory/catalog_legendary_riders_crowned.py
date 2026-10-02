"""Source-pinned four-form production cohort; review only, no runtime admission."""
import argparse
import copy
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
WORK = ROOT / '.tmp/legendary-riders-crowned-v1'
INTAKE = HERE / 'catalog_legendary_forms_intake.json'
sys.path.insert(0, str(HERE))
import catalog_battle_forms_next_seven as native
import catalog_battle_forms_first_five as materials
from catalog_shiny_151_material_probe import rebuild
from catalog_dlc_layer_emission import restore
from catalog_dlc_sleep_proposals import propose
from catalog_remaining_eye_bake import chunks, write_glb
from phase5_variant_parity import compare

ROWS = json.loads(INTAKE.read_text())['entries'][2:]
NAMES = [r['species'] for r in ROWS]
native.WORK = WORK
native.SCVI = {r['species']: (r['identity'], r['identity'].split('_')[0]) for r in ROWS}
# Reuse the pinned, existing importer code read-only; never copy caches or env.
native.IMPORTER = ROOT.parents[1] / 'slot-a/.tmp/scvi-importer'
native.DEPS = ROOT.parents[1] / 'slot-a/.tmp/scvi-python-deps'
materials.WORK = WORK
materials.INTAKE = INTAKE


def verify(row):
    source = Path(native.SOURCE) / row['model']
    assert native.sha(source) == row['model_sha256']
    for variant, suffix in [('normal', '.trmtr'), ('shiny', '_rare.trmtr')]:
        table = source.with_name(source.stem + suffix)
        assert native.sha(table) == row[variant + '_material_sha256']
    assert subprocess.check_output(['git', '-C', str(native.IMPORTER), 'rev-parse', 'HEAD'], text=True).strip() == native.IMPORTER_COMMIT


def sleep_only(source, target, hierarchy):
    """Add own-rig rest while preserving the already present native faint loop."""
    doc, binary = chunks(source)
    assert 'sleep' not in {a['name'] for a in doc['animations']}
    proposal_source = target.parent / 'sleep-source.glb'
    reduced = copy.deepcopy(doc)
    reduced['animations'] = [a for a in reduced['animations'] if a['name'] != 'faint_loop']
    write_glb(proposal_source, reduced, binary)
    proposal = target.parent / 'sleep-proposal.glb'
    receipt = propose(proposal_source, proposal, hierarchical_source=hierarchy)
    proposed, proposed_binary = chunks(proposal)
    sleep = next(a for a in proposed['animations'] if a['name'] == 'sleep')
    proposed['animations'] = copy.deepcopy(doc['animations']) + [sleep]
    for key in ('nodes', 'meshes', 'skins', 'scenes', 'scene'):
        assert proposed.get(key) == doc.get(key)
    assert proposed_binary[:len(binary)] == binary
    write_glb(target, proposed, proposed_binary)
    receipt.update(source_sha256=native.sha(source), glb_sha256=native.sha(target),
                   native_faint_loop_preserved=True, native_animation_count=len(doc['animations']))
    return receipt


def material(row):
    name = row['species']
    original = WORK / 'export' / name / 'flat/model.glb'
    export = native.read(original.with_name('export.json'))
    model = materials.material_source(row)
    variants = []
    for variant in ('normal', 'shiny'):
        folder = WORK / 'materials' / name / variant
        folder.mkdir(parents=True, exist_ok=True)
        table = model.with_name(model.stem + ('.trmtr' if variant == 'normal' else '_rare.trmtr'))
        base = folder / 'albedo.glb'
        colours = rebuild(original, base, table)
        layered = folder / 'layered.glb'
        emission = restore(base, layered, table)
        target = folder / 'model.glb'
        animations = copy.deepcopy(export['animations'])
        rest = None
        if 'sleep' not in animations:
            rest = sleep_only(layered, target, WORK / 'export' / name / 'hierarchical/model.glb')
            animations['sleep'] = {'duration': 2.0, 'fps': 60, 'loop': True,
                                   'source_action': 'authored_own_idle_with_own_faint_eyelids'}
        else:
            doc, binary = chunks(layered); write_glb(target, doc, binary)
        key = name + ('-shiny' if variant == 'shiny' else '')
        entry = {'species': key, 'path': str(target), 'glb_sha256': native.sha(target),
            'animations': animations, 'clips': animations,
            'action_timing': {a: {'frames': c['duration'] * 60, 'loop': c['loop'], 'speed': 1} for a, c in animations.items()},
            'placement': {'scale': 1, 'yaw_degrees': 0}, 'runtime_schema': 1,
            'complete_pose_channels': True, 'status': 'exported_for_review',
            'runtime_approved': False, 'appearance_approved': False, 'battle_approved': False,
            'material_receipt': colours, 'layer_emission': emission, 'sleep_proposal': rest,
            'review_poses': [['idle', 0, 'front'], ['idle', .5, 'back'],
                ['physical_attack', .5, 'front'], ['physical_attack_2', .5, 'front'],
                ['special_attack', .5, 'front'], ['sleep', .5, 'front'],
                ['faint_start', 1, 'front'], ['faint_loop', .5, 'front']]}
        native.write(folder / 'receipt.json', entry); variants.append(entry)
    parity = compare(Path(variants[0]['path']), Path(variants[1]['path']))
    return {'species': name, 'variants': variants, 'geometry_motion_parity': parity}


def visibility_stage():
    from scvi_tracm import inspect_visibility, inspect_tracm
    from visibility_export import keys
    from visibility_variants import mesh_name
    rows = native.read(WORK / 'stage-v1.json')
    for entry in rows:
        name = entry['species'].removesuffix('-shiny')
        source = next(r for r in ROWS if r['species'] == name)
        folder = native.MOTIONS / source['identity'].split('_')[0] / source['identity']
        doc, _ = chunks(Path(entry['path']))
        meshes = {n['name'] for n in doc['nodes'] if 'mesh' in n}
        manifest = {'schema': 1, 'glb_sha256': entry['glb_sha256'], 'clips': {}}
        for action, timing in entry['animations'].items():
            authored = timing['source_action'].startswith('authored_')
            motion = entry['animations']['idle'] if authored else timing
            path = folder / (motion['source_action'] + '.tracm')
            digest = native.sha(path)
            config = inspect_tracm(path)
            assert abs((config['frames'] - 1) / config['fps'] - motion['duration']) < 1e-6
            assert config['loop'] == motion['loop']
            tracks = []
            for track in inspect_visibility(path):
                mesh = mesh_name(track['target'])
                assert mesh in meshes
                samples = keys(track, config['frames'], config['fps'])
                if authored:
                    assert len(samples) == 1
                tracks.append({'mesh': mesh, 'source_target': track['target'], 'keys': samples})
            assert {t['mesh'] for t in tracks} == meshes and len(tracks) == len(meshes)
            assert native.sha(path) == digest
            manifest['clips'][action] = {'duration': timing['duration'], 'loop': timing['loop'],
                'source_sha256': digest, 'source_path': str(path), 'tracks': tracks,
                'authored_sleep_inherits_fixed_idle_visibility': authored}
        entry['visibility'] = manifest
        entry['review_poses'] += [[a, f, 'face'] for a, f, v in entry['review_poses'] if v == 'front']
    native.write(WORK / 'stage-visibility-v2.json', rows)
    print('VISIBILITY_STAGED appearances=8 full_native_clock_bindings=true')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('export', 'material', 'stage', 'visibility'))
    args = parser.parse_args()
    WORK.mkdir(parents=True, exist_ok=True)
    results = []
    if args.phase == 'visibility':
        visibility_stage()
        return
    if args.phase == 'stage':
        records = native.read(WORK / 'material-status.json')['entries']
        assert len(records) == 4 and all(r['status'] == 'review_candidate' for r in records)
        rows = [v for r in records for v in r['variants']]
        for row in rows: assert native.sha(row['path']) == row['glb_sha256']
        native.write(WORK / 'stage-v1.json', rows)
        print('STAGED appearances=8 native_and_authored_clips=64')
        return
    for row in ROWS:
        try:
            verify(row)
            result = native.export_candidate(row['species']) if args.phase == 'export' else material(row)
            results.append(dict(result, status='review_candidate'))
        except Exception as error:
            results.append({'species': row['species'], 'status': 'held', 'reason': str(error)})
        native.write(WORK / (args.phase + '-status.json'), {'schema': 1, 'entries': results, 'runtime_approved': False})
        print(args.phase, row['species'], results[-1]['status'], results[-1].get('reason', ''), flush=True)
    if any(r['status'] == 'held' for r in results): raise SystemExit(1)


if __name__ == '__main__':
    main()
