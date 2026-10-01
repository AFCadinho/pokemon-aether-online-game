"""Bind the user's final review to 112 exact normal/shiny scenes and profiles."""
import copy
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASE = ROOT / '.tmp/remaining-final-batch-v1'
WORK = BASE / 'approved-final'


def read(p): return json.loads(Path(p).read_text())
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p, value): Path(p).write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False)+'\n')


def main():
    source = HERE / 'catalog_remaining_final_checkpoint.json'
    checkpoint = read(source)
    assert checkpoint['visual_approval'] and checkpoint['user_approval']['answer'] == 'Zien er allemaal goed uit'
    assert checkpoint['review_pairs'] == 112
    manifest = checkpoint['review_manifest']
    assert sha(manifest['path']) == manifest['sha256']
    files = {str(source.relative_to(ROOT)): sha(source), str(Path(manifest['path']).relative_to(ROOT)): manifest['sha256']}
    for proof in checkpoint['proofs']:
        assert sha(proof['path']) == proof['sha256'], proof['path']
        files[str(Path(proof['path']).relative_to(ROOT))] = proof['sha256']
    motion = read(BASE / 'motion-final-normal-v7.json')
    motion.update(read(BASE / 'battle-fire-final-v3/candidates.json')['motion'])
    fixture = {'models': {}, 'profiles': {}}
    rows, records, images = [], [], {}
    registry = read(ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json')
    assert len(registry['profiles']) == 899 and len(registry['models']) == 1798
    for entry in checkpoint['entries']:
        name = entry['species']
        assert name not in registry['profiles']
        pair_profiles = []
        for variant in ['normal', 'shiny']:
            raw = entry['variants'][variant]
            assert sha(raw['runtime_path']) == raw['runtime_sha256']
            assert sha(raw['path']) == raw['glb_sha256']
            for report_key in ['appearance_report', 'eye_closeup_report']:
                assert sha(raw[report_key]) == raw[report_key+'_sha256']
                files[str(Path(raw[report_key]).relative_to(ROOT))] = raw[report_key+'_sha256']
            root = Path(raw['battle_evidence_root'])
            report = root / 'battle-review.json'
            battle = read(report)
            assert battle['complete']
            files[str(report.relative_to(ROOT))] = sha(report)
            measured = next(r for r in battle['entries'] if r['species'] == name+('-shiny' if variant == 'shiny' else ''))
            assert measured['bounds_hud_proxy'] and len(measured['shots']) == 16
            assert all(s['in_view'] and not s.get('hud_proxy_overlap', False) for s in measured['shots'])
            assert min(r['minimum_y'] for r in measured['corrected_clearance_120hz'].values()) >= .025-1e-5
            for shot in measured['shots']:
                p = root / shot['image']; images[str(p.relative_to(ROOT))] = sha(p)
            profile = copy.deepcopy(motion[name])
            assert abs(profile['scale']-measured['scale']) < 1e-8
            assert abs(profile['lift']-measured['candidate_lift']) < .001
            profile['sha256'] = raw['runtime_sha256']
            if not profile['clips']:
                # Fully airborne models need no additional lift. Persist explicit
                # zero correction curves from their measured clip clocks so the
                # runtime recognizes their completed calibration as well.
                for action, clip in measured['clips'].items():
                    if action == 'idle':
                        continue
                    seconds = float(clip['duration'])
                    profile['clips'][action] = {
                        'duration': seconds,
                        'intent': 'grounded_rest' if action == 'sleep' else 'clearance_only',
                        'offsets': [0.0] * (math.ceil(seconds*60.0)+1)}
            place = {k: profile[k] for k in ['scale', 'yaw_degrees']}
            bounds = {a: {'min': [x/profile['scale'] for x in r['envelope_min']],
                          'size': [x/profile['scale'] for x in r['envelope_size']]}
                      for a, r in measured['clips'].items()}
            if variant == 'shiny':
                # Exact pair geometry parity is pinned above; use the normal
                # bounds to avoid JSON writer rounding differences.
                bounds = copy.deepcopy(fixture['profiles'][name+'-normal']['bounds'])
            key = name+'-'+variant
            identity = name+('@shiny' if variant == 'shiny' else '')
            fixture['models'][identity] = {'sha256': raw['runtime_sha256'], 'glb_sha256': raw['glb_sha256'], 'profile': key}
            fixture['profiles'][key] = {'action_timing': raw['action_timing'], 'placement': place,
                                       'grounding': dict(place, lift=profile['lift']), 'motion': profile, 'bounds': bounds}
            comparable = copy.deepcopy(fixture['profiles'][key]); comparable['motion'].pop('sha256')
            pair_profiles.append(comparable)
            rows.append(dict(raw, species=name, variant=variant, runtime_schema=1, placement=place))
            records.append({'species': name, 'variant': variant, 'glb_sha256': raw['glb_sha256'],
                            'runtime_sha256': raw['runtime_sha256'], 'appearance_approved': True, 'battle_approved': True})
        assert pair_profiles[0] == pair_profiles[1], name
    assert len(rows) == 224 and len(images) == 3584
    if WORK.exists():
        assert read(WORK/'runtime-catalog-final.json') == rows, 'Cannot replace reviewed scenes'
    else:
        WORK.mkdir()
    write(WORK / 'runtime-catalog-final.json', rows)
    write(WORK / 'runtime-fixture.json', fixture)
    profiles = HERE / 'catalog_remaining_final_profiles.json'; write(profiles, fixture)
    for p in [Path(__file__), profiles, WORK/'runtime-catalog-final.json', WORK/'runtime-fixture.json']:
        files[str(p.relative_to(ROOT))] = sha(p)
    write(HERE / 'catalog_remaining_final_battle_qualification.json', {
        'schema': 1, 'date': '2026-10-01', 'runtime_approved': False,
        'appearance_approved_pairs': 112, 'battle_visual_approval': True,
        'battle_approval_answer': checkpoint['user_approval']['answer'], 'profiles_sha256': sha(profiles),
        'records': records, 'evidence_sha256': files, 'capture_sha256': images,
        'scope': '224 exact user-approved scenes; normal 60/120Hz measurements with exact geometry parity for shiny/material revisions; 3584 current camera captures; installation/performance pending'})
    print('FINAL_APPROVED_INPUTS pairs=112 scenes=224 captures=3584')


if __name__ == '__main__': main()
