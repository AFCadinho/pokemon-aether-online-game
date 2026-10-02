"""Correct observed native placement holds, preserving the original evidence."""
import argparse
import copy
import json
from pathlib import Path

from bake_motion_placement import bake
from catalog_mega_3d_production import sha


def correct(baseline_path, profile_path, observed_path, steelix_scale=.65):
    assert .5 <= steelix_scale < .7
    baseline = json.loads(baseline_path.read_text())
    original = json.loads(profile_path.read_text())
    observed = json.loads(observed_path.read_text())
    assert baseline['complete'] and original['catalog_sha256'] == baseline['catalog_sha256']
    rows = {r['species']: r for r in baseline['entries'] if 'clips' in r}
    checked = {r['species']: r for r in observed['entries'] if 'clips' in r}
    result = copy.deepcopy(original)
    changes = {}
    for species in ('steelixmega', 'steelixmega-shiny'):
        r = rows[species]
        assert abs(r['scale'] - .7) < 1e-6
        factor = steelix_scale / .7
        entry = dict(r, sha256=r['glb_sha256'], idle_verified=True,
                     scale=steelix_scale,
                     candidate_lift=max(0, .025 - r['clips']['idle']['minimum_y'] * factor),
                     clips={a: dict(c, minimum_y_samples=[v * factor for v in c['minimum_y_samples']])
                            for a, c in r['clips'].items()})
        result['readability'][species] = factor
        result['motion'].update(bake(dict(review_schema=1, errors=[], entries={species: entry}), [species]))
        changes[species] = {'reason': 'Special attack overlaps classic HUD proxy at accepted 0.7 scale',
                            'previous_scale': .7, 'proposed_scale': steelix_scale,
                            'focused_visual_acceptance_pending': True}
    for species in ('gyaradosmega', 'gyaradosmega-shiny'):
        action = 'physical_attack_2'
        minimum = checked[species]['corrected_clearance_120hz'][action]['minimum_y']
        assert minimum < .024, 'Only correct an observed clearance failure'
        addition = .030 - minimum + .001
        clip = result['motion'][species]['clips'][action]
        clip['offsets'] = [round(v + addition, 7) for v in clip['offsets']]
        changes[species] = {'reason': 'Independent 120Hz native subframe floor clearance',
                            'action': action, 'observed_minimum_y': minimum,
                            'added_root_clearance': addition,
                            'focused_visual_acceptance_pending': True}
    result['followup'] = {'original_profiles_sha256': sha(profile_path),
                          'baseline_sha256': sha(baseline_path),
                          'observed_report_sha256': sha(observed_path),
                          'changes': changes}
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('baseline', 'profiles', 'observed', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--steelix-scale', type=float, default=.65)
    a = p.parse_args()
    result = correct(a.baseline, a.profiles, a.observed, a.steelix_scale)
    with a.output.open('x') as f:
        json.dump(result, f, indent=2, allow_nan=False)
        f.write('\n')
    print('Follow-up variants:', ', '.join(result['followup']['changes']))
