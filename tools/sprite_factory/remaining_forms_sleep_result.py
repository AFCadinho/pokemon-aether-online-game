"""Verify and present sleep repairs separately from the approved colour preview."""
from html import escape
from pathlib import Path
import subprocess

from PIL import Image, ImageChops, ImageDraw
from catalog_galar_birds_candidates import read, write, sha
from remaining_forms_sleep import ROOT, HERE, OLD, WORK, NAMES, closed_atlas
from catalog_remaining_eye_bake import chunks
from io import BytesIO


def main():
    catalog_path = WORK/'review-v2/catalog.json'
    catalog = read(catalog_path)
    check_path = WORK/'check-final-geometry.json'
    check = read(check_path)
    assert not catalog['runtime_approved'] and not check['runtime_approved']
    expected = {n+s for n in NAMES for s in ('','-shiny')}
    assert {e['species'] for e in catalog['entries']} == expected
    assert {e['species'] for e in check['entries'] if e['passed']} == expected
    reports = {}
    for folder in ('review-v2','sleep-around-v2'):
        path = WORK/folder/'godot-review.json'
        report = read(path)
        assert not report['runtime_approved'] and len(report['entries'])==12
        assert {e['species'] for e in report['entries']} == expected
        assert all(not e['errors'] for e in report['entries'])
        reports[folder] = {'path':str(path),'sha256':sha(path),'renderer':report['renderer'],
            'frames':sum(e.get('video_frames',e.get('sleep_frames',0)) for e in report['entries'])}
    entries = {}; pixels = []; source_cell_checks = 0
    for entry in catalog['entries']:
        name = entry['species']
        assert sha(entry['runtime_path'])==entry['runtime_sha256']
        assert sha(entry['approved_runtime_path'])==entry['approved_runtime_sha256']
        assert sha(entry['path'])==entry['glb_sha256']
        doc,binary = chunks(entry['path'])
        for label,states in entry['eye_states'].items():
            material = next(m for m in doc['materials'] if m['name']==label)
            pbr = material['pbrMetallicRoughness']
            infos = {'albedo_texture':pbr.get('baseColorTexture'),'normal_texture':material.get('normalTexture'),
                'roughness_texture':pbr.get('metallicRoughnessTexture'),'metallic_texture':pbr.get('metallicRoughnessTexture'),
                'emission_texture':material.get('emissiveTexture')}
            for key,state in states.items():
                assert sha(state['path'])==state['sha256'] and not state['resampled']
                image = doc['images'][doc['textures'][infos[key]['index']]['source']]
                view = doc['bufferViews'][image['bufferView']];start=view.get('byteOffset',0)
                original = Image.open(BytesIO(binary[start:start+view['byteLength']])).convert('RGBA')
                actual = Image.open(state['path']).convert('RGBA')
                assert actual.size==original.size and actual.tobytes()==closed_atlas(original).tobytes()
                source_cell_checks += 1
        videos = {}
        for folder in ('review-v2','sleep-around-v2'):
            frames = WORK/folder/(name+'-frames')
            video = WORK/folder/(name+'.mp4')
            if not video.exists():
                subprocess.run(['ffmpeg','-nostdin','-loglevel','error','-n','-framerate','12',
                    '-i',str(frames/'%04d.png'),'-c:v','libx264','-threads','2','-preset','fast',
                    '-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(video)],check=True)
            videos[folder]={'path':str(video),'sha256':sha(video)}
        prior_folder = 'visibility-review-v2' if entry['base_species'].startswith('cramorant') else 'colour-review-v2'
        for action,view in [('idle','face'),('idle','back'),('idle','side'),('physical_attack','front'),
                            ('special_attack','front'),('damage','front'),('faint_start','front')]:
            filename = name+'-'+action+'-'+view+'.png'
            old = OLD/prior_folder/filename;new=WORK/'review-v2'/filename
            a,b=Image.open(old).convert('RGB'),Image.open(new).convert('RGB')
            assert a.size==b.size
            diff = ImageChops.difference(a,b)
            pixels.append({'species':name,'pose':action+'-'+view,
                'changed_pixels':sum(any(p) for p in diff.get_flattened_data()),'total_pixels':a.width*a.height,
                'source_sha256':sha(old),'candidate_sha256':sha(new)})
        entries[name]={'runtime_approved':False,'sleep_appearance_approved':False,
            'runtime_path':entry['runtime_path'],'runtime_sha256':entry['runtime_sha256'],
            'approved_runtime_sha256':entry['approved_runtime_sha256'],'videos':videos,
            'source_cell_count':sum(len(x) for x in entry['eye_states'].values()),
            'pose_policy':entry.get('sleep_attachment',{}).get('policy','Source body sleep unchanged; source closed-eye atlas cell selected.')}
    canvas = Image.new('RGB',(260*6,570),'#202020');draw=ImageDraw.Draw(canvas);cards=[]
    for index,name in enumerate(NAMES):
        pair=[]
        old_folder='visibility-review-v2' if name.startswith('cramorant') else 'colour-review-v2'
        for row,suffix in enumerate(('','-shiny')):
            species=name+suffix
            im=Image.open(WORK/'sleep-around-v2'/(species+'-sleep-face.png'));im.thumbnail((260,250))
            canvas.paste(im,(index*260,row*280+25));draw.text((index*260+4,row*280+4),species,fill='white')
            pair.append(f'<figure><figcaption>{"Shiny" if suffix else "Normaal"}</figcaption>'
                f'<video controls preload="none" poster="sleep-around-v2/{species}-sleep-face.png" src="sleep-around-v2/{species}.mp4"></video>'
                f'<details><summary>Oude slaappose</summary><img loading="lazy" src="../remaining-colour-visibility-v1/{old_folder}/{species}-sleep-face.png"></details>'
                f'<details><summary>Alle acties en wakker worden</summary><video controls preload="none" src="review-v2/{species}.mp4"></video></details></figure>')
        text = ('De kop houdt zijn eigen actieve oriëntatie, met gesloten ogen. De prooi volgt de kop; het lijf en de vleugels behouden hun bron-slaapbeweging.'
                if name.startswith('cramorant') else 'De slaapbeweging is behouden. De oorspronkelijke gesloten oogtekening wordt nu geselecteerd.')
        cards.append(f'<article><h2>{escape(name)}</h2><p>{text}</p><div class="pair">'+''.join(pair)+'</div></article>')
    contact=WORK/'sleep-repairs.png';canvas.save(contact)
    page=WORK/'index.html'
    page.write_text('''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Herstelde slaapposes</title>
<style>body{font:17px system-ui;background:#10151f;color:#e3e9f2;margin:0 auto;padding:28px;max-width:1300px}article{padding:22px;margin:24px 0;border:1px solid #43516a;border-radius:14px;background:#172030}.pair{display:grid;grid-template-columns:1fr 1fr;gap:18px}figure{margin:0}figcaption{margin:10px 0;font-weight:700}video,img{width:100%;background:#202020;border-radius:10px}summary{padding:12px;cursor:pointer}a{color:#bca5ff}.note{color:#ffd995}@media(max-width:650px){body{padding:12px}.pair{grid-template-columns:1fr}}</style>
<h1>Herstelde slaapogen en slaapposes</h1><p>Zes vormen, normaal en shiny. De gesloten ogen komen uit de oorspronkelijke oogtexturen. Cramorant behoudt zijn prooi tijdens het slapen.</p>
<p class="note">Je goedkeuring van de eerdere kleuren en vormtoestanden is vastgelegd. Deze slaapcorrecties zijn daarna gemaakt en lokaal getest. Battlekwalificatie, catalogustoelating en publicatie staan nog uit.</p>
<p><a href="../remaining-colour-visibility-v1/index.html">Eerdere 14 vormen bekijken</a></p>'''+''.join(cards)+'</html>')
    result={'schema':1,'runtime_approved':False,'battle_approved':False,'publication_approved':False,
        'visual_approval_sha256':sha(HERE/'remaining_forms_visual_approval.json'),
        'forms_repaired':6,'variants':12,'newly_admitted':0,'remaining_held_forms':35,
        'catalog':{'path':str(catalog_path),'sha256':sha(catalog_path)},
        'check':{'path':str(check_path),'sha256':sha(check_path),'summary':{k:v for k,v in check.items() if k!='entries'}},
        'source_cell_checks':source_cell_checks,'reports':reports,'awake_pixel_comparisons':pixels,
        'gallery':{'path':str(page),'sha256':sha(page),'contact':str(contact),'contact_sha256':sha(contact)},
        'entries':entries,'code_sha256':{p.name:sha(p) for pattern in ['remaining_forms_sleep*.py','remaining_forms_sleep*.gd'] for p in HERE.glob(pattern)}}
    write(HERE/'remaining_forms_sleep_result.json',result)
    print('SLEEP_REPAIR_RESULT',len(entries),'source_cells',source_cell_checks,'exact_awake_images',sum(p['changed_pixels']==0 for p in pixels),'/',len(pixels))


if __name__=='__main__':main()
