"""Prepare and admit locally qualified Therian models; never publish or select a release."""
import argparse
import copy
import json
import os
import struct
import sys
from pathlib import Path

from catalog_therian_models import ROOT, WORK, NAMES, INTAKE, read, sha, write

sys.path.insert(0, str(ROOT / 'tools'))
from package_optional_3d_bundle_prototype import build, encoded
from native_resource_compression_probe import Zstd, decode, encode
from probe_v13_compression import pack_pck, digest
from qualify_shared_model_catalog import compare


def prepare():
    raw = read(WORK / 'runtime/report.json')
    review = read(WORK / 'battle/final-v2/battle-review.json')
    placement = read(WORK / 'battle/placement.json')
    assert review['complete'] and not placement['motion_holds']
    measured = {r['species']: r for r in review['entries'] if 'clips' in r}
    fixture = {'models': {}, 'profiles': {}}
    rows = []
    for source in raw:
        name = source['species']; m = measured[name]
        assert sha(source['path']) == source['glb_sha256'] == m['glb_sha256']
        assert sha(source['runtime_path']) == source['runtime_sha256']
        assert source['complete_pose_channels']
        assert all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in m['shots'])
        assert min(c['minimum_y'] for c in m['corrected_clearance_120hz'].values()) >= .025 - 1e-5
        motion = copy.deepcopy(placement['motion'][name])
        assert motion['sha256'] == source['glb_sha256']
        assert abs(motion['lift'] - m['candidate_lift']) < .001
        assert abs(motion['scale'] - m['scale']) < 1e-6
        motion['sha256'] = source['runtime_sha256']
        species = name.removesuffix('-shiny')
        variant = 'shiny' if name.endswith('-shiny') else 'normal'
        identity = species + ('@shiny' if variant == 'shiny' else '')
        position = {k: motion[k] for k in ('scale', 'yaw_degrees')}
        position['hover_height'] = placement['hover'][name]
        normal = measured[species]
        bounds = {a: {'min': [v / normal['scale'] for v in c['envelope_min']],
                      'size': [v / normal['scale'] for v in c['envelope_size']]}
                  for a, c in normal['clips'].items()}
        fixture['models'][identity] = {'sha256': source['runtime_sha256'],
            'glb_sha256': source['glb_sha256'], 'profile': species + '-' + variant}
        fixture['profiles'][species + '-' + variant] = {'action_timing': source['action_timing'],
            'placement': position, 'grounding': dict(position, lift=motion['lift']),
            'motion': motion, 'bounds': bounds,
            'attack_family_actions': {'body_charge': 'physical_attack_2'}}
        rows.append(dict(source, species=species, variant=variant, placement=position))
    assert len(rows) == 6 and {r['species'] for r in rows} == set(NAMES)
    for species in NAMES:
        a, b = [copy.deepcopy(fixture['profiles'][species + '-' + v]) for v in ('normal', 'shiny')]
        a['motion'].pop('sha256'); b['motion'].pop('sha256')
        assert a == b
    write(WORK / 'runtime-fixture.json', fixture)
    write(WORK / 'runtime-catalog.json', rows)
    build(WORK / 'runtime-catalog.json', WORK / 'bundles', revision='therian-local-v1',
          species_set=tuple(sorted(NAMES)), dex=NAMES,
          candidate_hashes={k: v['sha256'] for k, v in fixture['models'].items()})
    print('THERIAN_PREPARED pairs=3 scenes=6')


def packs():
    generated = read(WORK / 'runtime-project/.tmp/texture-pairs/report.json')
    codec = Zstd()
    index = {'schema': 1, 'kind': 'pokeaether-optional-asset-index', 'catalog_revision': 'therian-shared-local-v1',
             'runtime_contract': {'pokemon_3d': 2, 'godot': '4.6'}, 'assets': []}
    output = WORK / 'shared'; (output / 'packs').mkdir(parents=True, exist_ok=False)
    render = {'models': [], 'packs': []}; jobs = []
    for pair in generated['pairs']:
        files = {}; appearances = []
        for row in pair['models']:
            assert sha(row['candidate_path']) == row['candidate_sha256']
            assert sha(row['source_path']) == row['source_sha256']
            raw = decode(Path(row['candidate_path']).read_bytes(), codec)
            native = encode(raw, 262144, 19, codec)
            assert decode(native, codec) == raw
            name = 'models/' + row['variant'] + '.scn'; files[name] = native
            appearances.append({'variant': row['variant'], 'runtime_identity': row['identity'], 'runtime_path': name,
                'runtime_sha256': digest(native), 'bytes': len(native), 'source_sha256': row['source_sha256'],
                'cache_source_bytes': Path(row['source_path']).stat().st_size, 'semantic_sha256': row['semantic_sha256']})
            render['models'].append({'identity': row['identity'], 'source_path': row['source_path'],
                'source_sha256': row['source_sha256'], 'candidate_path': pair['namespace'] + '/' + name,
                'candidate_sha256': digest(native)})
        for path in sorted((Path(pair['directory']) / 'textures').glob('*.res')):
            raw = decode(path.read_bytes(), codec); native = encode(raw, 262144, 19, codec)
            assert decode(native, codec) == raw
            files['textures/' + path.name] = native
        manifest = {'schema': 1, 'kind': 'pokeaether-model-pair', 'asset_id': 'pokemon_3d:' + pair['species'] + ':base',
            'species_id': pair['species'], 'form_id': 'base', 'version': 1, 'dependencies': [],
            'appearances': appearances, 'resource_root': pair['namespace'],
            'files': [{'path': n, 'bytes': len(b), 'sha256': digest(b), 'decoded_bytes': struct.unpack_from('<I', b, 12)[0]}
                      for n, b in sorted(files.items())]}
        files['bundle.json'] = encoded(manifest)
        data = pack_pck(files, pair['namespace'])
        name = 'v1-' + digest(data) + '.pck'; path = output / 'packs' / name; path.write_bytes(data)
        asset = {k: manifest[k] for k in ('asset_id', 'species_id', 'form_id', 'version', 'dependencies', 'appearances')}
        asset.update(format='model-pair-pck-v1', national_dex=NAMES[pair['species']], pair_manifest=manifest,
            sha256=digest(data), size_bytes=len(data),
            object_key='optional-assets/pokemon_3d/' + pair['species'] + '/base/' + name)
        index['assets'].append(asset)
        pin = {'path': str(path), 'asset': asset}; render['packs'].append(pin)
        jobs.append({'asset_id': asset['asset_id'], 'packs': {'shared': pin}, 'models': pair['models']})
    write(output / 'index.json', index); write(output / 'render-input.json', render)
    write(output / 'validate-input.json', {'jobs': jobs})
    print('THERIAN_PACKED pairs=3 bytes=' + str(sum(a['size_bytes'] for a in index['assets'])))


def pixels():
    rows = compare(WORK / 'shared/render-qualified')
    assert len(rows) == 6 and all(r['pixels_exact'] for r in rows)
    frames = sum(len(r['frames']) for r in rows)
    assert frames == 72
    write(WORK / 'shared/pixel-comparison.json', {'complete': True, 'exact_frames': frames, 'models': rows})
    print('THERIAN_PIXELS_OK frames=' + str(frames))


def admit():
    fixture = read(WORK / 'runtime-fixture.json')
    appearance = read(WORK / 'appearance/godot-review.json')
    assert len(appearance['entries']) == 6 and all(r['errors'] == [] for r in appearance['entries'])
    assert read(WORK / 'transitions.json')['failures'] == []
    validation = [json.loads(line) for line in (WORK / 'shared/validated/receipts.jsonl').read_text().splitlines()]
    assert len(validation) == 3 and all(r['packs']['shared']['ok'] for r in validation)
    pixels = read(WORK / 'shared/pixel-comparison.json')
    assert pixels['complete'] and pixels['exact_frames'] == 72
    for name in ('runtime-check.log', 'shared-runtime-check.log'):
        log = (WORK / name).read_text()
        assert 'THERIAN_RUNTIME_OK' in log and 'ERROR:' not in log
    index = read(WORK / 'shared/index.json')
    for asset in index['assets']:
        path = WORK / 'shared/packs' / Path(asset['object_key']).name
        assert sha(path) == asset['sha256'] and path.stat().st_size == asset['size_bytes']
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes(); registry = read(game)
    for species in NAMES:
        profile = copy.deepcopy(fixture['profiles'][species + '-normal']); profile['motion'].pop('sha256')
        assert species not in registry['profiles']; registry['profiles'][species] = profile
        for variant in ('normal', 'shiny'):
            identity = species + ('@shiny' if variant == 'shiny' else '')
            assert identity not in registry['models']
            registry['models'][identity] = dict(fixture['models'][identity], profile=species)
    evidence = ['runtime/report.json', 'runtime-fixture.json', 'appearance/godot-review.json', 'transitions.json',
        'battle/placement.json', 'battle/final-v2/battle-review.json', 'shared/validated/receipts.jsonl',
        'shared/pixel-comparison.json', 'shared/render-qualified/report.json', 'runtime-check.log', 'shared-runtime-check.log']
    receipt = {'schema': 1, 'forms': sorted(NAMES), 'models': 6, 'reviewer': 'assistant',
        'scope': 'Local Linux Godot 4.6.2; native appearance, battle placement, animation transitions, delivery and shared textures',
        'published': False, 'release_approved': False, 'runtime_approved': True,
        'source_intake_sha256': sha(INTAKE), 'bundle_index_sha256': sha(WORK / 'shared/index.json'),
        'bundle_size_bytes': sum(a['size_bytes'] for a in index['assets']), 'pixel_exact_frames': pixels['exact_frames'],
        'sharing': 'Textures shared within each normal/shiny pair; independent scenes retain animated eye materials',
        'visual_review': 'Assistant inspected all six idle-front appearances, normal back/attack/sleep/faint poses, and both battle cameras including shiny and grounded rest.',
        'evidence_sha256': {p: sha(WORK / p) for p in evidence},
        'remaining': ['Include three packs in the next selected model index', 'Release certification and publication']}
    receipt_path = Path(__file__).with_name('catalog_therian_qualification.json')
    write(receipt_path, receipt); registry['therian_qualification_sha256'] = sha(receipt_path)
    data = (json.dumps(registry, indent='\t', sort_keys=False, allow_nan=False) + '\n').encode()
    game.write_bytes(data); launcher.write_bytes(data)
    write(ROOT / 'release/approved_3d_therian_index.json', index)
    print('THERIAN_ADMITTED scenes=6 published=false')


def finalize():
    log = WORK / 'admitted-check.log'
    assert 'THERIAN_RUNTIME_OK' in log.read_text() and 'ERROR:' not in log.read_text()
    path = Path(__file__).with_name('catalog_therian_qualification.json')
    receipt = read(path)
    receipt['admitted_registry_check_passed'] = True
    receipt['evidence_sha256']['admitted-check.log'] = sha(log)
    receipt['code_sha256'] = {str(p.relative_to(ROOT)): sha(p) for p in [Path(__file__),
        Path(__file__).with_name('catalog_therian_models.py'),
        Path(__file__).with_name('catalog_therian_pair_render.gd'),
        Path(__file__).with_name('catalog_therian_battle_review.gd'),
        ROOT / 'tests/battle_3d_therian_check.gd']}
    write(path, receipt)
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game); registry['therian_qualification_sha256'] = sha(path)
    data = (json.dumps(registry, indent='\t', sort_keys=False, allow_nan=False) + '\n').encode()
    game.write_bytes(data); launcher.write_bytes(data)
    print('THERIAN_FINALIZED published=false')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('phase', choices=('prepare', 'packs', 'pixels', 'admit', 'finalize'))
    if os.environ.get('POKEAETHER_SLOT') != ROOT.parent.name:
        p.error('Run through assigned slot-env')
    globals()[p.parse_args().phase]()
