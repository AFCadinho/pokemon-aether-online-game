"""Refine placement from observed 120 Hz deficits, then require fresh sampling.

Retains all failed evidence. Changes are local vertical envelopes only; the
qualifier, source animation clocks and models are unchanged.
"""
import copy
import json
import math
from pathlib import Path
from catalog_galar_birds_candidates import sha

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.tmp/regional-production-v1'


def refine(reports, original, output):
    proposal = json.loads(original.read_text())
    before = copy.deepcopy(proposal)
    changed = {}
    sources = []
    seen = set()
    for path in reports:
        report = json.loads(path.read_text())
        assert report['complete']
        assert report['catalog_sha256'] == proposal['catalog_sha256']
        sources.append({'path': str(path), 'sha256': sha(path)})
        for row in report['entries']:
            if 'clips' not in row:
                continue
            name = row['species']
            assert name not in seen
            seen.add(name)
            for action, measured in row['corrected_clearance_120hz'].items():
                if measured['minimum_y'] >= .024:
                    continue
                minima = measured['minimum_y_samples']
                duration = row['clips'][action]['duration']
                assert len(minima) == math.ceil(duration * 120) + 1
                assert all(math.isfinite(v) for v in minima)
                assert .030 - min(minima) <= .25, (name, action, min(minima))
                changed.setdefault(name, []).append({'action': action, 'old_minimum_y': min(minima)})
                if action == 'idle':
                    # Tiny independent sub-frame differences for hovering actors.
                    assert .030 - min(minima) < .01
                    proposal['hover'][name] += .030 - min(minima) + .001
                    continue
                clip = proposal['motion'][name]['clips'][action]
                offsets = clip['offsets']
                bump = [0.] * len(offsets)
                for i, value in enumerate(minima):
                    deficit = max(0., .030 - value)
                    if not deficit:
                        continue
                    frame = min(i / 2., duration * 60)
                    lo = math.floor(frame)
                    # Full deficit at both interpolation nodes, smooth support
                    # over neighbouring frames. No delayed upward correction.
                    for j in range(max(0, lo - 6), min(len(bump), lo + 8)):
                        distance = max(0., abs(j - frame) - 1.)
                        weight = max(0., 1. - distance / 6.)
                        bump[j] = max(bump[j], deficit * weight)
                if action in ('sleep', 'faint_loop'):
                    bump = [max(bump)] * len(bump)
                clip['offsets'] = [round(a + b, 7) for a, b in zip(offsets, bump)]
            clips = proposal['motion'][name]['clips']
            if name in changed and 'faint_start' in clips and 'faint_loop' in clips:
                start, loop = clips['faint_start']['offsets'], clips['faint_loop']['offsets']
                end = max(start[-1], loop[0])
                delta = end - start[-1]
                for j in range(max(0, len(start) - 13), len(start)):
                    t = (j - max(0, len(start) - 13)) / min(12, len(start) - 1)
                    start[j] = round(start[j] + delta * t * t * (3 - 2 * t), 7)
                clips['faint_loop']['offsets'] = [end] * len(loop)
    assert seen == set(proposal['motion'])
    output.mkdir(exist_ok=False)
    (output / 'placement.json').write_text(json.dumps(proposal, indent=2) + '\n')
    evidence = {'runtime_approved': False, 'independent_remeasurement_required': sorted(changed),
                'input_placement': str(original), 'input_sha256': sha(original), 'reports': sources,
                'changes': changed, 'output_sha256': sha(output / 'placement.json')}
    (output / 'receipt.json').write_text(json.dumps(evidence, indent=2) + '\n')
    for name in seen - set(changed):
        for field in ('motion', 'readability', 'hover'):
            assert proposal[field][name] == before[field][name]
    print('Fresh native checks required:', len(changed), sorted(changed), flush=True)


if __name__ == '__main__':
    refine([WORK / f'battle-final-group-{i}/battle-review.json' for i in range(1, 4)],
           WORK / 'battle-input-v3/placement.json', WORK / 'battle-clearance-v1')
