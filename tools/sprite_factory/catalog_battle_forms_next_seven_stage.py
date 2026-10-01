"""Stage hash-pinned appearances with timings read from their GLBs."""
import argparse
import hashlib
import json
import math
from catalog_remaining_eye_bake import chunks
from catalog_dlc_flat_motion import values
from pathlib import Path


def stage(frontend, checkpoint, control_catalog, output, allow_appearance_proposal=False):
    data = json.loads(checkpoint.read_text())
    if not data.get('appearance_approved') and not allow_appearance_proposal:
        raise ValueError('Appearance approval required')
    rows = []
    for entry in data['entries']:
        if not entry.get('appearance_approved') and not allow_appearance_proposal:
            raise ValueError('Unapproved appearance: ' + entry['species'])
        path = (frontend / entry['path']).resolve()
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry['glb_sha256']:
            raise ValueError('Approved asset changed: ' + entry['species'])
        doc, binary = chunks(path)
        actual = {a['name']: max(v[0] for sampler in a['samplers']
            for v in values(doc, binary, sampler['input'])) for a in doc['animations']}
        for name, clip in entry['clips'].items():
            duration = clip['duration']
            if not math.isfinite(duration) or duration <= 0 or name not in actual or abs(actual[name] - duration) > 1e-5:
                raise ValueError('Source clip timing mismatch: ' + entry['species'] + '/' + name)
        row = dict(entry, path=str(path), status='exported_for_review',
                   complete_pose_channels=True, runtime_approved=False)
        row['action_timing'] = {name: dict(frames=spec['duration'] * 60,
            speed=1.0, loop=spec['loop']) for name, spec in entry['clips'].items()}
        row['animations'] = entry['clips']
        row['battle_review_poses'] = [[name, 0 if name == 'idle' else
            1 if name == 'faint_start' else .5] for name in entry['clips'] if name != 'damage']
        rows.append(row)
    controls = json.loads(control_catalog.read_text())['entries']
    control = next(row for row in controls if row['species'] == 'dragonite')
    if hashlib.sha256(Path(control['path']).read_bytes()).hexdigest() != control['glb_sha256']:
        raise ValueError('Dragonite control changed')
    output.mkdir(parents=True, exist_ok=False)
    (output / 'stage.json').write_text(json.dumps(rows, indent=2) + '\n')
    (output / 'catalog.json').write_text(json.dumps({'schema': 1,
        'runtime_approved': False, 'entries': rows + [control]}, indent=2) + '\n')
    print(f'Staged {len(rows)} review assets with actual clip durations')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--allow-appearance-proposal', action='store_true', help='Review only; never admission')
    parser.add_argument('--frontend', type=Path, required=True)
    parser.add_argument('--checkpoint', type=Path, required=True)
    parser.add_argument('--control-catalog', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    stage(args.frontend.resolve(), args.checkpoint.resolve(),
          args.control_catalog.resolve(), args.output.resolve(), args.allow_appearance_proposal)
