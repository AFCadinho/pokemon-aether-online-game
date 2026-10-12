"""Verify and present the 14 local proposals. This is not a qualification receipt."""
from html import escape
import json
from pathlib import Path
import subprocess

from PIL import Image, ImageDraw
from catalog_galar_birds_candidates import read, write, sha
from remaining_colour_preview import FAMILIES
from remaining_visibility_preview import NAMES

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
WORK = ROOT/'.tmp/remaining-colour-visibility-v1'
COLOURS = [n for group in FAMILIES.values() for n in group]


def concerns(name):
    if name.startswith(('burmy-', 'wormadam-')):
        return 'Shiny-kleur is gereconstrueerd. De ogen blijven open tijdens slapen; oogexpressies moeten nog worden hersteld.'
    if name == 'cherrim-sunshine':
        return 'Shiny-kleuren zijn gereconstrueerd. Kleuren en alle bewegingen moeten visueel worden goedgekeurd.'
    if name.startswith('cramorant-'):
        return 'Juiste prooi zichtbaar. De overgenomen slaappose laat de prooi door het lijf steken en houdt de ogen open; deze pose is afgekeurd.'
    return 'Zichtbaarheid en lichtgevende lagen zijn gereconstrueerd. Vormwissels en oorspronkelijke materiaalanimatie zijn niet bewezen.'


def main():
    all_entries = {}
    reports = []
    frame_count = clip_count = visibility_count = 0
    cards = []
    for folder, names in [('colour-review-v2', COLOURS), ('visibility-review-v2', NAMES)]:
        directory = WORK/folder
        catalog_path = directory/'catalog.json'
        report_path = directory/'godot-review.json'
        catalog, report = read(catalog_path), read(report_path)
        assert catalog['runtime_approved'] is False and report['runtime_approved'] is False
        expected = {n+s for n in names for s in ('', '-shiny')}
        assert {e['species'] for e in catalog['entries']} == expected
        assert len(catalog['entries']) == len(expected) == len(report['entries'])
        reviews = {e['species']:e for e in report['entries']}
        assert set(reviews) == expected
        for e in catalog['entries']:
            assert e['runtime_approved'] is False and e['status'] == 'exported_for_review'
            assert sha(e['path']) == e['glb_sha256'] and sha(e['runtime_path']) == e['runtime_sha256']
            assert sha(e['source_glb']) == e['source_glb_sha256']
            r = reviews[e['species']]
            assert not r['errors'] and set(r['clips']) == set(e['animations'])
            assert set(r['clips']) >= {'idle','physical_attack','special_attack','damage','sleep','faint_start'}
            for c in r['clips'].values():
                assert c['tracks'] > 0 and c['duration'] > 0 and len(c['samples']) == 3
            for spec in e.get('minior_materials',{}).values():
                for texture in spec['textures'].values():
                    assert sha(texture['path']) == texture['sha256']
                    assert list(Image.open(texture['path']).size) == texture['size']
            frames = directory/(e['species']+'-frames')
            assert len(list(frames.glob('*.png'))) == r['video_frames']
            frame_count += r['video_frames']; clip_count += len(r['clips'])
            visibility_count += r['visibility_samples']
            video = directory/(e['species']+'.mp4')
            if not video.exists():
                subprocess.run(['ffmpeg','-nostdin','-loglevel','error','-n','-framerate','12',
                    '-i',str(frames/'%04d.png'),'-c:v','libx264','-threads','2','-preset','fast',
                    '-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(video)],check=True)
            all_entries[e['species']] = {'base_species':e['base_species'],'variant':e['variant'],
                'runtime_approved':False,'appearance_approved':False,'battle_approved':False,
                'runtime_path':e['runtime_path'],'runtime_sha256':e['runtime_sha256'],
                'source_glb_sha256':e['source_glb_sha256'],'glb_sha256':e['glb_sha256'],
                'video':str(video),'video_sha256':sha(video),'review':str(report_path),
                'review_sha256':sha(report_path),'remaining':concerns(e['base_species'])}
        reports.append({'path':str(report_path),'sha256':sha(report_path),
            'catalog_path':str(catalog_path),'catalog_sha256':sha(catalog_path),
            'renderer':report['renderer'],'godot':report['godot']})
        canvas = Image.new('RGB',(280*len(names),590),'#202020'); draw = ImageDraw.Draw(canvas)
        for i,name in enumerate(names):
            figures = []
            for v,suffix in enumerate(('', '-shiny')):
                species = name+suffix
                poster = directory/(species+'-idle-face.png')
                im = Image.open(poster); im.thumbnail((280,260))
                canvas.paste(im,(i*280,v*290+25))
                draw.text((i*280+5,v*290+5),species,fill='white')
                relative = folder+'/'+species
                figures.append('<figure><figcaption>'+('Shiny' if v else 'Normaal')+'</figcaption>'
                    f'<video controls preload="none" poster="{relative}-idle-face.png" src="{relative}.mp4"></video>'
                    f'<details><summary>Slaappose bekijken</summary><img loading="lazy" src="{relative}-sleep-face.png"></details></figure>')
            reference = (f'<details><summary>Beschikbare shiny-kleurreferentie</summary><img style="width:180px" '
                         f'src="../../assets/sprites/pokemon/pokemon_home_shiny/{name}.png"></details>') if name in COLOURS else ''
            cards.append(f'<article id="{name}"><h2>{escape(name)}</h2><p class="note">{escape(concerns(name))}</p>'
                         +'<div class="pair">'+''.join(figures)+'</div>'+reference+'</article>')
        canvas.save(WORK/(folder+'-contact.png'))
    assert len(all_entries) == 28
    html = '''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>14 vormen — lokale modelpreviews</title><style>
body{font:17px system-ui;background:#10151f;color:#e3e9f2;margin:0 auto;padding:28px;max-width:1300px}h1{font-size:32px}h2{margin:0}a{color:#bca5ff}article{padding:22px;margin:25px 0;border:1px solid #43516a;border-radius:14px;background:#172030}.note{color:#ffd995}.pair{display:grid;grid-template-columns:1fr 1fr;gap:18px}figure{margin:0}figcaption{margin:10px 0;font-weight:700}video,img{width:100%;border-radius:10px;background:#202020}summary{padding:12px;cursor:pointer}nav{line-height:1.9}@media(max-width:650px){body{padding:12px}.pair{grid-template-columns:1fr}}</style>
<h1>14 vormen · normaal en shiny</h1>
<p>Lokale Godot-opnamen: rondom, daarna alle beschikbare gevechtsclips. De video's kun je pauzeren en terugspoelen.</p>
<p class="note">Dit zijn voorstellen, geen goedgekeurde modellen. Er blijven 35 vormen open. Burmy/Wormadam hebben nog geen gesloten slaapogen; bij Cramorant is de slaappose met prooi afgekeurd. R2 en de gamecatalogus zijn niet gewijzigd.</p>
<nav>'''+ ' · '.join(f'<a href="#{n}">{n}</a>' for n in COLOURS+NAMES)+'</nav>'+''.join(cards)+'</html>'
    page = WORK/'index.html'; page.write_text(html)
    result = {'schema':1,'runtime_approved':False,'appearance_approved':False,
        'scope':'Local visual reconstruction proposals, not battle qualification or admission',
        'forms':14,'variants':28,'remaining_held_forms':35,'newly_admitted':0,
        'checks':{'clips':clip_count,'clip_pose_samples':clip_count*3,
            'captured_video_frames':frame_count,'visibility_samples':visibility_count},
        'reports':reports,'gallery':str(page),'gallery_sha256':sha(page),'entries':all_entries,
        'code_sha256':{p.name:sha(p) for pattern in ['remaining_colour_*.py','remaining_colour_recipe.json',
            'remaining_forms_preview*.gd','remaining_forms_preview_result.py','remaining_visibility_preview.py',
            'remaining_minior_preview.gdshader'] for p in HERE.glob(pattern)}}
    write(HERE/'remaining_forms_preview_result.json',result)
    print('REMAINING_PREVIEW_RESULT',json.dumps(result['checks']),flush=True)


if __name__ == '__main__':
    main()
