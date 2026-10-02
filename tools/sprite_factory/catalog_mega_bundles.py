"""Prepare local Mega bundle candidates; preparation never grants admission."""
import argparse
import copy
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from package_optional_3d_bundle_prototype import build, encoded
from catalog_mega_3d_production import sha


def read(path):
    return json.loads(path.read_text())


def prepare(cohort, profiles_path, output, *, expected_pairs=71, approval_path=None, baseline_path=None):
    acceptance = read(approval_path or Path(__file__).with_name('catalog_mega_battle_checkpoint.json'))
    assert expected_pairs > 0 and acceptance['battle_visual_approved'] and acceptance['appearance_pair_count'] == expected_pairs
    for key in ('catalog', 'runtime_catalog', 'native_60hz_baseline', 'review_manifest'):
        evidence = acceptance['evidence'][key]
        assert sha(Path(evidence['path'])) == evidence['sha256']
    profiles = read(profiles_path)
    assert not profiles['runtime_approved'] and not profiles['motion_holds']
    assert profiles['catalog_sha256'] == sha(cohort / 'catalog.json')
    raw = {r['species']: r for r in read(cohort / 'runtime.json')}
    baseline_path = baseline_path or cohort / 'baseline/battle-review.json'
    baseline = read(baseline_path)
    assert baseline['complete'] and baseline['catalog_sha256'] == sha(cohort / 'catalog.json')
    measured = {r['species']: r for r in baseline['entries'] if 'clips' in r}
    intake = {r['showdown_id']: r for r in read(Path(__file__).with_name('catalog_mega_3d_source_intake.json'))['entries']}
    assert len(raw) == len(profiles['motion']) == expected_pairs * 2
    assert set(raw) == set(profiles['motion']) == set(measured)
    fixture, rows, names = {'models': {}, 'profiles': {}}, [], {}
    for identifier, source in sorted(raw.items()):
        showdown = identifier.removesuffix('-shiny')
        target = intake[showdown]['name']
        base, suffix = target.split('-mega', 1)
        form = 'mega' + suffix
        assert form in ('mega', 'mega-x', 'mega-y', 'mega-z')
        names[target] = dict(base=base, form=form, dex=intake[showdown]['pokedex_number'])
        variant = 'shiny' if identifier.endswith('-shiny') else 'normal'
        identity = target + ('@shiny' if variant == 'shiny' else '')
        assert sha(Path(source['path'])) == source['glb_sha256'] == measured[identifier]['glb_sha256']
        assert sha(Path(source['runtime_path'])) == source['runtime_sha256']
        motion = copy.deepcopy(profiles['motion'][identifier])
        assert motion['sha256'] == source['glb_sha256']
        for action, timing in source['action_timing'].items():
            assert abs(timing['frames'] / 60 - measured[identifier]['clips'][action]['duration']) < 1e-5
        motion['sha256'] = source['runtime_sha256']
        placement = {k: motion[k] for k in ('scale', 'yaw_degrees')}
        normal = measured[showdown]
        bounds = {a: {'min': [v / normal['scale'] for v in c['envelope_min']],
                      'size': [v / normal['scale'] for v in c['envelope_size']]}
                  for a, c in normal['clips'].items()}
        fixture['models'][identity] = {'sha256': source['runtime_sha256'],
            'glb_sha256': source['glb_sha256'], 'profile': target + '-' + variant}
        profile = {'action_timing': source['action_timing'], 'placement': placement,
                   'grounding': dict(placement, lift=motion['lift']), 'motion': motion, 'bounds': bounds}
        if 'physical_attack_2' in source['action_timing']:
            profile['attack_family_actions'] = {'body_charge': 'physical_attack_2'}
        fixture['profiles'][target + '-' + variant] = profile
        rows.append(dict(source, species=target, variant=variant, placement=placement))
    assert len(names) == expected_pairs
    for name in names:
        normal = copy.deepcopy(fixture['profiles'][name + '-normal'])
        shiny = copy.deepcopy(fixture['profiles'][name + '-shiny'])
        normal['motion'].pop('sha256'); shiny['motion'].pop('sha256')
        assert normal == shiny, name
    output.mkdir(parents=True, exist_ok=False)
    (output / 'runtime-catalog.json').write_bytes(encoded(rows))
    (output / 'runtime-fixture.json').write_bytes(encoded(fixture))
    bundles = output / 'bundles'; bundles.mkdir()
    assets, index = [], None
    hashes = {key: row['sha256'] for key, row in fixture['models'].items()}
    for name, info in sorted(names.items()):
        part = build(output / 'runtime-catalog.json', bundles / name,
            revision=f'mega-{expected_pairs}-local-candidates-v1', species_set=(info['base'],),
            dex={info['base']: info['dex']}, candidate_hashes=hashes,
            form_id=info['form'], runtime_suffix='-' + info['form'])
        asset = part['assets'][0]
        archive = bundles / name / Path(asset['object_key']).name
        shutil.move(archive, bundles / archive.name)
        assets.append(asset); index = part
    index = dict(index, assets=assets)
    (bundles / 'asset-index.json').write_bytes(encoded(index))
    (output / 'preparation.json').write_bytes(encoded(dict(schema=1, pair_count=expected_pairs,
        runtime_approved=False, published=False, independent_native_validation_pending=True,
        focused_placement_visual_acceptance_pending=True, catalog_sha256=sha(cohort / 'catalog.json'),
        runtime_source_sha256=sha(cohort / 'runtime.json'), profiles_sha256=sha(profiles_path),
        bundle_index_sha256=sha(bundles / 'asset-index.json'),
        total_bytes=sum(a['size_bytes'] for a in assets))))
    print(f'MEGA_LOCAL_CANDIDATES pairs={expected_pairs} scenes={expected_pairs * 2} bundles={expected_pairs} runtime_approved=false', flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('cohort', 'profiles', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--expected-pairs', type=int, default=71)
    p.add_argument('--approval', type=Path)
    p.add_argument('--baseline', type=Path)
    a = p.parse_args()
    prepare(a.cohort.resolve(), a.profiles.resolve(), a.output.resolve(), expected_pairs=a.expected_pairs,
            approval_path=a.approval.resolve() if a.approval else None,
            baseline_path=a.baseline.resolve() if a.baseline else None)
