#!/usr/bin/env python3
"""Bind successful native study and compiled client qualification to v15."""
import argparse
from pathlib import Path

from package_approved_3d_release_v15 import BINDING, ROOT, read, sha, write

CODE = ['scripts/services/model_pair_pilot.gd', 'launcher/scripts/model_pair_pilot.gd',
        'scripts/services/model_pair_pack.gd', 'scripts/services/on_demand_3d_bundle_service.gd',
        'launcher/scripts/release_asset_bundles.gd', 'tools/package_launcher_release.py',
        'tools/package_approved_3d_release_v15.py', 'tools/publish_approved_3d_index_v15.py',
        'tools/qualify_approved_3d_release_v15.py', 'tools/seal_approved_3d_release_v15.py',
        'tests/approved_3d_release_v15_check.gd', 'tests/model_release_v15_upgrade_check.gd',
        'tests/model_release_v15_actor_check.gd', 'data/android_3d_experiment.json',
        'tools/verify_android_3d_assets.py', 'launcher/tests/model_release_v15_binding_check.gd']


def seal(work, launcher_log):
    work = Path(work).resolve()
    binding = read(BINDING)
    admission = read(work / 'binding-runtime.json')
    assert admission['complete'] and admission['pairs'] == 1420 and admission['appearances'] == 2840
    actors = read(work / 'actors.json')
    assert actors['renderer'] == 'gl_compatibility' and actors['godot'].startswith('4.6.2') and actors['device']
    fixture = read(work / 'actor-input.json')
    assert actors['complete'] and actors['pairs'] == fixture['pairs'] and len(actors['records']) == 111
    assert set(actors['pairs']) == {a['appearances'][0]['runtime_identity'] for a in
        read(ROOT / 'data/model_pair_release_v15_catalog.json')['assets'] if a['asset_id'] in binding['replacements']}
    assert actors['battles'] == 222 and actors['previews'] == 888
    assert all(r['actual_actor_states_exact'] for r in actors['records'])
    evidence = {}
    names = [('binding-runtime', 'APPROVED_3D_V15_OK'), ('actors', 'V15_ACTOR_OK')]
    for phase in ['original', 'verify-original', 'upgrade', 'verify-upgrade', 'rollback', 'verify-rollback']:
        report = work / 'upgrade' / (phase + '.json')
        value = read(report)
        assert value['complete'] and value['phase'] == phase and value['pairs'] == 11
        if phase.startswith('verify-'):
            assert value['appearances_loaded'] == 22
        else:
            assert value['restart_no_download']
        evidence[str(report.relative_to(work))] = sha(report)
        names.append(('upgrade-' + phase, 'MODEL_V15_UPGRADE_OK'))
    assert read(work / 'upgrade/upgrade.json')['failed_batch_preserved_generation']
    for name, marker in names:
        path = work / (name + '.stdout.log')
        text = path.read_text()
        assert marker in text and 'ERROR:' not in text and 'SCRIPT ERROR' not in text, name
        evidence[str(path.relative_to(work))] = sha(path)
    for name in ['actor-input.json', 'actors.json', 'binding-runtime.json', 'upgrade-input.json']:
        evidence[name] = sha(work / name)
    launcher_log = Path(launcher_log).resolve()
    launcher_text = launcher_log.read_text()
    assert 'LAUNCHER_V15_BINDING_OK' in launcher_text and 'ERROR:' not in launcher_text and 'SCRIPT ERROR' not in launcher_text
    binding.update(runtime_approved=True, publication_approved=True,
        upgrade_qualified=True, rollback_qualified=True, restart_qualified=True,
        immutable_versions_incremented=True, distinct_resource_namespaces=True,
        actual_presenter_pairs=111, actual_battles=222, actual_previews=888,
        platform='Linux Godot 4.6.2; real Compatibility GPU. No native Windows/macOS or physical Android certification.',
        evidence_sha256=evidence, standalone_launcher_qualified=True,
        previous_publication_receipt_sha256=sha(ROOT / 'release/approved_3d_bundles_v14_r2_receipt.json'),
        launcher_evidence_sha256={str(launcher_log.relative_to(ROOT)): sha(launcher_log)},
        code_bindings={name: sha(ROOT / name) for name in CODE})
    write(BINDING, binding)
    print('V15_BINDING_QUALIFIED pairs=1420 replacements=111 presenters=111 upgrade=true rollback=true publication_pending=true')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--launcher-log', type=Path, required=True)
    args = parser.parse_args()
    seal(args.work, args.launcher_log)
