"""Review-only 5B candidates. Never changes the runtime catalog or source assets."""
import argparse
import hashlib
import json
import math
from pathlib import Path

from bake_motion_placement import bake
from phase5_battle_summary import summarize

COHORT = {'pikachu', 'arcanine', 'lucario', 'snorlax', 'onix', 'articuno',
          'abra', 'gastly', 'dragonite', 'roaring-moon'}
HELD = {'gastly': ['Layered smoke/material semantics unresolved'],
        'abra': ['Physical attack, sleep and faint loop not identified'],
        'onix': ['Sleep and faint loop not identified']}
# Explicit resting review intent. Flying controls retain native sleep height.
GROUNDED_SLEEP = {'pikachu', 'arcanine', 'lucario', 'snorlax', 'dragonite'}
REQUIRED_ACTIONS = {'idle', 'physical_attack', 'special_attack', 'damage', 'sleep', 'faint_start', 'faint_loop'}


def validate(report):
    summarize(report)
    if {e['species'] for e in report['entries']} != COHORT:
        raise ValueError('Exact ten-model cohort required')


def prepare(report):
    validate(report)
    scales = {}
    for entry in report['entries']:
        if entry.get('status') == 'held':
            continue
        heights = [s['screen_rect'][3] for s in entry['shots'] if s['action'] == 'idle']
        if len(heights) != 4 or not all(math.isfinite(h) and h > 0 for h in heights):
            raise ValueError('Four finite idle views required')
        # One readability rule for the whole cohort, not per-species art direction.
        # Margin above 60 px accommodates perspective change after resizing.
        scales[entry['species']] = min(4.0, max(1.0, 66.0 / min(heights)))
    return {'schema': 1, 'runtime_approved': False, 'catalog_sha256': report['catalog_sha256'],
            'readability': scales, 'motion': {}, 'motion_holds': {}}


def bake_candidates(report, candidates):
    validate(report)
    if report['catalog_sha256'] != candidates['catalog_sha256']:
        raise ValueError('Catalog changed')
    result = dict(candidates, motion={}, motion_holds={})
    for entry in report['entries']:
        if entry.get('status') == 'held':
            continue
        species = entry['species']
        data = dict(entry, idle_verified=True, sha256=entry['glb_sha256'])
        try:
            profile = bake({'review_schema': 1, 'errors': [], 'entries': {species: data}},
                           [species] if species in GROUNDED_SLEEP else [])
            result['motion'].update(profile)
        except ValueError as error:
            result['motion_holds'][species] = str(error)
    return result


def close(report, candidates, candidate_hash):
    validate(report)
    if report.get('candidates_sha256') != candidate_hash or report['catalog_sha256'] != candidates['catalog_sha256']:
        raise ValueError('Candidate provenance mismatch')
    rows = []
    for entry in report['entries']:
        species = entry['species']
        reasons = list(HELD.get(species, []))
        metrics = {}
        if entry.get('status') != 'held':
            missing = REQUIRED_ACTIONS - set(entry['clips'])
            if missing:
                reasons.append('Missing canonical actions: ' + ', '.join(sorted(missing)))
            measured = entry.get('corrected_clearance_120hz', {})
            if set(measured) != set(entry['clips']):
                reasons.append('Independent full-clip clearance validation missing')
            for action, clip in measured.items():
                if clip['samples'] != math.ceil(entry['clips'][action]['duration'] * 120) + 1:
                    raise ValueError('Incomplete independent sampling')
                if not math.isfinite(clip['minimum_y']) or clip['minimum_y'] < -0.001:
                    reasons.append('Floor penetration: ' + action)
            if not entry.get('bounds_hud_proxy'):
                reasons.append('Bounds-based HUD not measured')
            shots = entry['shots']
            views = {(s['arena_camera'], s['side']) for s in shots if s['action'] == 'idle'}
            if views != {(arena, side) for arena in ('classic', 'stadium') for side in (0, 1)}:
                raise ValueError('Both sides of both cameras required')
            if any(not s['in_view'] or s['model_overlaps_hud_proxy'] for s in shots):
                reasons.append('Framing/HUD proxy conflict')
            if min(s['screen_rect'][3] for s in shots if s['action'] == 'idle') < 60:
                reasons.append('Idle model below readability threshold')
            metrics = {'glb_sha256': entry['glb_sha256'], 'candidate_scale': entry['scale'],
                       'candidate_lift': entry['candidate_lift'],
                       'minimum_idle_pixels': round(min(s['screen_rect'][3] for s in shots if s['action'] == 'idle'), 2),
                       'minimum_clearance': min((c['minimum_y'] for c in measured.values()), default=None),
                       'independent_pose_samples': sum(c['samples'] for c in measured.values()),
                       'reviewed_shots': len(shots), 'mapped_actions': sorted(entry['clips'])}
        if species in candidates['motion_holds']:
            reasons.append(candidates['motion_holds'][species])
        rows.append({'species': species, 'status': 'held' if reasons else 'eligible_for_5c_normal',
                     'reasons': reasons, 'runtime_approved': False, **metrics})
    return {'phase': '5B', 'review_complete': True, 'runtime_approved': False,
            'catalog_sha256': report['catalog_sha256'], 'candidates_sha256': candidate_hash,
            'scope': 'Normal review GLBs; flat floor, two default cameras, HUD proxy. Not battle certification.',
            'entries': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=['prepare', 'bake', 'close'])
    parser.add_argument('report', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--candidates', type=Path)
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    if args.stage == 'prepare':
        result = prepare(report)
    else:
        if not args.candidates:
            parser.error('--candidates required')
        candidates = json.loads(args.candidates.read_text())
        result = (bake_candidates(report, candidates) if args.stage == 'bake' else
                  close(report, candidates, hashlib.sha256(args.candidates.read_bytes()).hexdigest()))
    result['source_report_sha256'] = hashlib.sha256(args.report.read_bytes()).hexdigest()
    with args.output.open('x') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')


if __name__ == '__main__':
    main()
