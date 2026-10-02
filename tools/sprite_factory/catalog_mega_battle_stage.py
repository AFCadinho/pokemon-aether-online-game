"""Stage accepted Mega appearances for native, review-only battle qualification."""
import argparse
import json
from pathlib import Path

from catalog_mega_3d_production import sha, write
from catalog_remaining_eye_bake import chunks
from catalog_dlc_flat_motion import values


def stage(status, approval, control_catalog, output, expected_pairs=71):
    batch = json.loads(status.read_text())
    accepted = json.loads(approval.read_text())
    approvals = {r['species']: r for r in accepted['entries']}
    if (expected_pairs < 1 or not accepted['appearance_approved']
            or len(approvals) != expected_pairs or len(accepted['entries']) != expected_pairs
            or len(batch['entries']) != expected_pairs
            or {r['showdown_id'] for r in batch['entries']} != set(approvals)):
        raise ValueError(f'Complete {expected_pairs}-pair appearance acceptance required')
    rows, runtime = [], []
    for candidate in batch['entries']:
        if candidate['status'] != 'runtime_candidate':
            continue
        species = candidate['showdown_id']
        receipt = approvals[species]
        if not receipt['appearance_approved']:
            raise ValueError('Unaccepted appearance: ' + species)
        scenes = {r['species']: r for r in candidate['runtime_scenes']}
        for variant, model in candidate['variants'].items():
            identity = species + ('-shiny' if variant == 'shiny' else '')
            path = Path(model['path'])
            if sha(path) != model['sha256'] or model['sha256'] != receipt['variants'][variant]['sha256']:
                raise ValueError('Accepted asset changed: ' + identity)
            scene = scenes[identity]
            if scene['glb_sha256'] != model['sha256'] or sha(Path(scene['runtime_path'])) != scene['runtime_sha256']:
                raise ValueError('Standalone scene changed: ' + identity)
            document, binary = chunks(path)
            clips = {a['name']: max(v[0] for s in a['samplers']
                      for v in values(document, binary, s['input'])) for a in document['animations']}
            if set(clips) != set(candidate['actions']):
                raise ValueError('Incomplete action set: ' + identity)
            for name, duration in clips.items():
                if abs(duration - candidate['actions'][name]['duration']) > 1e-5:
                    raise ValueError('Clip timing changed: ' + identity + '/' + name)
            scale = receipt.get('approved_scale', 1.0)
            notes = 'Eigen Mega-rusthouding voor slaap.' if candidate.get('native_rest_sleep_review_required') else 'Eigen slaapclip.'
            if species == 'steelixmega':
                notes += ' Grootte 0,7 en herstelde materialen goedgekeurd.'
            poses = [[a, 0 if a == 'idle' else 1 if a == 'faint_start' else .5]
                     for a in clips if a != 'damage']
            rows.append(dict(species=identity, path=str(path), glb_sha256=model['sha256'],
                status='exported_for_review', placement=dict(scale=scale, yaw_degrees=0.0),
                animations=clips, battle_review_poses=poses, review_notes=notes,
                appearance_approved=True, runtime_approved=False, battle_approved=False))
            runtime.append(scene)
    if len(rows) != expected_pairs * 2:
        raise ValueError(f'Expected {expected_pairs * 2} standalone Mega variants')
    control = next(r for r in json.loads(control_catalog.read_text())['entries'] if r['species'] == 'dragonite')
    if sha(Path(control['path'])) != control['glb_sha256']:
        raise ValueError('Dragonite control changed')
    control = {**control, 'status': 'control', 'animations': {'idle': 1}}
    output.mkdir(parents=True, exist_ok=False)
    write(output / 'catalog.json', dict(schema=1, appearance_checkpoint_sha256=sha(approval),
          input_status_sha256=sha(status), runtime_approved=False, entries=rows + [control]))
    write(output / 'runtime.json', runtime)
    project = output / 'render-project'; project.mkdir()
    (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Mega battle qualification"\n'
        '[display]\nwindow/size/viewport_width=1152\nwindow/size/viewport_height=648\nwindow/vsync/vsync_mode=0\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    (project / 'tools').symlink_to(Path(__file__).resolve().parents[1], target_is_directory=True)
    print(f'Staged {expected_pairs} accepted normal/shiny pairs and Dragonite control', flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('status', 'approval', 'control-catalog', 'output'):
        p.add_argument('--' + key, type=Path, required=True)
    p.add_argument('--expected-pairs', type=int, default=71)
    a = p.parse_args()
    stage(a.status.resolve(), a.approval.resolve(), a.control_catalog.resolve(), a.output.resolve(), a.expected_pairs)
