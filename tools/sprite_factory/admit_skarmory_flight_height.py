"""Admit the reviewed higher Skarmory pair after its local delivery checks."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / '.tmp/remaining-274-production/skarmory-flight-v1'

def read(path):
    return json.loads(path.read_text())

def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def write(path, data):
    path.write_text(json.dumps(data, indent=2, sort_keys=True, allow_nan=False) + '\n')

def main():
    candidate = read(HERE / 'catalog_skarmory_flight_height_candidate.json')
    assert candidate['user_approval']['answer'] == 'Nieuwe hoogte is goed'
    for rel, digest in candidate['evidence_sha256'].items():
        assert sha(ROOT / rel) == digest, rel
    rows = read(WORK / 'runtime-catalog-final.json')
    fixture = read(WORK / 'runtime-fixture.json')
    assert len(rows) == 2 and {(r['species'],r['variant']) for r in rows} == {('skarmory','normal'),('skarmory','shiny')}
    expected = {r['variant']:r['runtime_sha256'] for r in rows}
    installed = read(WORK / 'installed/installed-catalog.json')
    assert {r['variant']:r['runtime_sha256'] for r in installed} == expected
    for r in rows + installed:
        assert sha(Path(r['runtime_path'])) == r['runtime_sha256']
    compression = read(WORK / 'compression-proof.json')['pairs']
    assert len(compression) == 2
    reviewed = {r['variant']:r for r in candidate['candidates']}
    for proof in compression:
        variant = proof['species'].split('-')[-1]
        assert proof['normal_runtime_sha256'] == reviewed[variant]['runtime_sha256']
        assert proof['shiny_runtime_sha256'] == expected[variant]
    capture = read(WORK / 'captures-v2/battle-review.json')
    assert capture['complete']
    checked = [r for r in capture['entries'] if 'shots' in r]
    assert len(checked) == 2
    for row in checked:
        assert len(row['shots']) == 16 and all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in row['shots'])
        assert min(c['minimum_y'] for c in row['corrected_clearance_120hz'].values()) >= .015
    for file, marker in [('install.log','REMAINING_144_BUNDLES_OK bundles=1 scenes=2 resumed=0 no_op=true restart=true'),('update-check.log','SKARMORY_V1_V2_UPDATE_OK scenes=2 no_op=true restart=true'),('installed-stress-fixed.log','BATCH01_STRESS_OK')]:
        log = (WORK / file).read_text()
        assert marker in log and 'ERROR:' not in log, file
    stress = read(WORK / 'installed-stress-fixed.json')
    assert stress['complete'] and stress['species'] == ['skarmory'] and stress['catalog_sha256'] == sha(WORK / 'installed/installed-catalog.json')
    assert [r['arena'] for r in stress['rounds']] == ['classic','stadium','classic']
    for round in stress['rounds']:
        assert round['pairs'] == round['faint_replacements'] == 1
        assert round['retained_source_bytes'] <= 64 * 1024 * 1024
    index = read(WORK / 'bundles/asset-index.json')
    assert len(index['assets']) == 1
    asset = index['assets'][0]
    assert asset['species_id'] == 'skarmory' and asset['version'] == 2
    archive = WORK / 'bundles' / Path(asset['object_key']).name
    assert sha(archive) == asset['sha256'] and archive.stat().st_size == asset['size_bytes']
    assert {a['variant']:a['runtime_sha256'] for a in asset['appearances']} == expected
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    previous = read(WORK / 'previous-registry-skarmory.json')
    assert registry['profiles']['skarmory'] == previous['profile']
    assert {k:registry['models'][k] for k in previous['models']} == previous['models']
    profile = copy.deepcopy(fixture['profiles']['skarmory-normal'])
    rare = copy.deepcopy(fixture['profiles']['skarmory-shiny'])
    profile['motion'].pop('sha256'); rare['motion'].pop('sha256')
    assert profile == rare
    # Existing v1 scenes remain safe under this profile: placement, clocks and
    # clearance offsets are unchanged, and each bound encloses both revisions.
    for key in ('placement','grounding','action_timing','motion'):
        assert profile[key] == previous['profile'][key]
    for action, old in previous['profile']['bounds'].items():
        bound = profile['bounds'][action]
        for i in range(3):
            assert bound['min'][i] <= old['min'][i] + 1e-8
            assert bound['min'][i] + bound['size'][i] >= old['min'][i] + old['size'][i] - 1e-8
    registry['profiles']['skarmory'] = profile
    count = len(registry['models'])
    for row in rows:
        identity = 'skarmory' + ('@shiny' if row['variant']=='shiny' else '')
        old = registry['models'][identity]
        registry['models'][identity] = {**old, **fixture['models'][identity], 'profile':'skarmory', 'previous_sha256':sorted(set(old.get('previous_sha256',[]) + [old['sha256']]))}
    assert len(registry['models']) == count
    files = [HERE / 'catalog_skarmory_flight_height_candidate.json', Path(__file__), ROOT / 'scripts/battle/battle_ui/immersive_hud.gd'] + [WORK / name for name in ('runtime-catalog-final.json','runtime-fixture.json','previous-registry-skarmory.json','compression-proof.json','bundles/asset-index.json','installed/installed-catalog.json','install.log','update_check.gd','update-check.log','runtime_check.gd','installed-stress-fixed.json','installed-stress-fixed.log')]
    receipt = {'schema':1,'date':'2026-10-01','species':['skarmory'],'appearance_approved':True,'battle_approved':True,'runtime_approved':True,'published':False,'release_approved':False,'bundle_index':index,'bundle_size_bytes':asset['size_bytes'],'evidence_sha256':{str(p.relative_to(ROOT)):sha(p) for p in files},'scope':'Reviewed0.7m visual flight height; preserved native keys/bone poses; exact compression geometry/animation parity; actual120Hz floor checks and32 camera views; fresh install, actualv1-v2 update/no-op/restart and three installed real-battle functional passes. Frame-rate certification remains separate because concurrent Godot runs affect timing.','remaining':['R2 publication','Release certification/publication']}
    target = HERE / 'catalog_skarmory_flight_height_qualification.json'
    assert not target.exists()
    write(target, receipt)
    registry['skarmory_flight_height_qualification_sha256'] = sha(target)
    write(game, registry); launcher.write_bytes(game.read_bytes())
    print('SKARMORY_FLIGHT_ADMITTED variants=2 bundle_version=2 old_hashes_retained=true published=false')

if __name__ == '__main__':
    main()
