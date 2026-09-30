"""Bind the reviewed76 pairs to their final placement and local bundle inputs."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASE = ROOT / '.tmp/remaining-274-production/shiny-76/sleep-battle-v1'
BATTLE = BASE / 'battle-76'
WORK = ROOT / '.tmp/remaining-274-production/approved-76'

def read(path):
    return json.loads(path.read_text())

def sha(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()

def write(path, data):
    with path.open('x') as stream:
        json.dump(data, stream, indent=2, allow_nan=False)
        stream.write('\n')

def main():
    checkpoint_path = HERE / 'catalog_remaining_76_shiny_checkpoint.json'
    checkpoint = read(checkpoint_path)
    assert checkpoint['battle_user_approved_pairs'] == 76 and checkpoint['battle_user_review_pending'] == 0
    assert sha(BATTLE / 'review-v1/index.html') == checkpoint['battle_partial_approval']['page_sha256']
    assert sha(BATTLE / 'review-v1/receipt.json') == checkpoint['battle_partial_approval']['receipt_sha256']
    accepted = {r['species']:r for r in checkpoint['entries']}
    for item in accepted['wailord']['battle_size_review']['reports']:
        assert sha(ROOT / item['path']) == item['sha256']
    assert accepted['wailord']['battle_size_review']['user_approval']['answer'] == 'Nieuwe grootte is goed'
    dhelmise_envelope = read(BATTLE / 'dhelmise-final-envelope.json')
    assert len(accepted) == 76
    for entry in accepted.values():
        assert entry['appearance_user_approved'] and entry['sleep_user_approved'] and entry['battle_user_approved']
    normal_report = read(BATTLE / 'normal-combined.json')
    assert normal_report['complete']
    normal = {r['species']:r for r in normal_report['entries']}
    sources = {s:BATTLE / d for s,d in normal_report['sources'].items()}
    reports = [BATTLE / s['path'] for s in normal_report['source_reports']]
    for s in normal_report['source_reports']:
        assert sha(BATTLE / s['path']) == s['sha256']
    for directory in ('wailord-size-normal/captures',):
        path = BATTLE / directory / 'battle-review.json'
        report = read(path)
        assert report['complete']
        for row in report['entries']:
            if 'shots' not in row:
                continue
            normal[row['species']] = row
            sources[row['species']] = path.parent
        reports.append(path)
    shiny = {}
    for directory in ('shiny-final/captures', 'wailord-size-shiny/captures'):
        path = BATTLE / directory / 'battle-review.json'
        report = read(path)
        assert report['complete']
        for row in report['entries']:
            if 'shots' not in row:
                continue
            shiny[row['species']] = row
            sources[row['species']] = path.parent
        reports.append(path)
    proofs = {r['species']:r for r in read(BASE / 'final-pair-proof.json')['pairs']}
    stage = read(BASE / 'final-canonical-stage.json')
    assert len(stage) == 152 and len(normal) == len(shiny) == len(proofs) == 76
    rows, records, images = [], [], {}
    fixture = {'models':{}, 'profiles':{}}
    for source in stage:
        row = copy.deepcopy(source)
        species = row['species'].split('@')[0]
        variant = 'shiny' if row['species'].endswith('@shiny') else 'normal'
        identity = species + ('@shiny' if variant == 'shiny' else '')
        key = species + '-' + variant
        accepted_row = accepted[species]
        expected = accepted_row[variant + '_candidate']
        assert sha(Path(row['path'])) == row['glb_sha256'] == expected['glb_sha256']
        assert sha(Path(row['runtime_path'])) == row['runtime_sha256'] == expected['runtime_sha256'] == proofs[species][variant + '_runtime_sha256']
        check = normal[species] if variant == 'normal' else shiny[species + '-shiny']
        assert check['glb_sha256'] == row['glb_sha256']
        assert len(check['shots']) == 16 and all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in check['shots'])
        assert min(c['minimum_y'] for c in check['corrected_clearance_120hz'].values()) >= .015
        calibration = accepted_row['battle_calibration_candidate']
        assert calibration[variant + '_scene_sha256'] == row['runtime_sha256']
        motion = copy.deepcopy(calibration['motion'])
        assert motion['sha256'] == accepted_row['normal_candidate']['glb_sha256']
        motion['sha256'] = row['glb_sha256']
        assert abs(check['scale'] - motion['scale']) < 1e-8 and abs(check['candidate_lift'] - motion['lift']) < .001
        place = {k:motion[k] for k in ('scale','yaw_degrees')}
        bound_clips = normal[species]['clips']
        if species == 'dhelmise':
            assert dhelmise_envelope['runtime_sha256'] == accepted_row['normal_candidate']['runtime_sha256']
            assert abs(dhelmise_envelope['scale'] - motion['scale']) < 1e-8
            bound_clips = dhelmise_envelope['clips']
        bounds = {a:{'min':[x/motion['scale'] for x in c['envelope_min']], 'size':[x/motion['scale'] for x in c['envelope_size']]} for a,c in bound_clips.items()}
        fixture['models'][identity] = {'sha256':row['runtime_sha256'], 'glb_sha256':row['glb_sha256'], 'profile':key}
        fixture['profiles'][key] = {'action_timing':row['action_timing'], 'placement':place, 'grounding':dict(place,lift=motion['lift']), 'motion':motion, 'bounds':bounds}
        row.update(species=species, variant=variant, placement=place)
        rows.append(row)
        records.append({'species':species,'variant':variant,'appearance_approved':True,'battle_approved':True,'glb_sha256':row['glb_sha256'],'runtime_sha256':row['runtime_sha256']})
        capture_key = species if variant == 'normal' else species + '-shiny'
        for shot in check['shots']:
            path = sources[capture_key] / shot['image']
            images[str(path.relative_to(ROOT))] = sha(path)
    for species in accepted:
        normal_profile = copy.deepcopy(fixture['profiles'][species + '-normal'])
        shiny_profile = copy.deepcopy(fixture['profiles'][species + '-shiny'])
        normal_profile['motion'].pop('sha256'); shiny_profile['motion'].pop('sha256')
        assert normal_profile == shiny_profile
    assert len(images) == 2432
    WORK.mkdir(exist_ok=False)
    rows.sort(key=lambda r:(r['species'],r['variant']))
    write(WORK / 'runtime-catalog-final.json', rows)
    write(WORK / 'runtime-fixture.json', fixture)
    profiles_path = HERE / 'catalog_remaining_76_profiles.json'
    write(profiles_path, fixture)
    files = [BATTLE / 'dhelmise-final-envelope.json', checkpoint_path, profiles_path, Path(__file__), BASE / 'final-canonical-stage.json', BASE / 'final-pair-proof.json', BATTLE / 'normal-combined.json', WORK / 'runtime-catalog-final.json', WORK / 'runtime-fixture.json', BATTLE / 'review-v1/receipt.json', BATTLE / 'review-v1/media-sha256.json', BATTLE / 'wailord-size-review-v1/receipt.json'] + reports
    receipt = {'schema':1,'date':'2026-10-01','appearance_approved_pairs':76,'battle_visual_approval':True,'battle_approval_answer':'75 pairs approved; Wailord larger size approved separately','runtime_approved':False,'profiles_sha256':sha(profiles_path),'records':records,'evidence_sha256':{str(p.relative_to(ROOT)):sha(p) for p in files},'capture_sha256':images,'scope':'Actual120Hz normal clearance; exact actual SCN pair parity for shiny clearance;2432 final actual normal/shiny camera captures; appearance/sleep/battle approved; Wailord size override approved.'}
    write(HERE / 'catalog_remaining_76_battle_qualification.json', receipt)
    print('APPROVED76_INPUTS scenes=',len(rows),' captures=',len(images))

if __name__ == '__main__':
    main()
