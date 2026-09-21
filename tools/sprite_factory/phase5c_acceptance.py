"""Close the offline 5C candidate qualification; never authorize runtime release."""
import argparse
import hashlib
import json
from pathlib import Path

COHORT = {'pikachu', 'arcanine', 'lucario', 'snorlax', 'articuno', 'dragonite', 'roaring-moon'}


def qualify(stress, review, parity, log):
    if 'SCRIPT ERROR' in log or 'ERROR:' in log or 'PHASE5_BATTLE_STRESS_OK' not in log:
        raise ValueError('Runtime did not finish cleanly')
    if not stress.get('complete') or len(stress.get('rounds', [])) != 3:
        raise ValueError('Three complete battles required')
    if stress.get('screenshots_enabled', True):
        raise ValueError('Use a separate no-readback performance run, not the screenshot review run')
    if {e['species'] for e in review['entries']} != COHORT or len(review['entries']) != 7:
        raise ValueError('Incomplete shiny review cohort')
    for entry in review['entries']:
        if entry.get('errors') or entry.get('missing_actions') or len(entry.get('poses', [])) != 5:
            raise ValueError('Variant review has errors or missing poses')
    if {e['species'] for e in parity} != COHORT or len(parity) != 7:
        raise ValueError('Incomplete variant parity proof')
    for entry in parity:
        for key in ('normal_glb_sha256', 'shiny_glb_sha256', 'geometry_motion_sha256'):
            if len(entry.get(key, '')) != 64:
                raise ValueError('Missing parity hash')
    summaries = []
    for row in stress['rounds']:
        if (len(row['switch_ms']) != 12 or row['duplicate_checks'] != 7
                or row['faint_replacements'] != 7 or row.get('variant_checks') != 7
                or not row['replay_duplicate_faint_replacement']):
            raise ValueError('Incomplete lifecycle matrix')
        dispatch = max((s['ms'] for s in row['load_spans']
                        if s['operation'] == 'threaded load dispatch/collect'), default=0)
        if not 0 < row['frame_p95_ms'] <= 20 or dispatch > 1000 / 60:
            raise ValueError('Candidate performance regression: p95 >20ms or load callback >one 60Hz frame')
        if row['retained_source_bytes'] > 64 * 1024 * 1024:
            raise ValueError('Source cache budget exceeded')
        if any(s['ms'] > 100 and not s.get('covered', False) and s['context'] != 'replay setup'
               for s in row['stalls_over_50ms']):
            raise ValueError('Severe uncovered gameplay hitch; investigate before closing')
        summaries.append({key: row[key] for key in ('arena', 'frame_p95_ms', 'frame_max_ms',
            'replay_setup_ms', 'stalls_over_50ms', 'static_bytes', 'retained_source_bytes')} |
            {'load_callback_max_ms': dispatch})
    growth = stress['rounds'][2]['static_bytes'] - stress['rounds'][1]['static_bytes']
    if growth >= 1024 * 1024:
        raise ValueError('Repeated battle retention regression')
    return {'schema': 1, 'phase5c_complete': True, 'runtime_approved': False,
        'scope': 'Offline real battle UI/presenter and recorded events, seven normal/shiny pairs; no live PvP certification',
        'qualified_candidate_species': sorted(COHORT), 'held_species': ['abra', 'gastly', 'onix'],
        'checks': {'battles': 3, 'mixed_team_switches': 36, 'normal_duplicate_faint_replacements': 21,
                   'variant_swap_faint_eviction_reload_checks': 21, 'recorded_event_sequences': 3,
                   'shiny_review_images': 35, 'exact_geometry_motion_pairs': 7},
        'performance_scope': 'Separate no-readback run: p95 <=20ms, main-thread load callbacks <=one 60Hz frame, no uncovered gameplay interval >100ms. Covered entry and explicitly measured replay construction retained separately; not a no-hitch or total RAM/VRAM guarantee',
        'final_two_round_static_growth_bytes': growth, 'rounds': summaries,
        'parity': parity, 'next': '5D: separately select and enable approved candidate variants; unresolved 5B holds stay disabled'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('stress', 'review', 'parity', 'log', 'catalog'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    stress = json.loads(args.stress.read_text())
    if stress['catalog_sha256'] != hashlib.sha256(args.catalog.read_bytes()).hexdigest():
        raise ValueError('Stale runtime catalog')
    result = qualify(stress, json.loads(args.review.read_text()), json.loads(args.parity.read_text()), args.log.read_text())
    result['evidence_sha256'] = {name: hashlib.sha256(getattr(args, name).read_bytes()).hexdigest()
                               for name in ('stress', 'review', 'parity', 'log', 'catalog')}
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
