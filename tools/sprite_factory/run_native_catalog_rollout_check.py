#!/usr/bin/env python3
"""Qualify the entire unpublished catalog using isolated compiled future pins."""
import argparse
import copy
import json
import os
from pathlib import Path
import resource
import time
import subprocess

from native_resource_compression_probe import sha
from native_bundle_validation_fixture import write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('prepared', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--resume-installed', action='store_true', help='Recheck an installed native generation after a retained failed engine check')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.relative_to(root / '.tmp')
    output.mkdir(parents=True, exist_ok=args.resume_installed)
    project = output / 'project'
    project.mkdir(exist_ok=args.resume_installed)
    prepared = args.prepared.resolve()
    report_bytes = (prepared / 'report.json').read_bytes()
    prepared_report = json.loads(report_bytes)
    assert prepared_report['complete'] and prepared_report['pairs'] == 1200
    old_path = root / 'release/approved_3d_bundles_v10_index.json'
    assert sha(old_path.read_bytes()) == prepared_report['index_sha256']
    new_path = prepared / 'draft-index.json'
    assert sha(new_path.read_bytes()) == prepared_report['draft_index_sha256']
    compact_path = output / 'compact-native-index.json'
    compact = json.loads(new_path.read_bytes())
    compact_path.write_text(json.dumps(compact, separators=(',', ':')) + '\n')
    assert json.loads(compact_path.read_text()) == compact and compact_path.stat().st_size < 1024 * 1024
    new_path = compact_path
    registry_bytes = (root / 'scripts/battle/battle_ui/reviewed_model_catalog.json').read_bytes()
    assert sha(registry_bytes) == prepared_report['registry_sha256']
    registry = json.loads(registry_bytes)
    new_models = json.loads((prepared / 'draft-models.json').read_text())['models']
    rows = {e['identity']: e for a in prepared_report['assets'] for e in a['entries']}
    for identity, model in new_models.items():
        model['cache_source_bytes'] = rows[identity]['source_bytes']
    registry['models'].update(new_models)
    stages = []
    for label, path, field in [('original', old_path, 'source_archive'), ('native-256k', new_path, 'candidate_archive')]:
        index = json.loads(path.read_text())
        key = 'qualification/' + label + '.json'
        descriptor = {'schema': 1, 'kind': 'pokeaether-release-asset-index', 'revision': index['catalog_revision'],
            'url': 'http://127.0.0.1/' + key, 'objectBaseUrl': 'http://127.0.0.1', 'object_key': key,
            'sha256': sha(path.read_bytes()), 'sizeBytes': path.stat().st_size,
            'requiredAssetIds': [a['asset_id'] for a in index['assets']]}
        stages.append({'label': label, 'index_path': str(path), 'descriptor': descriptor,
            'archives': {a['asset_id']: a[field] for a in prepared_report['assets']},
            'models': {e['identity']: copy.deepcopy(registry['models'][e['identity']]) for a in prepared_report['assets'] for e in a['entries']}})
        if label == 'original':
            for identity, model in stages[-1]['models'].items():
                # Profiles are unchanged; the original encoded revision is the primary for baseline runs.
                model['sha256'] = rows[identity]['source_sha256']
                model.pop('cache_source_bytes', None)
    controls = ['floragato', 'grimmsnarl', 'maushold', 'marshadow', 'gliscor', 'charmander', 'garchomp-mega', 'dragonite', 'roaring-moon']
    by_identity = {a['appearances'][0]['runtime_identity']: a['asset_id'] for a in json.loads(old_path.read_text())['assets']}
    fixture = {'prototype_only': True, 'production_approved': False, 'stages': stages,
        'control_asset_ids': [by_identity[name] for name in controls],
        'control_identities': [name + suffix for name in controls for suffix in ['', '@shiny']]}
    write_json(output / 'fixture.json', fixture)
    if args.resume_installed:
        prior = json.loads((output / 'report.json').read_text())
        assert not prior['complete'] and prior['pairs_installed'] == 1200 and prior['appearances_installed'] == 2400
        assert prior['restart_no_op'] and prior['on_demand_pin_selection_cached_reuse_and_repair']
        write_json(output / 'previous-attempt-report.json', prior)
    # Source-only links, fresh project cache and generated release metadata.
    for p in (root / 'launcher/scripts').glob('*.gd'):
        target = project / 'scripts' / p.name
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists(): target.symlink_to(p)
    for p in (root / 'launcher/data').glob('*.json'):
        target = project / 'data' / p.name
        target.parent.mkdir(parents=True, exist_ok=True)
        if p.name in ['approved_3d_release_v9.json', 'approved_3d_release_v10.json']:
            stage = stages[0 if 'v9' in p.name else 1]
            d = stage['descriptor']
            write_json(target, {'schema': 1, 'revision': d['revision'], 'requiredAssetIds': d['requiredAssetIds'],
                'index': {'object_key': d['object_key'], 'sha256': d['sha256'], 'size_bytes': d['sizeBytes']}})
        elif p.name == 'reviewed_model_catalog.json':
            write_json(target, registry)
        else:
            if not target.exists(): target.symlink_to(p)
    source_files = [root / 'scripts/services/on_demand_3d_bundle_service.gd', root / 'scripts/services/desktop_asset_storage.gd',
        root / 'scripts/battle/battle_ui/reviewed_model_catalog.gd', root / 'scripts/battle/battle_ui/model_form_dependencies.gd', root / 'scripts/battle/battle_ui/model_resource_cache.gd', root / 'scripts/data/mega_champions_catalog.gd', root / 'data/mega_champions_catalog.generated.json', root / 'scripts/battle/battle_ui/screened_model_catalog.json']
    source_files += list((root / 'scripts/battle/animations').glob('*.gd'))
    source_files += list((root / 'resources/battle/model_animations').glob('*'))
    for source in source_files:
        if not source.is_file(): continue
        target = project / source.relative_to(root)
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists(): target.symlink_to(source)
    write_json(project / 'scripts/battle/battle_ui/reviewed_model_catalog.json', registry)
    target = project / 'tests/native_catalog_rollout_check.gd'
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists(): target.symlink_to(root / 'launcher/tests/native_catalog_rollout_check.gd')
    (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Native catalog rollout ' + output.name + '"\n')
    env = os.environ.copy()
    env.update(NATIVE_ROLLOUT_FIXTURE=str(output / 'fixture.json'), NATIVE_ROLLOUT_OUTPUT=str(output))
    if args.resume_installed: env['NATIVE_ROLLOUT_RESUME_INSTALLED'] = '1'
    godot = env.get('GODOT_BIN', 'godot')
    with (output / 'import.log').open('w') as log:
        subprocess.run([godot, '--headless', '--editor', '--path', str(project), '--import'], env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
    with (output / 'check.log').open('w') as log:
        process = subprocess.Popen([godot, '--rendering-method', 'forward_plus', '--path', str(project), '--script', 'res://tests/native_catalog_rollout_check.gd'], env=env, stdout=log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 3600
        while process.poll() is None:
            messages = (output / 'check.log').read_text()
            if 'SCRIPT ERROR:' in messages or '\nERROR:' in messages or time.monotonic() > deadline:
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
                break
            time.sleep(1)
        result = subprocess.CompletedProcess(process.args, process.returncode)
    receipt = {'source_report_sha256': sha(report_bytes), 'source_registry_sha256': sha(registry_bytes),
        'script_sha256': sha(Path(__file__).read_bytes()),
        'engine_check_sha256': sha((root / 'launcher/tests/native_catalog_rollout_check.gd').read_bytes()),
        'resumed_installed_generation': args.resume_installed, 'renderer': 'forward_plus', 'peak_child_rss_bytes': resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss * 1024,
        'exit_code': result.returncode, 'complete': False, 'production_approved': False}
    write_json(output / 'receipt.json', receipt)
    check = json.loads((output / 'report.json').read_text())
    log = (output / 'check.log').read_text()
    assert result.returncode == 0 and check['complete'] and 'SCRIPT ERROR:' not in log and '\nERROR:' not in log
    receipt['complete'] = True
    receipt['report_sha256'] = sha((output / 'report.json').read_bytes())
    write_json(output / 'receipt.json', receipt)
    print('NATIVE_FULL_ROLLOUT_CHECK_OK', flush=True)


if __name__ == '__main__':
    main()
