"""Review-only Galar bird scale, grounding and flight-height proposals."""
import argparse
import json
from pathlib import Path

from bake_motion_placement import bake
from catalog_mega_battle_calibrate import calibrate


def propose(report):
    result = calibrate(report, expected_pairs=3)
    expected = {name + suffix for name in ('articuno-galar', 'zapdos-galar', 'moltres-galar')
                for suffix in ('', '-shiny')}
    rows = {r['species']: r for r in report['entries'] if 'clips' in r}
    if set(rows) != expected:
        raise ValueError('Expected exactly the three Galar bird pairs')
    result['hover'] = {name: 0.0 if name.startswith('zapdos-') else 0.45 for name in rows}
    for name in ('moltres-galar', 'moltres-galar-shiny'):
        # Full-size physical attack 2 overlapped the classic-camera HUD proxy.
        # Keep the flight height, and leave room for the extended flame wings.
        row = rows[name]
        factor = 0.9
        result['readability'][name] = factor
        entry = dict(row, idle_verified=True, sha256=row['glb_sha256'],
                     scale=row['scale'] * factor,
                     candidate_lift=max(0.0, 0.025 - row['clips']['idle']['minimum_y'] * factor),
                     clips={a: dict(c, minimum_y_samples=[v * factor for v in c['minimum_y_samples']])
                            for a, c in row['clips'].items()})
        result['motion'].update(bake(dict(review_schema=1, errors=[], entries={name: entry}), [name]))
    result['policy'] = 'Galar review proposal; independent native 120 Hz clearance and user battle approval required'
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    result = propose(json.loads(args.report.read_text()))
    with args.output.open('x') as stream:
        json.dump(result, stream, indent=2, allow_nan=False)
        stream.write('\n')
