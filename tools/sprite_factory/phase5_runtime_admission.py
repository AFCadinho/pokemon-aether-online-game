"""Emit reviewed runtime metadata or a local catalog from the exact qualified 5C set.

Does not copy scenes, change Settings, or publish/download assets. Outputs JSON
to stdout so the registry can be reviewed before it is committed.
"""
import argparse
import hashlib
import json
from pathlib import Path


def build(catalog_path, qualification_path):
    source = Path(catalog_path)
    qualification = json.loads(Path(qualification_path).read_text())
    if not qualification.get('phase5c_complete'):
        raise ValueError('Phase 5C is incomplete')
    if hashlib.sha256(source.read_bytes()).hexdigest() != qualification['evidence_sha256']['catalog']:
        raise ValueError('Catalog is not the qualified artifact')
    entries = json.loads(source.read_text())
    grounding = json.loads(Path(str(source) + '.grounding.json').read_text())['entries']
    eligible = set(qualification['qualified_candidate_species'])
    expected = eligible | {s + '@shiny' for s in eligible}
    if len(entries) != len(expected) or {e['species'] for e in entries} != expected:
        raise ValueError('Incomplete/duplicate normal-shiny cohort')
    registry = {'schema': 1, 'qualification_sha256': hashlib.sha256(Path(qualification_path).read_bytes()).hexdigest(),
                'models': {}, 'profiles': {}}
    catalog = []
    for entry in entries:
        key = entry['species']
        species = key.removesuffix('@shiny')
        digest = hashlib.sha256(Path(entry['runtime_path']).read_bytes()).hexdigest()
        if digest != entry['runtime_sha256'] or digest != grounding[key]['sha256'] or digest != entry['_review_motion']['sha256']:
            raise ValueError('Stale scene/grounding/motion: ' + key)
        motion = {k: v for k, v in entry['_review_motion'].items() if k != 'sha256'}
        calibration = {k: v for k, v in grounding[key].items() if k != 'sha256'}
        profile = {'placement': entry['placement'], 'grounding': calibration,
                   'motion': motion, 'bounds': entry['_review_bounds'], 'action_timing': entry['action_timing']}
        if species in registry['profiles'] and registry['profiles'][species] != profile:
            raise ValueError('Variants do not share reviewed placement/motion: ' + species)
        registry['profiles'][species] = profile
        registry['models'][key] = {'sha256': digest, 'profile': species, 'glb_sha256': entry['glb_sha256']}
        catalog.append({'species': species, 'variant': 'shiny' if key.endswith('@shiny') else 'normal',
                        'runtime_path': entry['runtime_path'], 'runtime_sha256': digest, 'runtime_schema': 1,
                        'placement': entry['placement'], 'action_timing': entry['action_timing']})
    return registry, catalog


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog', type=Path)
    parser.add_argument('--qualification', type=Path,
                        default=Path(__file__).parents[2] / 'docs/phase5c-qualification.json')
    parser.add_argument('--catalog-only', action='store_true')
    args = parser.parse_args()
    registry, catalog = build(args.catalog, args.qualification)
    print(json.dumps(catalog if args.catalog_only else registry, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
