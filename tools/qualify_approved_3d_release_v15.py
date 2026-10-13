#!/usr/bin/env python3
"""Run compiled v15 admission, real GPU upgrade/restart/rollback and presenters.

Invoke through ops/worktrees/slot-env (or release-env); retained packs are read
in place. This performs no publication, builds or production access.
"""
import argparse
import os
from pathlib import Path
import subprocess

from audit_cross_form_resources import catalog
from package_approved_3d_release_v15 import ROOT, read, sha, write


def fixtures(work, previous_sources):
    _, previous = catalog()
    previous = {a['asset_id']: a for a in previous}
    sources = read(previous_sources)['sources']
    current = read(work / 'sources.json')['sources']
    selected = read(ROOT / 'data/model_pair_release_v15_catalog.json')
    by_id = {a['asset_id']: a for a in selected['assets']}
    changes = read(ROOT / 'release/approved_3d_v15_binding.json')['replacements']
    controls = ['alcremie-caramel-swirl', 'unown-exclamation', 'gourgeist-large',
                'sinistcha-masterpiece', 'poltchageist-artisan', 'greninja-ash',
                'pikachu-rock-star', 'tyranitar', 'hydreigon', 'urshifu-rapid-strike',
                'landorus-therian']
    ids = ['pokemon_3d:' + name + ':base' for name in controls]
    write(work / 'upgrade-input.json', {'previous': {k: sources[k] for k in ids},
                                      'current': {k: current[k] for k in ids}, 'additional': {}})
    fixture = {'schema': 1, 'packs': [], 'models': [], 'pairs': []}
    for key in sorted(changes):
        old, new = previous[key], by_id[key]
        fixture['packs'] += [{'asset': old, 'path': sources[key]}, {'asset': new, 'path': current[key]}]
        fixture['pairs'].append(new['appearances'][0]['runtime_identity'])
        for before, after in zip(old['appearances'], new['appearances'], strict=True):
            fixture['models'].append({'identity': after['runtime_identity'], 'variant': after['variant'],
                'source_path': old['pair_manifest']['resource_root'] + '/' + before['runtime_path'],
                'source_sha256': before['runtime_sha256'], 'source_bytes': before['bytes'],
                'candidate_path': new['pair_manifest']['resource_root'] + '/' + after['runtime_path'],
                'candidate_sha256': after['runtime_sha256'], 'candidate_bytes': after['bytes'],
                'pair_asset': new, 'pack_path': current[key]})
    write(work / 'actor-input.json', fixture)


def run(work, script, name, args=(), headless=False, env=None, timeout=600):
    command = ['godot', '--audio-driver', 'Dummy', '--path', str(ROOT),
               '--log-file', str(work / (name + '.log')), '--script', 'res://' + script]
    command += ['--headless'] if headless else ['--rendering-method', 'gl_compatibility']
    if args:
        command += ['--', *map(str, args)]
    with (work / (name + '.stdout.log')).open('w') as output:
        result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT,
                                env={**os.environ, **(env or {})}, timeout=timeout)
    assert result.returncode == 0, f'{name} failed; see {work / (name + ".stdout.log")}'
    text = (work / (name + '.stdout.log')).read_text()
    assert 'ERROR:' not in text and 'SCRIPT ERROR' not in text, name
    print('V15_QUALIFICATION_OK ' + name, flush=True)


def qualify(work, previous_sources):
    work = Path(work).resolve()
    fixtures(work, previous_sources)
    run(work, 'tests/approved_3d_release_v15_check.gd', 'binding-runtime', headless=True,
        env={'POKEAETHER_V15_BINDING_REPORT': str(work / 'binding-runtime.json')})
    for phase in ['original', 'verify-original', 'upgrade', 'verify-upgrade', 'rollback', 'verify-rollback']:
        run(work, 'tests/model_release_v15_upgrade_check.gd', 'upgrade-' + phase,
            [work / 'upgrade-input.json', work / 'upgrade', phase])
    run(work, 'tests/model_release_v15_actor_check.gd', 'actors',
        [work / 'actor-input.json', work / 'actors.json'], timeout=3600)
    print('V15_CLIENT_QUALIFICATION_COMPLETE admission=1420 upgrade_controls=11 actor_pairs=111', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--previous-sources', type=Path, required=True)
    args = parser.parse_args()
    qualify(args.work, args.previous_sources)
