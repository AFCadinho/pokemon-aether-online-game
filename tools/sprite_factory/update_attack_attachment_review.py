#!/usr/bin/env python3
"""Refresh durable per-form review progress without approving candidates.

Decision files are applied in argument order (later overrides earlier). Only
profiles already in the runtime data count as installed mouth calibrations.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inspection', required=True, type=Path)
    parser.add_argument('--decisions', action='append', default=[], type=Path)
    parser.add_argument('--part-decisions', action='append', default=[], type=Path)
    parser.add_argument('--profiles', type=Path, default=Path('data/battle_move_attachments_3d.json'))
    parser.add_argument('--pose-visibility-audit', type=Path, default=Path('docs/3d/attack-attachment-pose-visibility.json'))
    parser.add_argument('--output', type=Path, default=Path('docs/3d/attack-attachment-review.json'))
    args = parser.parse_args()
    decisions = {}
    for path in args.decisions:
        decisions.update(json.loads(path.read_text()))
    part_decisions = {}
    part_review_notes = {}
    for path in args.part_decisions:
        for species, decision in json.loads(path.read_text()).items():
            part_decisions.setdefault(species, {}).update(decision.get('parts', {}))
            part_review_notes.setdefault(species, []).append(decision)
    profiles = json.loads(args.profiles.read_text())['profiles']
    visibility = json.loads(args.pose_visibility_audit.read_text()).get('models', {}) if args.pose_visibility_audit.exists() else {}
    visibility_digest = hashlib.sha256(args.pose_visibility_audit.read_bytes()).hexdigest() if visibility else ''

    def requires_visibility_review(review):
        if review.get('pose_sampling') == 'forward_from_start_v1':
            return False
        audit = review.get('visibility_audit', {})
        return not (audit.get('result') == 'differences_outside_attachment' and audit.get('audit_sha256') == visibility_digest)
    rows = {}
    for path in sorted(args.inspection.glob('*.json')):
        model = json.loads(path.read_text())
        if 'identity' not in model or model['identity'].endswith('@shiny'):
            continue
        species = model['identity']
        decision = decisions.get(species, {})
        if isinstance(decision, str):
            decision = {'status': decision}
        status = decision.get('status', 'pending_mouth_proposal_or_anatomical_route')
        row = {'normal_runtime_sha256': model['runtime_sha256'], 'native_actions': sorted(model['actions']),
               'mouth_status': status, 'other_parts_status': 'pending_visual_and_move_routing_review',
               'move_effect_review': 'pending'}
        if decision:
            row['latest_candidate_review'] = decision
        profile = profiles.get(species, {})
        if profile.get('move_effect_reviews'):
            row['move_effect_reviews'] = profile['move_effect_reviews']
            row['move_effect_review'] = 'partially_reviewed'
        row['part_status'] = part_decisions.get(species, {}).copy()
        if species in part_review_notes:
            row['part_candidate_reviews'] = part_review_notes[species]
        if profile.get('part_reviews'):
            row['part_reviews'] = profile['part_reviews']
            for part in profile['part_reviews']:
                row['part_status'][part] = 'sampled_marker_pose_review_pass_installed'
        row['anatomical_move_routing_review'] = 'pending'
        if profile.get('family_attachment_review'):
            row['family_attachment_review'] = profile['family_attachment_review']
            row['family_attachments'] = profile.get('family_attachments', {})
            row['attachment_overrides'] = profile.get('attachment_overrides', {})
            row['family_actions'] = profile.get('family_actions', {})
            row['family_choreography'] = profile.get('family_choreography', {})
        if profile.get('anatomical_route_reviews'):
            row['anatomical_move_routing_review'] = 'partially_reviewed'
            row['anatomical_route_reviews'] = profile['anatomical_route_reviews']
        if profile.get('parts', {}).get('mouth'):
            row['mouth_status'] = 'sampled_mouth_pose_review_pass'
            row['mouth_review'] = profile['review']
        elif status == 'mouth_pose_review_pass':
            row['mouth_status'] = 'candidate_review_pass_not_installed'
        changes = visibility.get(species, {}).get('differences', [])
        if changes:
            row['previous_pose_visibility_differences'] = changes
            if profile.get('parts', {}).get('mouth') and requires_visibility_review(profile.get('review', {})):
                row['mouth_status'] = 'installed_pending_forward_visibility_review'
            for part, review in profile.get('part_reviews', {}).items():
                if requires_visibility_review(review):
                    row['part_status'][part] = 'installed_pending_forward_visibility_review'
        rows[species] = row
    report = {'schema': 2, 'complete': False,
              'scope': 'Per-form review progress; sampled anatomical markers do not certify all attack effects.',
              'profile_sha256': hashlib.sha256(args.profiles.read_bytes()).hexdigest(),
              'counts': {'species_forms': len(rows), 'runtime_profiles': len(profiles),
                         'part_status': dict(sorted(Counter(v for r in rows.values() for v in r['part_status'].values()).items())),
                         'mouth_status': dict(sorted(Counter(r['mouth_status'] for r in rows.values()).items()))},
              'species_forms': rows}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True)+'\n')
    print(json.dumps(report['counts'], sort_keys=True))


if __name__ == '__main__':
    main()
