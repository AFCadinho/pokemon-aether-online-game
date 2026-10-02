"""Refine review-only motion profiles from finer native-scene measurements."""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path


def refine(report_path, candidates_path, output):
    report = json.loads(report_path.read_text())
    candidates = json.loads(candidates_path.read_text())
    assert report['complete'] and not candidates['runtime_approved']
    assert report['catalog_sha256'] == candidates['catalog_sha256']
    assert report['candidates_sha256'] == hashlib.sha256(candidates_path.read_bytes()).hexdigest()
    rows = {r['species']: r for r in report['entries'] if 'clips' in r}
    assert len(rows) == 8 and set(rows) == set(candidates['motion'])
    result = copy.deepcopy(candidates)
    changes = {}
    for species, row in rows.items():
        profile = result['motion'][species]
        assert row['glb_sha256'] == profile['sha256']
        changes[species] = {}
        for action, measured in row['corrected_clearance_120hz'].items():
            duration = row['clips'][action]['duration']
            minima = measured['minimum_y_samples']
            assert len(minima) == math.ceil(duration * 120) + 1
            assert all(math.isfinite(v) for v in minima)
            # Idle placement remains source-bound. Only existing motion curves
            # may be refined; no geometry, native timing or admission changes.
            if action not in profile['clips']:
                assert min(minima) >= .024
                continue
            clip = profile['clips'][action]
            old = list(clip['offsets'])
            additions = [0.] * len(old)
            for i, value in enumerate(minima):
                deficit = max(0., .0301 - value)
                if deficit <= .0002:
                    continue
                frame = min(i / 120, duration) * 60
                left = min(math.floor(frame), len(old) - 2)
                # Add the whole deficit at both bracketing 60 Hz keys so linear
                # interpolation covers the observed half-frame dip.
                for key in (left, left + 1):
                    additions[key] = max(additions[key], deficit)
            if any(additions):
                if action in ('sleep', 'faint_loop'):
                    additions = [max(additions)] * len(old)
                clip['offsets'] = [round(a + b, 7) for a, b in zip(old, additions)]
                changes[species][action] = max(additions)
    # The two variants have identical geometry and motion. Keep placement
    # identical even when fine measurement introduces float differences.
    for species in rows:
        if species.endswith('-shiny'):
            continue
        a = result['motion'][species]['clips']
        b = result['motion'][species + '-shiny']['clips']
        assert a.keys() == b.keys()
        for action in a:
            assert len(a[action]['offsets']) == len(b[action]['offsets'])
            shared = [max(x, y) for x, y in zip(a[action]['offsets'], b[action]['offsets'])]
            a[action]['offsets'] = shared
            b[action]['offsets'] = list(shared)
        for clips in (a, b):
            if 'faint_start' in clips and 'faint_loop' in clips:
                assert abs(clips['faint_start']['offsets'][-1] - clips['faint_loop']['offsets'][0]) <= .0002
    result['refinement'] = dict(measurement_sha256=hashlib.sha256(report_path.read_bytes()).hexdigest(),
        previous_candidates_sha256=hashlib.sha256(candidates_path.read_bytes()).hexdigest(),
        target_clearance=.0301, changes=changes,
        independent_revalidation_required=True)
    with output.open('x') as stream:
        json.dump(result, stream, indent=2, allow_nan=False)
        stream.write('\n')
    print(json.dumps(changes, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('candidates', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    refine(args.report, args.candidates, args.output)
