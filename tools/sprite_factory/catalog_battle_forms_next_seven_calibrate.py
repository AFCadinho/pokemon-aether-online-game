"""Build review-only clearance profiles, independently checked by the battle renderer."""
import argparse
import json
import math
from pathlib import Path
from bake_motion_placement import bake


def calibrate(report, expected_pairs=7):
    if not report.get('complete'):
        raise ValueError('Complete battle measurements required')
    rows = [r for r in report['entries'] if 'clips' in r]
    if expected_pairs <= 0 or len(rows) != expected_pairs * 2:
        raise ValueError('Expected complete normal/shiny cohort required')
    scales = {}
    for row in rows:
        heights = [s['screen_rect'][3] for s in row['shots'] if s['action'] == 'idle']
        if len(heights) != 4 or not all(math.isfinite(h) and h > 0 for h in heights):
            raise ValueError('Four finite camera/side views required')
        scales[row['species']] = min(4., max(1., 66. / min(heights)))
    for row in rows:
        base = row['species'].removesuffix('-shiny')
        factor = max(scales[base], scales[base + '-shiny'])
        scales[base] = scales[base + '-shiny'] = factor
    result = dict(schema=1, runtime_approved=False,
                  catalog_sha256=report['catalog_sha256'], readability=scales,
                  motion={}, motion_holds={},
                  policy='Uniform scale applied analytically to measured vertex minima; validate independently at 120 Hz before admission')
    for row in rows:
        factor = scales[row['species']]
        data = dict(row, idle_verified=True, sha256=row['glb_sha256'],
                    scale=row['scale'] * factor,
                    candidate_lift=max(0, row.get('clearance_margin', .025) - row['clips']['idle']['minimum_y'] * factor),
                    clips={})
        for name, clip in row['clips'].items():
            data['clips'][name] = dict(clip,
                minimum_y_samples=[v * factor for v in clip['minimum_y_samples']])
        try:
            profile = bake({'review_schema': 1, 'errors': [],
                'entries': {row['species']: data}}, [])
            rest = data['clips']['sleep']
            lift = max(0., .03 - min(rest['minimum_y_samples']) - data['candidate_lift'])
            if lift > 0:
                profile[row['species']]['clips']['sleep'] = dict(duration=rest['duration'], intent='grounded_rest',
                    offsets=[round(lift, 7)] * len(rest['minimum_y_samples']))
            result['motion'].update(profile)
        except ValueError as error:
            result['motion_holds'][row['species']] = str(error)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pairs', type=int, default=7)
    parser.add_argument('report', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    data = calibrate(json.loads(args.report.read_text()), args.pairs)
    with args.output.open('x') as stream:
        json.dump(data, stream, indent=2, allow_nan=False)
        stream.write('\n')
    print('Profiles:', len(data['motion']), 'holds:', data['motion_holds'])
