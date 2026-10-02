"""Check native Mega battle evidence; technical success never grants art approval."""
import argparse
import json
import math
from pathlib import Path

from catalog_mega_3d_production import sha


def qualify(report_path, catalog_path):
    report = json.loads(report_path.read_text())
    catalog = json.loads(catalog_path.read_text())
    rows = {r['species']: r for r in report['entries'] if 'clips' in r}
    expected = {r['species'] for r in catalog['entries'] if r['species'] != 'dragonite'}
    if not report.get('complete') or len(expected) != 142 or set(rows) != expected:
        raise ValueError('Complete 71-pair native battle report required')
    if report['catalog_sha256'] != sha(catalog_path):
        raise ValueError('Battle catalog changed')
    held, passed = {}, []
    for name, row in rows.items():
        errors = []
        measured = row.get('corrected_clearance_120hz', {})
        if set(measured) != set(row['clips']):
            errors.append('Missing independent 120 Hz action coverage')
        for action, clip in measured.items():
            expected_samples = math.ceil(row['clips'][action]['duration'] * 120) + 1
            minima = clip.get('minimum_y_samples', [])
            if clip.get('samples') != expected_samples or len(minima) != expected_samples:
                errors.append(f'{action}: incomplete 120 Hz sample clock')
            if not minima or not math.isfinite(clip['minimum_y']) or any(not math.isfinite(v) for v in minima) or abs(min(minima) - clip['minimum_y']) > 1e-6:
                errors.append(f'{action}: invalid native clearance samples')
            if clip['minimum_y'] < .024:
                errors.append(f'{action}: floor clearance {clip["minimum_y"]:.6f} m')
        for shot in row['shots']:
            if not shot['in_view']:
                errors.append(f'{shot["action"]}/{shot["arena_camera"]}/{shot["side"]}: outside camera')
            if shot['model_overlaps_hud_proxy']:
                errors.append(f'{shot["action"]}/{shot["arena_camera"]}/{shot["side"]}: overlaps HUD proxy')
        if errors:
            held[name] = errors
        else:
            passed.append(name)
    return dict(schema=1, runtime_approved=False, battle_visual_approved=False,
        technical_variant_count=len(passed), expected_variant_count=142,
        independent_native_sample_hz=120, held=held, technical_passed=passed,
        battle_report_sha256=sha(report_path), catalog_sha256=sha(catalog_path),
        scope='Native SCN full-clock floor clearance plus captured poses in four camera/side combinations. Full UI, arena collision and performance qualification remain separate.')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--report', type=Path, required=True)
    p.add_argument('--catalog', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args(); data = qualify(a.report, a.catalog)
    with a.output.open('x') as f:
        json.dump(data, f, indent=2); f.write('\n')
    print('Technical variants:', data['technical_variant_count'], 'held:', data['held'])
