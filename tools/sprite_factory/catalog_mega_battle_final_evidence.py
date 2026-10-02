"""Retain and compose independent native follow-ups without trusting capture-only rows."""
import argparse
import copy
import json
import os
from pathlib import Path

from catalog_mega_3d_production import sha
from catalog_mega_battle_qualification import qualify


def read(path):
    return json.loads(path.read_text())


def floor_followup(original_path, current_path, observed_path):
    original, current, observed = read(original_path), read(current_path), read(observed_path)
    result = copy.deepcopy(current)
    changes = {}
    for row in observed['entries']:
        name = row['species']
        for action, clip in row.get('corrected_clearance_120hz', {}).items():
            if clip['minimum_y'] >= .024:
                continue
            assert action not in ('idle', 'faint_start', 'faint_loop'), 'Needs linked root/endpoint review'
            before = original['motion'][name]['clips'][action]['offsets']
            after = current['motion'][name]['clips'][action]['offsets']
            differences = [b - a for a, b in zip(before, after)]
            assert len(before) == len(after) and max(differences) - min(differences) < 1e-6
            corrected_minimum = clip['minimum_y'] + min(differences)
            if corrected_minimum >= .024:
                continue
            addition = .031 - corrected_minimum
            target = result['motion'][name]['clips'][action]
            target['offsets'] = [round(value + addition, 7) for value in target['offsets']]
            changes.setdefault(name, {})[action] = dict(observed_minimum_y=clip['minimum_y'],
                added_root_clearance=addition, final_target_minimum_y=.031)
    result['subframe_followup'] = dict(changes=changes, original_profiles_sha256=sha(original_path),
        previous_profiles_sha256=sha(current_path), observed_report_sha256=sha(observed_path))
    return result


def compose(report_path, original_path, final_path, followups, output):
    original, final = read(original_path), read(final_path)
    report = read(report_path)
    assert report['complete'] and report['candidates_sha256'] == sha(original_path)
    sources = [(report_path, original_path, report)]
    for report_file, profile_file in followups:
        data = read(report_file)
        assert data['complete'] and data['candidates_sha256'] == sha(profile_file)
        for key in ('catalog_sha256', 'runtime_catalog_sha256', 'framing_sha256', 'motion_rules_sha256'):
            assert data[key] == report[key], key
        rows = {r['species'] for r in data['entries'] if 'clips' in r}
        assert rows and rows == set(data['selected_variants'])
        sources.append((report_file, profile_file, data))
    selected = {}
    evidence = {}
    for source_file, profile_file, data in sources:
        profiles = read(profile_file)
        for row in data['entries']:
            name = row['species']
            if 'clips' not in row:
                continue
            # Every adopted row must have actually measured the final per-form profile.
            if profiles['motion'][name] != final['motion'][name] or profiles['readability'][name] != final['readability'][name]:
                continue
            assert row['glb_sha256'] == final['motion'][name]['sha256']
            assert abs(row['scale'] - final['motion'][name]['scale']) < 1e-6
            assert abs(row['candidate_lift'] - final['motion'][name]['lift']) < .001
            adopted = copy.deepcopy(row)
            for shot in adopted['shots']:
                image = source_file.parent / shot['image']
                assert image.is_file()
                shot['image'] = os.path.relpath(image.resolve(), output.parent.resolve())
            selected[name] = adopted
            evidence[name] = dict(report=str(source_file.resolve()), report_sha256=sha(source_file),
                                  profiles=str(profile_file.resolve()), profiles_sha256=sha(profile_file))
    assert set(selected) == set(final['motion']) and len(selected) == 142, 'Missing final native evidence'
    combined = dict(report, entries=[selected[n] for n in sorted(selected)],
        candidates_sha256=sha(final_path), composed_native_evidence=evidence,
        runtime_approved=False, battle_visual_approved=False,
        scope='Exact final placement independently sampled at 120Hz; original and filtered reruns retained per row')
    assert not output.exists()
    output.write_text(json.dumps(combined, indent=2, allow_nan=False) + '\n')
    return combined


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('phase', choices=('floor-followup', 'compose'))
    p.add_argument('--original', type=Path, required=True)
    p.add_argument('--current', type=Path, required=True)
    p.add_argument('--report', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--followup', action='append', nargs=2, type=Path, default=[])
    p.add_argument('--catalog', type=Path)
    a = p.parse_args()
    if a.phase == 'floor-followup':
        result = floor_followup(a.original, a.current, a.report)
        with a.output.open('x') as f:
            json.dump(result, f, indent=2, allow_nan=False); f.write('\n')
        print('Native clearance follow-ups:', list(result['subframe_followup']['changes']))
    else:
        compose(a.report, a.original, a.current, a.followup, a.output)
        assert a.catalog
        gate = qualify(a.output, a.catalog)
        assert gate['technical_variant_count'] == 142 and not gate['held'], gate['held']
        receipt = a.output.with_name('technical-qualification-final.json')
        with receipt.open('x') as f:
            json.dump(gate, f, indent=2); f.write('\n')
        print('Final native technical variants:', gate['technical_variant_count'])
