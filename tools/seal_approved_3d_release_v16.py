#!/usr/bin/env python3
"""Seal full Linux native coverage and compiled v16 download/restart qualification."""
import argparse
from pathlib import Path

from probe_v13_compression import read, write, require
from study_lossless_texture_storage import ROOT, sha

CODE = ['scripts/services/model_pair_pilot.gd', 'launcher/scripts/model_pair_pilot.gd',
    'scripts/services/model_pair_pack.gd', 'launcher/scripts/model_pair_pack.gd',
    'scripts/services/on_demand_3d_bundle_service.gd', 'launcher/scripts/asset_bundle_index.gd',
    'launcher/scripts/asset_bundle_store.gd', 'launcher/scripts/release_asset_bundles.gd',
    'launcher/scripts/bulk_asset_downloads.gd', 'scripts/battle/battle_ui/experimental_battle_3d.gd',
    'scripts/services/settings_manager.gd', 'scripts/ui/battle_visual_choice.gd',
    'data/android_3d_experiment.json', 'data/battle_visual_download_info.json',
    'tools/package_approved_3d_release_v16.py', 'tools/rebind_release_resource_paths.py',
    'tools/prepare_approved_3d_catalog_v16.py', 'tools/qualify_approved_3d_release_v16.py',
    'tools/check_approved_3d_runtime_v16.py', 'tools/seal_approved_3d_release_v16.py',
    'tools/publish_approved_3d_index_v16.py', 'tools/package_launcher_release.py',
    'tools/probe_v13_compression.py', 'tools/study_shared_form_textures.py',
    'tools/study_lossless_texture_storage.py', 'tools/run_shared_texture_runtime_checks.py',
    'tools/publish_shared_model_collection.py', 'tools/publish_qualified_3d_bundles.py',
    'tools/upload_launcher_release.py', 'tools/publish_approved_3d_index_v8.py',
    'tools/verify_android_3d_assets.py', 'tools/android_release.py',
    'tests/model_release_v16_native_check.gd', 'tests/model_release_v16_runtime_check.gd',
    'tests/approved_3d_release_v16_check.gd', 'launcher/tests/model_release_v16_binding_check.gd',
    'tests/android_3d_model_release_check.gd',
    '.github/workflows/build-android.yml', '.github/workflows/deploy-desktop-r2.yml']


def seal(native, runtime, launcher_log):
    binding_path = ROOT / 'release/approved_3d_v16_binding.json'
    binding = read(binding_path)
    full = read(native / 'qualification.json')
    flow = read(runtime / 'qualification.json')
    require(full['complete'] and full['scene_states_exact'] and full['deep_duplicates_exact'], 'Incomplete native qualification')
    require(len(full['records']) == 1365 and sum(len(r['looks']) for r in full['records']) == 2730, 'Native appearance coverage incomplete')
    require(full['configuration_sha256'] == flow['configuration_sha256'] == binding['assembly_sha256'], 'Qualification targets differ')
    require(flow['complete'] and flow['revision'] == binding['revision'] and flow['restart_http_requests'] == 0 and
            flow['cold_pool_requests'] == 3 and flow['corruption_repaired'] and flow['partial_failure_rejected'] and flow['launcher_handoff'], 'Incomplete runtime qualification')
    require(flow['battles'] == 16 and flow['previews'] == 32, 'Presenter coverage incomplete')
    for name, expected in full['inputs'].items():
        path = (native / name).resolve()
        require(path.is_relative_to(ROOT) and sha(path) == expected, 'Native source changed: ' + name)
    for name, expected in full['driver_inputs'].items():
        require(sha(ROOT / name) == expected, 'Native driver changed: ' + name)
    for name, expected in flow['inputs'].items():
        path = (runtime / 'native-project' / name).resolve()
        require(path.is_relative_to(ROOT) and sha(path) == expected, 'Runtime source changed: ' + name)
    require(flow['driver_sha256'] == sha(ROOT / 'tools/check_approved_3d_runtime_v16.py'), 'Runtime driver changed')
    for name, expected in full['reports'].items():
        require(sha(native / name) == expected, 'Native report changed')
    for phase, expected in flow['reports'].items():
        require(sha(runtime / phase / 'report.json') == expected, 'Runtime report changed')
        text = (runtime / phase / 'stdout.log').read_text()
        require('V16_SHARED_TEXTURE_RUNTIME_OK' in text and 'ERROR:' not in text, 'Runtime engine error')
    text = launcher_log.read_text()
    require('LAUNCHER_V16_BINDING_OK' in text and 'ERROR:' not in text and 'SCRIPT ERROR' not in text, 'Standalone launcher failed')
    for name, value in [('approved_3d_v16_native_qualification.json', full), ('approved_3d_v16_runtime_qualification.json', flow)]:
        write(ROOT / 'release' / name, value)
    binding.update(runtime_approved=True, publication_approved=True,
        qualification='Linux Godot 4.6.2 Compatibility; native Windows/macOS and physical Android remain untested.',
        native_pck_pairs=1365, native_appearances=2730, unchanged_zip_pairs=55,
        full_collection_runtime_qualified=True, other_platforms_qualified=False,
        native_motion_samples=full['motion_samples'], actual_battles=16, actual_previews=32,
        shared_pool_corruption_repaired=True, restart_no_download=True, launcher_handoff_verified=True,
        native_qualification_sha256=sha(ROOT / 'release/approved_3d_v16_native_qualification.json'),
        runtime_qualification_sha256=sha(ROOT / 'release/approved_3d_v16_runtime_qualification.json'),
        standalone_launcher_log_sha256=sha(launcher_log), code_bindings={name: sha(ROOT / name) for name in CODE})
    write(binding_path, binding)
    print('V16_BINDING_SEALED full_collection=true publication_pending=true', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', type=Path, required=True)
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--launcher-log', type=Path, required=True)
    args = parser.parse_args()
    seal(args.native.resolve(), args.runtime.resolve(), args.launcher_log.resolve())
