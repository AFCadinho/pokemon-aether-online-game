#!/usr/bin/env python3
"""Add unapproved limb proposals from each model's measured bind geometry.

This does not install profiles. Native effect bones are preserved; geometry
centers (including finger/toe children) require individual pose review.
"""
import argparse
import json
from pathlib import Path


def propose(report):
    parts = report.setdefault('candidate_parts', {})
    reasons = report.setdefault('candidate_reasons', {})
    geometry = report['geometry']
    for part, bones in {
        'hand': ['right_hand', 'right_hand_sub', 'right_palm'],
        'left_hand': ['left_hand', 'left_hand_sub', 'left_palm'],
        'foot': ['right_toe', 'right_foot_index', 'right_foot_middle', 'right_foot'],
        'left_foot': ['left_toe', 'left_foot_index', 'left_foot_middle', 'left_foot'],
    }.items():
        if reasons.get(part) == 'native_effect_bone':
            continue
        for bone in bones:
            if bone not in geometry:
                continue
            box = geometry[bone]
            parts[part] = [[{'bone': bone, 'offset': [(a+b)/2 for a, b in zip(box['min'], box['max'])], 'weight': 1}]]
            reasons[part] = 'limb_surface_center_requires_review'
            break
    report['review_status'] = 'unreviewed'
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve():
        raise ValueError('Write proposals to a new directory to preserve prior review inputs')
    args.output.mkdir(parents=True, exist_ok=True)
    count = 0
    for path in sorted(args.input.glob('*.json')):
        report = json.loads(path.read_text())
        if 'identity' not in report:
            continue
        (args.output/path.name).write_text(json.dumps(propose(report), indent=2, sort_keys=True)+'\n')
        count += 1
    print(f'UNREVIEWED_LIMB_PROPOSALS models={count}')


if __name__ == '__main__':
    main()
