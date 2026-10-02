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


def prepare(cohort, profiles_path, output):
    acceptance = read(Path(__file__).with_name('catalog_mega_battle_checkpoint.json'))
    assert acceptance['battle_visual_approved'] and acceptance['appearance_pair_count'] == 71
    for key in ('catalog', 'runtime_catalog', 'native_60hz_baseline', 'review_manifest'):
        evidence = acceptance['evidence'][key]
        assert sha(Path(evidence['path'])) == evidence['sha256']
    profiles = read(profiles_path)
    assert not profiles['runtime_approved'] and not profiles['motion_holds']
    assert profiles['catalog_sha256'] == sha(cohort / 'catalog.json')
    raw = {r['species']: r for r in read(cohort / 'runtime.json')}
    measured = {r['species']: r for r in read(cohort / 'baseline/battle-review.json')['entries'] if 'clips' in r}
    intake = {r['showdown_id']: r for r in read(Path(__file__).with_name('catalog_mega_3d_source_intake.json'))['entries']}
    assert len(raw) == len(profiles['motion']) == 142
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
    assert len(names) == 71
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
            revision='mega-71-local-candidates-v1', species_set=(info['base'],),
            dex={info['base']: info['dex']}, candidate_hashes=hashes,
            form_id=info['form'], runtime_suffix='-' + info['form'])
        asset = part['assets'][0]
        archive = bundles / name / Path(asset['object_key']).name
        shutil.move(archive, bundles / archive.name)
        assets.append(asset); index = part
    index = dict(index, assets=assets)
    (bundles / 'asset-index.json').write_bytes(encoded(index))
    (output / 'preparation.json').write_bytes(encoded(dict(schema=1, pair_count=71,
        runtime_approved=False, published=False, independent_native_validation_pending=True,
        focused_placement_visual_acceptance_pending=True, catalog_sha256=sha(cohort / 'catalog.json'),
        runtime_source_sha256=sha(cohort / 'runtime.json'), profiles_sha256=sha(profiles_path),
        bundle_index_sha256=sha(bundles / 'asset-index.json'),
        total_bytes=sum(a['size_bytes'] for a in assets))))
    print('MEGA_LOCAL_CANDIDATES pairs=71 scenes=142 bundles=71 runtime_approved=false', flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('cohort', 'profiles', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    prepare(a.cohort.resolve(), a.profiles.resolve(), a.output.resolve())
