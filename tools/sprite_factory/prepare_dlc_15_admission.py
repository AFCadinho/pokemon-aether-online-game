"""Bind the approved DLC review to exact standalone scenes and runtime profiles."""
import copy
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASE = ROOT / '.tmp/remaining-dlc-15-v1'
WORK = BASE / 'approved-final'


def read(path): return json.loads(Path(path).read_text())
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def write(path, value): Path(path).write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False)+'\n')


def main():
    checkpoint_path = HERE / 'catalog_remaining_dlc_battle_checkpoint.json'
    checkpoint = read(checkpoint_path)
    assert checkpoint['user_sleep_battle_approved'] and checkpoint['shiny_followup_approved']
    assert not checkpoint['pending_shiny_followup'] and not checkpoint['battle_failures']
    files = {str(checkpoint_path.relative_to(ROOT)): sha(checkpoint_path)}
    for relative, digest in checkpoint['evidence_sha256'].items():
        assert sha(ROOT / relative) == digest, relative
        files[relative] = digest
    candidates_path = HERE / 'catalog_remaining_dlc_battle_candidates.json'
    assert sha(candidates_path) == checkpoint['candidates_sha256']
    files[str(candidates_path.relative_to(ROOT))] = sha(candidates_path)
    motion = read(candidates_path)['motion']
    measured = {r['species']: r for r in read(BASE / 'battle-flat-v4/status.json')['entries']}
    runtime = {r['species']: r for r in read(BASE / 'runtime-flat-v2/report.json')}
    runtime_original = copy.deepcopy(runtime)
    runtime.update({r['species']: r for r in read(BASE / 'runtime-pot-v1/report.json')})
    accepted = {(r['species'].removesuffix('-shiny'), r['variant']): r for r in checkpoint['records']}
    names = sorted({r['species'].removesuffix('-shiny') for r in checkpoint['records']})
    assert len(names) == 15 and len(accepted) == 30
    fixture = {'models': {}, 'profiles': {}}
    rows, records, images = [], [], {}
    for name in names:
        pair_profiles = []
        for variant in ('normal', 'shiny'):
            key = name + ('-shiny' if variant == 'shiny' else '')
            raw, approval, battle = runtime[key], accepted[name, variant], measured[key]
            assert approval['user_battle_approved']
            assert sha(raw['path']) == raw['glb_sha256'] == approval['glb_sha256']
            assert sha(raw['runtime_path']) == raw['runtime_sha256'] == approval['runtime_sha256']
            assert Path(raw['runtime_path']) == ROOT / approval['runtime_scene']
            assert raw['complete_pose_channels'] and raw['runtime_schema'] == 1
            if battle['glb_sha256'] != raw['glb_sha256']:
                assert approval['previous_glb_sha256'] == battle['glb_sha256'] == sha(runtime_original[key]['path'])
                receipt = read(ROOT / approval['material_revision_receipt'])
                from phase5_variant_parity import compare
                assert compare(Path(runtime_original[key]['path']), Path(raw['path'])) == receipt['geometry_motion_signature'] == approval['material_revision_geometry_motion_signature']
            assert battle['bounds_hud_proxy'] and len(battle['shots']) == 16
            assert all(s['in_view'] and not s.get('model_overlaps_hud_proxy', False) for s in battle['shots'])
            assert min(r['minimum_y'] for r in battle['corrected_clearance_120hz'].values()) >= .025-1e-5
            for shot in battle['shots']:
                image = Path(battle['evidence_root']) / shot['image']
                images[str(image.relative_to(ROOT))] = sha(image)
            profile = copy.deepcopy(motion[key])
            assert profile['sha256'] == raw['glb_sha256']
            assert abs(profile['scale'] - battle['scale']) < 1e-8
            assert abs(profile['lift'] - battle['candidate_lift']) < .001
            profile['sha256'] = raw['runtime_sha256']
            if not profile['clips']:
                for action, clip in battle['clips'].items():
                    if action == 'idle': continue
                    duration = float(clip['duration'])
                    profile['clips'][action] = {'duration': duration,
                        'intent': 'grounded_rest' if action == 'sleep' else 'clearance_only',
                        'offsets': [0.0] * (math.ceil(duration*60)+1)}
            place = {k: profile[k] for k in ('scale', 'yaw_degrees')}
            bounds = {a: {'min': [x/profile['scale'] for x in r['envelope_min']],
                          'size': [x/profile['scale'] for x in r['envelope_size']]}
                      for a, r in battle['clips'].items()}
            if variant == 'shiny': bounds = copy.deepcopy(fixture['profiles'][name+'-normal']['bounds'])
            profile_key = name + '-' + variant
            identity = name + ('@shiny' if variant == 'shiny' else '')
            fixture['models'][identity] = {'sha256': raw['runtime_sha256'], 'glb_sha256': raw['glb_sha256'], 'profile': profile_key}
            fixture['profiles'][profile_key] = {'action_timing': raw['action_timing'], 'placement': place,
                'grounding': dict(place, lift=profile['lift']), 'motion': profile, 'bounds': bounds}
            comparable = copy.deepcopy(fixture['profiles'][profile_key]); comparable['motion'].pop('sha256')
            pair_profiles.append(comparable)
            rows.append(dict(raw, species=name, variant=variant, placement=place))
            records.append({'species': name, 'variant': variant, 'runtime_sha256': raw['runtime_sha256'],
                'glb_sha256': raw['glb_sha256'], 'appearance_approved': True, 'battle_approved': True})
        assert pair_profiles[0] == pair_profiles[1], name
    assert len(images) == 480
    WORK.mkdir(exist_ok=True)
    if (WORK/'runtime-catalog-final.json').exists():
        assert read(WORK/'runtime-catalog-final.json') == rows, 'Cannot replace approved scenes'
    write(WORK/'runtime-catalog-final.json', rows)
    write(WORK/'runtime-fixture.json', fixture)
    profiles_path = HERE / 'catalog_remaining_dlc_profiles.json'
    write(profiles_path, fixture)
    for p in (Path(__file__), profiles_path, WORK/'runtime-catalog-final.json', WORK/'runtime-fixture.json'):
        files[str(p.relative_to(ROOT))] = sha(p)
    write(HERE/'catalog_remaining_dlc_battle_qualification.json', {
        'schema': 1, 'date': '2026-10-01', 'runtime_approved': False,
        'appearance_approved': True, 'battle_approved': True, 'profiles_sha256': sha(profiles_path),
        'records': records, 'evidence_sha256': files, 'capture_sha256': images,
        'scope': '30 approved scenes; 60/120Hz measurements reused for four exact geometry/motion material revisions; installed loading/performance pending'})
    print('DLC_APPROVED_INPUTS pairs=15 scenes=30 captures=480')


if __name__ == '__main__': main()
