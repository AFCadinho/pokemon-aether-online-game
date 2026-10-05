"""Validate and record four eye-only revisions, then build their review page."""
import copy
import hashlib
import json
import os
from pathlib import Path

from PIL import Image
from catalog_galar_birds_candidates import sha
from phase5_variant_parity import signature

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.tmp/regional-production-v1'


def read(path):
    return json.loads(path.read_text())


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def main():
    folder = WORK / 'eye-last-two-v2'
    before_folder = WORK / 'eyes-followup-v2/appearance'
    after_folder = folder / 'appearance'
    old = {r['species']: r for r in read(WORK / 'runtime-final-v3.json')}
    new = {r['species']: r for r in read(folder / 'runtime/report.json')}
    before = {r['species']: r for r in read(before_folder / 'godot-review.json')['entries']}
    after = {r['species']: r for r in read(after_folder / 'godot-review.json')['entries']}
    assert len(new) == len(after) == 4 and set(new) == set(after)
    proof = []
    for name, row in new.items():
        assert not after[name]['errors']
        assert sha(Path(row['path'])) == row['glb_sha256']
        assert sha(Path(row['runtime_path'])) == row['runtime_sha256']
        assert signature(row['path']) == signature(old[name]['path'])
        delta = 0
        assert before[name]['clips'].keys() == after[name]['clips'].keys()
        for action, clip in before[name]['clips'].items():
            fresh = after[name]['clips'][action]
            assert clip['duration'] == fresh['duration'] and clip['tracks'] == fresh['tracks']
            assert len(clip['samples']) == len(fresh['samples'])
            for a, b in zip(clip['samples'], fresh['samples']):
                assert a['fraction'] == b['fraction']
                delta = max(delta, *(abs(x-y) for k in ['min', 'size'] for x,y in zip(a[k],b[k])))
        assert delta < .00001, (name, delta)
        if name.startswith('typhlosion'):
            original = copy.deepcopy(old[name]['eye_motion'])
            revised = copy.deepcopy(row['eye_motion'])
            original.pop('glb_sha256'); revised.pop('glb_sha256')
            for a,b in zip(original['materials'],revised['materials']):
                a['clips'].pop('idle'); b['clips'].pop('idle')
            assert original == revised, 'Only idle gaze may change'
        proof.append({'species': name, 'old_runtime_sha256': old[name]['runtime_sha256'],
                      'runtime_sha256': row['runtime_sha256'], 'geometry_motion_sha256': signature(row['path']),
                      'max_pose_bound_difference_m': delta})
    save(folder / 'geometry-proof.json', {'runtime_approved': False,
        'scope': 'Eye texture/idle gaze only; prior geometric qualification retained by exact skeletal parity and fresh runtime bounds. Visual acceptance pending.',
        'prior_battle_qualification_sha256': sha(WORK / 'battle-final-combined-v2/qualification.json'), 'entries': proof})
    merged = [new.get(n,r) for n,r in old.items()]
    save(WORK / 'runtime-final-v4.json', merged)
    catalog = read(WORK / 'eyes-followup-v2/catalog.json')
    catalog['entries'] = [new.get(r['species'],r) for r in catalog['entries']]
    save(folder / 'catalog.json', catalog)
    placement = read(WORK / 'eyes-followup-v2/placement.json')
    placement['catalog_sha256'] = sha(folder / 'catalog.json')
    for n,r in new.items():
        assert placement['motion'][n]['sha256'] == old[n]['glb_sha256']
        placement['motion'][n]['sha256'] = r['glb_sha256']
    save(folder / 'placement.json', placement)
    out = WORK / 'eyes-last-two-review-v1'
    out.mkdir(exist_ok=False)
    rows, images = [], []
    for name,label,box in [('pikachu-alola','Pikachu — Alola-pet',(230,300,620,565)),
                           ('typhlosion-hisui','Typhlosion — Hisui',(220,245,445,375))]:
        entry = {'name':label, 'images':{}}
        for suffix,variant in [('', 'Normal'),('-shiny', 'Shiny')]:
            n = name+suffix
            for state,records,base in [('Voor',before,before_folder),('Na',after,after_folder)]:
                key = variant+' · '+state
                entry['images'][key] = {}
                for pose in records[n]['poses']:
                    if pose['view'] != 'face': continue
                    path = base / pose['image']
                    images.append({'path':str(path.relative_to(ROOT)),'sha256':sha(path)})
                    entry['images'][key][pose['action']] = os.path.relpath(path,out)
                    if pose['action'] == 'idle':
                        crop = out / (n+'-'+state+'-eyes.png')
                        Image.open(path).crop(box).save(crop)
                        entry['images'][key]['closeup'] = crop.name
        rows.append(entry)
    html = '''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Pikachu en Typhlosion — ogen</title>
<style>body{background:#111c28;color:#edf4fb;font:17px system-ui;margin:0}header{background:#1b3143;padding:20px;position:sticky;top:0}main{max-width:1700px;margin:auto;padding:20px}article{padding:18px;background:#213444;border:1px solid #577088;border-radius:10px;margin:20px 0}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}figure{margin:0}img{width:100%;background:#202020;object-fit:contain}figcaption{padding:8px}select{font:inherit;padding:10px;color:white;background:#28495e;border-radius:6px}a{color:#95e5ff}p{line-height:1.5}h1{font-size:24px}@media(max-width:750px){.grid{grid-template-columns:repeat(2,1fr)}header{position:static}}</style>
<header><h1>Pikachu en Typhlosion — nieuwe ogenvergelijking</h1><select id="pose"><option value="closeup">Ogen van dichtbij</option><option value="idle">Stilstand</option><option value="physical_attack">Aanval 1</option><option value="physical_attack_2">Aanval 2</option><option value="special_attack">Speciale aanval</option><option value="sleep">Slaap</option><option value="faint_start">Flauw</option></select></header>
<main><p>Vergelijk Voor en Na. Pikachu heeft weer witte oogglinsteringen. Bij Typhlosion staat de iris bij stilstand weer in het zicht. Klik op een afbeelding om die groot te openen.</p><p>Deze Pikachu met Alola-pet heeft in de bron dezelfde kleuren voor normal en shiny.</p><div id="cards"></div></main>
<script>const rows=DATA;function draw(){const root=document.getElementById('cards');root.replaceChildren();for(const r of rows){const card=document.createElement('article'),h=document.createElement('h2');h.textContent=r.name;card.append(h);const grid=document.createElement('div');grid.className='grid';for(const [name,poses] of Object.entries(r.images)){const f=document.createElement('figure'),c=document.createElement('figcaption');c.textContent=name;f.append(c);const a=document.createElement('a'),im=new Image();a.href=poses[document.getElementById('pose').value];a.target='_blank';im.src=a.href;im.alt=r.name+' '+name;a.append(im);f.append(a);grid.append(f);}card.append(grid);root.append(card);}}document.getElementById('pose').onchange=draw;draw();</script></html>'''
    (out / 'index.html').write_text(html.replace('DATA',json.dumps(rows)))
    save(out / 'evidence.json', {'runtime_approved':False, 'before_report_sha256':sha(before_folder/'godot-review.json'),
                              'after_report_sha256':sha(after_folder/'godot-review.json'), 'images':images})
    manifest_path = ROOT / 'tools/sprite_factory/regional_model_candidate_review.json'
    manifest = read(manifest_path)
    for row in manifest['entries']:
        n = row['species']
        if n not in new: continue
        r = new[n]
        row.update(glb_sha256=r['glb_sha256'], runtime_sha256=r['runtime_sha256'],
                   candidate_path=str(Path(r['path']).relative_to(ROOT)), runtime_path=str(Path(r['runtime_path']).relative_to(ROOT)),
                   motion_profile_sha256=hashlib.sha256(json.dumps(placement['motion'][n],sort_keys=True).encode()).hexdigest())
    for path in [WORK/'runtime-final-v4.json',folder/'catalog.json',folder/'placement.json',folder/'stage.json',
                 folder/'source-proof.json',folder/'geometry-proof.json',after_folder/'godot-review.json',out/'evidence.json']:
        manifest['reports'][str(path.relative_to(WORK))] = sha(path)
    manifest['current_runtime_report'] = 'runtime-final-v4.json'
    manifest['current_placement'] = 'eye-last-two-v2/placement.json'
    manifest['last_eye_review'] = 'eyes-last-two-review-v1/index.html'
    manifest['last_eye_correction_pairs'] = ['pikachu-alola','typhlosion-hisui']
    manifest['geometry_qualification_scope'] += ' Four subsequent eye-only revisions retain the same geometry; see eye-last-two-v2/geometry-proof.json.'
    save(manifest_path, manifest)
    print('Four eye revisions verified; review:',out/'index.html')


if __name__ == '__main__':
    main()
