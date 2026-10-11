#!/usr/bin/env python3
"""Group missing anatomical routes by form and attack family, without approval."""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--audit', required=True, type=Path)
    parser.add_argument('--output', type=Path,
                        default=Path('docs/3d/attack-attachment-family-backlog.json'))
    args = parser.parse_args()
    audit = json.loads(args.audit.read_text())
    if audit['errors']:
        raise ValueError('Resolve learnset audit errors before summarizing')
    for name, expected in audit['source_sha256'].items():
        if hashlib.sha256(Path(name).read_bytes()).hexdigest() != expected:
            raise ValueError(f'Stale learnset audit: {name}')
    profiles = json.loads(Path('data/battle_move_attachments_3d.json').read_text())['profiles']
    recipes = json.loads(Path('data/battle_move_recipes_3d.json').read_text())['moves']
    rows = {}
    for species, row in sorted(audit['species_forms'].items()):
        if not row['unconfigured_anatomical_parts']:
            continue
        missing = {}
        for part in row['unconfigured_anatomical_parts']:
            families = {}
            for move in row['moves_by_runtime_part'][part]:
                if row['move_routes'][move]['configured']:
                    continue
                family = recipes.get(move, {}).get('family', 'dedicated_presenter')
                group = families.setdefault(family, {'supported_move_count': 0,
                                                     'representative_move': move})
                group['supported_move_count'] += 1
            missing[part] = families
        profile = profiles.get(species, {})
        configured = set(profile.get('parts', {}))
        for action in profile.get('actions', {}).values():
            configured.update(action)
        rows[species] = {'missing_routes': missing, 'configured_parts': sorted(configured),
                         'runtime_sha256': row['runtime_sha256'],
                         'learnset_sha256': row['learnset_sha256'],
                         'status': 'individual_anatomy_or_routing_review_required'}
    report = {
        'schema': 1, 'complete': not rows, 'complete_visual_review': False,
        'scope': 'Missing configured anatomical routes grouped by form and family. '
                 'Existing points may need an alias; absent anatomy may need a deliberate '
                 'alternative. This is not a visual approval or a count of all unfinished effects.',
        'excluded_procedural_parts': ['body', 'orb_clearance'],
        'counts': {**audit['counts'], 'forms_with_missing_routes': len(rows)},
        'source_sha256': audit['source_sha256'],
        'learnset_audit_sha256': hashlib.sha256(args.audit.read_bytes()).hexdigest(),
        'species_forms': rows,
    }
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print(json.dumps(report['counts'], sort_keys=True))


if __name__ == '__main__':
    main()
