"""Validate and collect an offline reconstruction review, never admit models."""
import argparse
import html
import json
import subprocess
from pathlib import Path

from remaining_twenty_one import ROOT,HERE,WORK,CORE,read,write,sha

RECEIPT=HERE/'remaining_twenty_one_result.json'
REGISTRIES=[ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json',ROOT/'launcher/data/reviewed_model_catalog.json']


def limitations(name):
    common=['Battle framing, closed sleep eyes, packaging and platform qualification remain pending.']
    if name.startswith('pikachu-') or name=='pichu-spiky-eared':
        return ['New costume/ear geometry: reference likeness, fit and intersections require art review. Native base motions retained.']+common
    if name.startswith('ogerpon-'):
        return ['New mask attachment, crystal material and effects; effect intensity, visibility and alignment require art review.',
                'Body motion is an authored generic proposal, not recovered native battle motion.']+common
    if name=='greninja-ash':
        return ['Five original action slots recovered. Missing textures were newly painted; face markings and palette require art review.',
                'Sleep is authored; the other five required clips use recovered source slots.']+common
    if name.startswith('castform-'):
        return ['Source shader graphs baked into review textures; newly authored shiny palette and missing motions require art review.',
                'Snowy shell visibility/alpha are authored and require silhouette review.' if name.endswith('snowy') else 'Review source translucency and facial expression states.']+common
    if name=='eternatus-eternamax':
        return ['Generic authored battle clips and shiny palette; silhouette, pose and motion need art review.',
                'Preview-only scale is 0.01; battle placement has not been qualified.']+common
    if name in ['necrozma-dawn-wings','necrozma-dusk-mane']:
        return ['Native clips retained; newly authored light/effect material requires art review.']+common
    if name=='necrozma-ultra':
        return ['Available native clips retained; missing motions and shiny palette are authored proposals.']+common
    return ['Native geometry and available clips retained; colour/emission mapping and authored sleep require art review.']+common


def validate(catalog, review, logs):
    names=set(read(HERE/'remaining_fourteen_qualification.json')['remaining_species'])
    expected=names|{n+'-shiny' for n in names}
    for data in [catalog,review]:
        assert data['runtime_approved'] is False
        actual=[e['species'] for e in data['entries']]
        assert len(actual)==42 and set(actual)==expected,'Missing or duplicated reconstruction'
    for log in logs:
        assert not any(marker in log for marker in ['SCRIPT ERROR:','ERROR:','Parse Error']), 'Engine error in successful-looking run'
    rows={r['species']:r for r in review['entries']}
    for e in catalog['entries']:
        assert e['runtime_approved'] is False
        assert set(CORE+['faint_loop'])<=set(e['animations'])
        r=rows[e['species']];assert not r['errors'],(e['species'],r['errors'])
        assert r.get('video_frames',0)>=108,'Missing motion review'
        assert len(r['poses'])==7
        name=e['base_species'];changes=e['changes']
        if name.startswith('ogerpon-'):
            assert changes.get('attachment_bone')=='head' and changes.get('effect_surfaces',0)>0
            assert r['attachment_samples']>0
        if (name.startswith('pikachu-') and name!='pikachu-cosplay') or name=='pichu-spiky-eared':
            assert changes.get('attachments') and r['attachment_samples']>0
        if name.startswith('pikachu-'):assert changes.get('black_tail_tip')
    return rows


def collect(directory):
    catalog=read(directory/'catalog.json');review=read(directory/'godot-review.json')
    version=directory.name.removeprefix('review-')
    logs=[WORK/f'build-{version}.log',WORK/f'render-{version}.log']
    rows=validate(catalog,review,[p.read_text() for p in logs])
    assert REGISTRIES[0].read_bytes()==REGISTRIES[1].read_bytes()
    records=[]
    for e in catalog['entries']:
        for pathkey,hashkey in [('path','glb_sha256'),('runtime_path','runtime_sha256')]:assert sha(Path(e[pathkey]))==e[hashkey]
        for p in rows[e['species']]['poses']:assert (directory/p['image']).is_file()
        frames=directory/(e['species']+'-frames')
        assert len(list(frames.glob('*.png')))==rows[e['species']]['video_frames']
        movie=directory/(e['species']+'.mp4')
        if not movie.exists():
            subprocess.run(['ffmpeg','-v','error','-framerate','12','-i',str(frames/'%04d.png'),'-an','-c:v','libx264','-threads','2','-crf','22','-pix_fmt','yuv420p','-movflags','+faststart',str(movie)],check=True)
        record={k:e[k] for k in ['species','base_species','variant','glb_sha256','runtime_sha256','changes']}
        record.update(runtime_approved=False,status='requires_art_review',limitations=limitations(e['base_species']),
                      clips=list(e['animations']),video_frames=rows[e['species']]['video_frames'],
                      attachment_samples=rows[e['species']]['attachment_samples'],video_sha256=sha(movie))
        records.append(record)
    gallery(directory,catalog)
    evidence={str(p.relative_to(ROOT)):sha(p) for p in logs+[directory/'catalog.json',directory/'godot-review.json',directory/'index.html']}
    for category in ['native','legacy','graph-bake','palettes']:
        for p in (WORK/category).rglob('*.json'):
            if 'rejected-' not in str(p) and '-retry-' not in p.name:
                evidence[str(p.relative_to(ROOT))]=sha(p)
    receipt={'runtime_approved':False,'visual_approved':False,'published':False,'release_approved':False,
             'forms_previewed':21,'appearances_previewed':42,'forms_admitted':0,'remaining_forms':21,
             'structural_review_passed':True,'platform':'Linux','renderer':review['renderer'],
             'scope':'Authored local proposals; structural success does not establish visual or battle quality.',
             'previous_qualification_sha256':sha(HERE/'remaining_fourteen_qualification.json'),
             'registries_sha256':{str(p.relative_to(ROOT)):sha(p) for p in REGISTRIES},
             'gallery':str(directory/'index.html'),'evidence_sha256':evidence,
             'code_sha256':{str(p.relative_to(ROOT)):sha(p) for p in HERE.glob('remaining_twenty_one*') if p.suffix in ['.py','.gd','.gdshader']},
             'entries':records}
    write(RECEIPT,receipt)
    print(json.dumps({'gallery':receipt['gallery'],'forms_previewed':21,'forms_admitted':0,'remaining_forms':21}))


def gallery(directory,catalog):
    cards=[]
    for name in sorted({e['base_species'] for e in catalog['entries']}):
        note=' '.join(limitations(name));variants=[]
        for suffix,label in [('', 'Normaal'),('-shiny','Shiny')]:
            key=name+suffix
            variants.append(f'<div><h3>{label}</h3><video controls loop muted preload="none" poster="{key}-idle-front.png" src="{key}.mp4"></video><p><a href="{key}-sleep-front.png">Slaap</a> · <a href="{key}-faint_start-front.png">Neervallen</a> · <a href="{key}-idle-back.png">Achterkant</a></p></div>')
        cards.append(f'<article><h2>{name}</h2><p>{html.escape(note)}</p><div class="pair">'+''.join(variants)+'</div></article>')
    page='''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>21 vormen — reconstructies</title>
<style>body{margin:32px auto;max-width:1200px;padding:0 20px;background:#101625;color:#e6edf8;font:16px system-ui}h1,h2{color:#c7afff}article{border-top:1px solid #465068;padding:20px 0}p{line-height:1.55}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}video{width:100%;background:#202020}a{color:#97caff}.notice{padding:20px;border:1px solid #dcac57;background:#392e20}@media(max-width:650px){.pair{grid-template-columns:1fr}}</style>
<h1>21 vormen · normal en shiny</h1><p class="notice">Lokale reconstructies. Nog niet visueel goedgekeurd of toegevoegd aan het spel. Sommige kostuums, kleuren, ogen, effecten en bewegingen moeten nog worden verfijnd. 0 vormen toegelaten; 21 blijven open.</p>
<p>Elke video toont een rondgang en daarna 12 samples per animatie. De snelheid is voor inspectie en is niet de oorspronkelijke afspeelsnelheid. Linux-rendercontrole; battle- en platformtests volgen pas na goedkeuring van de beelden.</p>'''+''.join(cards)+'</html>'
    (directory/'index.html').write_text(page)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);a=p.parse_args();collect(a.directory.resolve())
