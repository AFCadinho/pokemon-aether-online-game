"""Replace incompatible base-form sleep with a review-only native Mega rest loop."""
import argparse
import copy
import json
from pathlib import Path

from catalog_remaining_eye_bake import chunks, write_glb
from phase5_variant_parity import compare
from catalog_mega_3d_production import sha, write


def native_rest(document):
    animations = document['animations']
    rests = [a for a in animations if a['name'] == 'faint_loop']
    sleeps = [i for i, a in enumerate(animations) if a['name'] == 'sleep']
    if len(rests) != 1 or len(sleeps) != 1:
        raise ValueError('Expected one own-rig rest loop and one sleep clip')
    # Reuse only the exact native animation's channels and samplers. No mesh,
    # bone, skin, UV, image, material or binary data is altered here.
    animations[sleeps[0]] = {**copy.deepcopy(rests[0]), 'name': 'sleep'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--status', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = args.output.resolve(); root.mkdir(parents=True, exist_ok=False)
    batch = json.loads(args.status.read_text()); results = []
    for old in batch['entries']:
        row = copy.deepcopy(old)
        if row.get('cross_bank_sleep_review_required'):
            for variant, model in row['variants'].items():
                source = Path(model['path'])
                if sha(source) != model['sha256']:
                    raise ValueError('Pinned model changed')
                document, binary = chunks(source)
                native_rest(document)
                target = root / row['showdown_id'] / variant / 'model.glb'
                write_glb(target, document, binary)
                model.update(path=str(target), sha256=sha(target))
            row['geometry_motion_sha256'] = compare(Path(row['variants']['normal']['path']),
                                                   Path(row['variants']['shiny']['path']))
            row['sleep_rest_correction'] = {'policy': 'native_mega_down_loop_as_rest_review',
                'replaced_base_action': old['actions']['sleep']['source_action'],
                'native_action': row['actions']['faint_loop']['source_action']}
            row['actions']['sleep'] = copy.deepcopy(row['actions']['faint_loop'])
            row['visibility']['clips']['sleep'] = copy.deepcopy(row['visibility']['clips']['faint_loop'])
            dynamic = old['visibility'].get('dynamic_visibility_tracks', [])
            row['visibility']['dynamic_visibility_tracks'] = [t for t in dynamic if not t.startswith('sleep:')]
            row['visibility']['dynamic_visibility_tracks'] += [t.replace('faint_loop:', 'sleep:', 1)
                                                              for t in dynamic if t.startswith('faint_loop:')]
            row['visibility']['dynamic_visibility_review_required'] = bool(row['visibility']['dynamic_visibility_tracks'])
            row['cross_bank_sleep_review_required'] = False
            row['native_rest_sleep_review_required'] = True
            row['warnings'] = [w for w in old['warnings'] if ':sleep:' not in w]
            row['warnings'] += [w.replace(':faint_loop:', ':sleep:') for w in old['warnings']
                                if ':faint_loop:' in w]
            row.pop('runtime_scenes', None)
            row['status'] = 'export_candidate'
        results.append(row)
        write(root / 'status.json', {**batch, 'entries': results, 'processed': len(results),
              'runtime_candidates': sum(r['status'] == 'runtime_candidate' for r in results),
              'export_candidates': sum(r['status'] == 'export_candidate' for r in results)})
        print(row['showdown_id'], row['status'], flush=True)


if __name__ == '__main__':
    main()
