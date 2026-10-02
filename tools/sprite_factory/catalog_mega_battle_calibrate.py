"""Bake Mega battle placement proposals from complete native 60 Hz measurements.

Never grants runtime approval. Independent 120 Hz validation and user battle
review are required before admission. Steelix's accepted 0.7 scale is pinned.
"""
import argparse
import json
import math
from pathlib import Path

from bake_motion_placement import bake


def calibrate(report):
    rows = {r['species']: r for r in report['entries'] if 'clips' in r}
    if not report.get('complete') or len(rows) != 142:
        raise ValueError('Complete native measurements for 71 pairs required')
    names = sorted(n for n in rows if not n.endswith('-shiny'))
    result = dict(schema=1, runtime_approved=False, battle_approved=False,
        independent_motion_validation_pending=True, catalog_sha256=report['catalog_sha256'],
        readability={}, motion={}, motion_holds={},
        policy='Source geometry unchanged; readable scale plus source-clock floor correction. Proposal pending independent native validation.')
    for name in names:
        pair = [rows[name], rows[name + '-shiny']]
        idle = [s for r in pair for s in r['shots'] if s['action'] == 'idle']
        if len(idle) != 8:
            raise ValueError('Four camera/side views per variant required')
        heights = [s['screen_rect'][3] for s in idle]
        widths = [s['screen_rect'][2] for s in idle]
        if not all(math.isfinite(v) and v > 0 for v in heights + widths):
            raise ValueError('Invalid native screen measurements')
        all_shots = [s for r in pair for s in r['shots']]
        # Large source attacks can unfold above or beside an otherwise modest
        # idle body (e.g. Golurk). Retain room for those captured poses too.
        factor = min(1., 300. / max(heights), 430. / max(widths),
                     320. / max(s['screen_rect'][3] for s in all_shots),
                     560. / max(s['screen_rect'][2] for s in all_shots))
        factor = min(4., max(factor, 66. / min(heights)))
        if name == 'steelixmega':
            if any(abs(r['scale'] - .7) > 1e-6 for r in pair):
                raise ValueError('Accepted Steelix size changed')
            factor = 1.
        for r in pair:
            species = r['species']; result['readability'][species] = factor
            entry = dict(r, sha256=r['glb_sha256'], idle_verified=True,
                scale=r['scale'] * factor,
                candidate_lift=max(0, .025 - r['clips']['idle']['minimum_y'] * factor),
                clips={a: dict(c, minimum_y_samples=[v * factor for v in c['minimum_y_samples']])
                       for a, c in r['clips'].items()})
            try:
                # The accepted own-Mega rest poses have explicit resting intent.
                result['motion'].update(bake(dict(review_schema=1, errors=[],
                    entries={species: entry}), [species]))
            except ValueError as error:
                result['motion_holds'][species] = str(error)
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('report', type=Path); p.add_argument('output', type=Path)
    a = p.parse_args(); result = calibrate(json.loads(a.report.read_text()))
    with a.output.open('x') as f:
        json.dump(result, f, indent=2, allow_nan=False); f.write('\n')
    print('Placement proposals:', len(result['motion']), 'holds:', result['motion_holds'])
