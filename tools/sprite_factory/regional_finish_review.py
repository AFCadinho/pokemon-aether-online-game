"""Combine disjoint native checks, run the unchanged gate, build one review."""
import argparse
import copy
import json
from pathlib import Path
from catalog_galar_birds_candidates import sha
from catalog_mega_battle_qualification import qualify
from regional_review_page import build

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.tmp/regional-production-v1'


def main(refined=False):
    groups = json.loads((WORK / 'battle-final-groups.json').read_text())['groups']
    expected = {r['species'] for r in json.loads((WORK / 'runtime-final-v2.json').read_text())}
    assert len(expected) == 116 and sum(map(len, groups)) == 116
    assert set().union(*map(set, groups)) == expected
    combined = None
    rows, sources = {}, []

    def read_group(folder, names):
        path = folder / 'battle-review.json'
        report = json.loads(path.read_text())
        assert report['complete'] and set(report['selected_variants']) == set(names)
        assert report['catalog_sha256'] == sha(WORK / 'battle-input-v3/catalog.json')
        assert report['runtime_catalog_sha256'] == sha(WORK / 'runtime-final-v2.json')
        current = {r['species']: r for r in report['entries'] if 'clips' in r}
        assert set(current) == set(names)
        for row in current.values():
            for shot in row['shots']:
                assert (folder / shot['image']).is_file()
                shot['image'] = '../' + folder.name + '/' + shot['image']
        return report, current, {'report': str(path), 'sha256': sha(path), 'variants': names}

    for i, names in enumerate(groups, 1):
        report, current, source = read_group(WORK / f'battle-final-group-{i}', names)
        assert not set(current) & set(rows)
        rows.update(current)
        if combined is None:
            combined = copy.deepcopy(report)
        sources.append(source)
    assert set(rows) == expected
    placement = WORK / 'battle-input-v3/placement.json'
    if refined:
        receipt_path = WORK / 'battle-clearance-v1/receipt.json'
        receipt = json.loads(receipt_path.read_text())
        assert receipt['input_sha256'] == sha(placement)
        original = json.loads(placement.read_text())
        placement = WORK / 'battle-clearance-v1/placement.json'
        assert receipt['output_sha256'] == sha(placement)
        updated = json.loads(placement.read_text())
        changed = set(receipt['independent_remeasurement_required'])
        for name in expected - changed:
            for field in ('readability', 'motion', 'hover'):
                assert original[field][name] == updated[field][name]
        manifest = json.loads((WORK / 'battle-clearance-v1/launch.json').read_text())
        assert manifest['placement_sha256'] == sha(placement)
        checked = set()
        for run in manifest['groups']:
            report, current, source = read_group(Path(run['output']), run['variants'])
            assert not set(current) & checked
            checked.update(current)
            for key in ('framing_sha256', 'placement_sha256', 'motion_rules_sha256', 'viewport'):
                assert report[key] == combined[key]
            rows.update(current)
            sources.append(source)
        assert checked == changed
        combined['refinement_receipt_sha256'] = sha(receipt_path)
        combined['unmodified_variants_reused'] = sorted(expected - changed)
    combined.update(entries=[rows[n] for n in sorted(rows)], selected_variants=[], complete=True,
                    native_reports=sources, candidate_placement_sha256=sha(placement), runtime_approved=False)
    output = WORK / ('battle-final-combined-v2' if refined else 'battle-final-combined-v1')
    output.mkdir(exist_ok=False)
    report_path = output / 'battle-review.json'
    report_path.write_text(json.dumps(combined, indent=2) + '\n')
    qualified = qualify(report_path, WORK / 'battle-input-v3/catalog.json', expected_pairs=58)
    (output / 'qualification.json').write_text(json.dumps(qualified, indent=2) + '\n')
    print('Technical variants', qualified['technical_variant_count'], 'held', qualified['held'], flush=True)
    if qualified['held']:
        raise SystemExit('Resolve native battle holds before publishing the combined review')
    build(WORK / 'appearance-final-v1', output, WORK / 'review-v1', ROOT)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--refined', action='store_true')
    main(parser.parse_args().refined)
