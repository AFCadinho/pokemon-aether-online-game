"""Summarise diagnostic placement evidence; never creates runtime calibration."""
import argparse
import html
import json
import math
from pathlib import Path


def summarize(report):
    if report.get('runtime_approved') is not False or report.get('sample_hz') != 60 or report.get('complete') is not True:
        raise ValueError('Expected unapproved 60 Hz placement diagnostics')
    results = []
    seen = set()
    for entry in report['entries']:
        name = entry['species']
        if name in seen:
            raise ValueError('Duplicate species')
        seen.add(name)
        if entry.get('status') == 'held':
            results.append({'species': name, 'status': 'held'})
            continue
        lift = entry['candidate_lift']
        if not math.isfinite(lift) or lift < 0 or entry.get('runtime_approved') is not False:
            raise ValueError('Invalid candidate lift or approval')
        clips = entry['clips']
        if 'idle' not in clips:
            raise ValueError('Missing idle measurement')
        for clip in clips.values():
            if not math.isfinite(clip['minimum_y']) or not math.isfinite(clip['duration']) or clip['duration'] <= 0:
                raise ValueError('Invalid geometry or duration')
            if clip['samples'] != math.ceil(clip['duration'] * 60) + 1:
                raise ValueError('Incomplete clip sampling')
            if abs(clip['clearance_with_idle_lift'] - clip['minimum_y'] - lift) > 1e-5:
                raise ValueError('Inconsistent clearance')
        results.append({'species': name, 'status': 'measured_not_approved',
            'scale': entry['scale'], 'candidate_lift': lift,
            'idle_clearance': clips['idle']['clearance_with_idle_lift'],
            'floor_penetrating_clips': [name for name, clip in clips.items() if clip['clearance_with_idle_lift'] < -0.001],
            'out_of_frame_shots': [s['image'] for s in entry['shots'] if not s['in_view']],
            'hud_proxy_overlap_shots': [s['image'] for s in entry['shots'] if s['model_overlaps_hud_proxy']],
            'idle_hud_gap_pixels': [round(s['hud_gap_pixels'], 1) for s in entry['shots'] if s['action'] == 'idle']})
    return {'runtime_approved': False, 'entries': results}


def build(directory):
    report = json.loads((directory / 'battle-review.json').read_text())
    summary = summarize(report)
    (directory / 'summary.json').write_text(json.dumps(summary, indent=2))
    rows = []
    for entry, result in zip(report['entries'], summary['entries']):
        rows.append('<h2>' + html.escape(entry['species']) + '</h2><pre>' +
                    html.escape(json.dumps(result, indent=2)) + '</pre>')
        for shot in entry.get('shots', []):
            label = f"{shot['arena_camera']} / side {shot['side']} / {shot['action']}"
            rows.append('<figure style="display:inline-block;margin:6px"><a href="' + html.escape(shot['image'], quote=True) + '">' +
                        '<img width="460" src="' + html.escape(shot['image'], quote=True) + '"></a><figcaption>' +
                        html.escape(label) + '</figcaption></figure>')
    (directory / 'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Battle placement review</title>'
        '<style>body{background:#18202a;color:white;font:16px sans-serif}a{color:#8df}</style>'
        '<h1>Placement diagnostics — NOT runtime approved</h1>'
        '<p>Actual shared spawn/camera rules on a flat floor. Dragonite comparison on the opposite side. '
        'Text labels approximate current HP-HUD anchors, not the full battle UI. '
        'Projected AABB overlap is conservative; arena geometry and camera orbit are not certified.</p>' + ''.join(rows))
    for entry in summary['entries']:
        print(json.dumps(entry))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    build(parser.parse_args().directory)
