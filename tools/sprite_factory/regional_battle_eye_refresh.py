"""Refresh eye-only battle screenshots, preserving explicit geometry evidence."""
import argparse
import copy
import json
import os
from pathlib import Path

from catalog_galar_birds_candidates import sha
from phase5_variant_parity import signature
from regional_review_page import build
from catalog_mega_battle_qualification import qualify

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.tmp/regional-production-v1'
OUT = WORK / 'battle-eyes-final-v1'


def read(path):
    return json.loads(path.read_text())


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def prepare():
    OUT.mkdir(exist_ok=False)
    old = {r['species']:r for r in read(WORK/'runtime-final-v2.json')}
    new = {r['species']:r for r in read(WORK/'runtime-final-v4.json')}
    assert old.keys() == new.keys() and len(new) == 116
    a = read(WORK/'battle-clearance-v1/placement.json')
    b = read(WORK/'eye-last-two-v2/placement.json')
    report = WORK/'battle-final-combined-v2/battle-review.json'
    qualification = WORK/'battle-final-combined-v2/qualification.json'
    assert not read(qualification)['held']
    variants, changed = {}, []
    for n,r in new.items():
        previous = old[n]
        assert sha(Path(previous['path'])) == previous['glb_sha256']
        assert sha(Path(r['path'])) == r['glb_sha256']
        assert sha(Path(r['runtime_path'])) == r['runtime_sha256']
        assert signature(previous['path']) == signature(r['path'])
        assert previous['animations'] == r['animations']
        for field in ['readability','hover']:
            assert a[field][n] == b[field][n]
        old_motion = copy.deepcopy(a['motion'][n]); new_motion = copy.deepcopy(b['motion'][n])
        assert old_motion.pop('sha256') == previous['glb_sha256']
        assert new_motion.pop('sha256') == r['glb_sha256']
        assert old_motion == new_motion
        variants[n] = {'old_glb_sha256':previous['glb_sha256'], 'glb_sha256':r['glb_sha256'],
                       'runtime_sha256':r['runtime_sha256'], 'geometry_motion_sha256':signature(r['path'])}
        if previous['runtime_sha256'] != r['runtime_sha256']:
            changed.append(n)
    assert len(changed) == 44
    save(OUT/'receipt.json', {'runtime_approved':False, 'scope':'Fresh images only; exact geometry/motion/placement parity with prior qualification.',
         'source_report':str(report), 'source_report_sha256':sha(report), 'qualification_sha256':sha(qualification),
         'catalog_sha256':sha(WORK/'eye-last-two-v2/catalog.json'), 'runtime_sha256':sha(WORK/'runtime-final-v4.json'),
         'placement_sha256':sha(WORK/'eye-last-two-v2/placement.json'), 'variants':variants, 'changed':changed})
    print('Refresh',len(changed),'variants')


def finish():
    receipt = read(OUT/'receipt.json')
    fresh_dir = OUT/'render'
    fresh = read(fresh_dir/'battle-review.json')
    prior_path = Path(receipt['source_report'])
    assert sha(prior_path) == receipt['source_report_sha256']
    prior = read(prior_path)
    assert fresh['complete'] and set(fresh['selected_variants']) == set(receipt['changed'])
    assert fresh['catalog_sha256'] == receipt['catalog_sha256']
    assert fresh['runtime_catalog_sha256'] == receipt['runtime_sha256']
    assert fresh['candidates_sha256'] == receipt['placement_sha256']
    # Neither qualification thresholds nor source measurement results change.
    old_rows = {r['species']:r for r in prior['entries'] if 'shots' in r}
    new_rows = {r['species']:r for r in fresh['entries'] if 'shots' in r}
    assert set(new_rows) == set(receipt['changed'])
    for n,r in new_rows.items():
        assert r['glb_sha256'] == receipt['variants'][n]['glb_sha256']
        assert r['corrected_clearance_120hz'] == old_rows[n]['corrected_clearance_120hz']
        assert len(r['shots']) == 16
        for s in r['shots']:
            assert s['in_view'] and not s['model_overlaps_hud_proxy'], (n,s)
    combined = copy.deepcopy(fresh)
    combined['entries'] = []
    for n in sorted(old_rows):
        r = copy.deepcopy(new_rows.get(n,old_rows[n]))
        folder = fresh_dir if n in new_rows else prior_path.parent
        for shot in r['shots']:
            image = (folder/shot['image']).resolve()
            assert image.is_file()
            shot['image'] = os.path.relpath(image,OUT)
        combined['entries'].append(r)
    combined.update(selected_variants=[], scope='Fresh/reused screenshots; prior 120 Hz qualification retained by exact parity, no new performance qualification.',
                    refresh_receipt_sha256=sha(OUT/'receipt.json'))
    save(OUT/'battle-review.json',combined)
    qualification = qualify(OUT/'battle-review.json',WORK/'eye-last-two-v2/catalog.json',expected_pairs=58)
    assert not qualification['held'], qualification['held']
    qualification['measurement_reuse_receipt_sha256'] = sha(OUT/'receipt.json')
    qualification['scope'] = 'Prior full-clock 120 Hz qualification retained by exact geometry/placement parity; updated eye-material screenshots checked with unchanged thresholds. No new performance measurement.'
    save(OUT/'qualification.json',qualification)
    appearance = OUT/'appearance'
    appearance.mkdir(exist_ok=False)
    rows = {}
    for folder in [WORK/'appearance-final-v1',WORK/'eyes-followup-v2/appearance',WORK/'eye-last-two-v2/appearance']:
        report = read(folder/'godot-review.json')
        for r in report['entries']:
            assert not r['errors']
            r = copy.deepcopy(r)
            for p in r['poses']:
                if 'image' in p:
                    p['image'] = os.path.relpath((folder/p['image']).resolve(),appearance)
            rows[r['species']] = r
    assert len(rows) == 116
    save(appearance/'godot-review.json',{'entries':list(rows.values()), 'runtime_approved':False})
    page = WORK/'battle-review-final-v1'
    build(appearance,OUT,page,ROOT)
    html = (page/'index.html').read_text().replace('<option value="battle">','<option value="battle" selected>')
    (page/'index.html').write_text(html)
    manifest_path = ROOT/'tools/sprite_factory/regional_model_candidate_review.json'
    manifest = read(manifest_path)
    manifest['status'] = 'awaiting_final_battle_visual_review'
    manifest['current_battle_review'] = 'battle-review-final-v1/index.html'
    for p in [OUT/'receipt.json',OUT/'battle-review.json',OUT/'qualification.json',fresh_dir/'battle-review.json',appearance/'godot-review.json',page/'evidence.json']:
        manifest['reports'][str(p.relative_to(WORK))] = sha(p)
    save(manifest_path,manifest)
    print('Final battle gallery:',page/'index.html')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action',choices=['prepare','finish'])
    args = parser.parse_args()
    prepare() if args.action == 'prepare' else finish()
