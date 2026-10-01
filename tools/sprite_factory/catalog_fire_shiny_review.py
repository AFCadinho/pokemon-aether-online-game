"""Pin six standalone fire candidates and build a local normal/shiny review."""
import hashlib
import json
from pathlib import Path
import sys
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'.tmp/remaining-142-production'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def bbox(im):return ImageChops.difference(im,Image.new('RGB',im.size,im.getpixel((0,0)))).getbbox()
def main(version):
    work=BASE/('fire-shiny-'+version);captures=work/'captures-final';loops=work/'fire-loop-final'
    rows=json.loads((work/'runtime-verified-v2/report.json').read_text())
    assert len(rows)==6 and len({r['species'] for r in rows})==6
    for d in [captures,loops]:
        report=json.loads((d/'review.json').read_text());assert len(report['entries'])==6
        assert all(not r['errors'] and len(r['captures'])==5 for r in report['entries'])
    out=work/'review';out.mkdir(exist_ok=False);cards=[];proof=[]
    actions=[('idle',50,'Stilstand'),('physical_attack',50,'Fysieke aanval'),('special_attack',50,'Speciale aanval'),('sleep',50,'Slaap'),('faint_start',100,'Flauw')]
    for name in ['ponyta','rapidash','centiskorch']:
        reference=ROOT/'assets/sprites/pokemon/pokemon_home_shiny'/f'{name}.png';Image.open(reference).save(out/f'{name}-reference.png')
        pictures={}
        for variant,key in [('normal',name),('shiny',name+'@shiny')]:
            row=next(r for r in rows if r['species']==key)
            assert sha(row['runtime_path'])==row['runtime_sha256'] and row['native_geometry_skin_animation_unchanged']
            frames=[Image.open(loops/f'{key}-idle-{t}.png').convert('RGB') for t in [0,25,50,75,100]]
            assert ImageChops.difference(frames[0],frames[-1]).getbbox() is None
            assert any(ImageChops.difference(frames[0],f).getbbox() for f in frames[1:4])
            b=[bbox(f) for f in frames];box=(min(x[0] for x in b)-15,min(x[1] for x in b)-15,max(x[2] for x in b)+15,max(x[3] for x in b)+15)
            cropped=[f.crop(box) for f in frames[:4]];cropped[0].save(out/f'{key}-loop.webp',save_all=True,append_images=cropped[1:],duration=500,loop=0,lossless=True)
            for action,phase,_ in actions:
                raw=captures/f'{key}-{action}-{phase}.png';im=Image.open(raw).convert('RGB');b=bbox(im);assert b
                im.crop((b[0]-15,b[1]-15,b[2]+15,b[3]+15)).save(out/f'{key}-{action}.png')
                if variant=='normal':
                    approved=BASE/'fire-live-preview-v1/poses-v9'/raw.name
                    assert ImageChops.difference(im,Image.open(approved).convert('RGB')).getbbox() is None
            proof.append({'species':name,'variant':variant,'runtime_path':str(Path(row['runtime_path']).relative_to(ROOT)),'runtime_sha256':row['runtime_sha256'],'native_geometry_skin_animation_unchanged':True,'native_clips':6,'loop_boundary_pixels_identical':True,'visible_fire_motion':True,'normal_pixels_identical_to_approved_v9':variant=='normal','shiny_appearance_approved':False,'runtime_approved':False,'captures':{str(p.relative_to(ROOT)):sha(p) for p in sorted(captures.glob(key+'-*.png'))+sorted(loops.glob(key+'-*.png'))}})
        cards.append(f'<article><h2>{name.title()}</h2><div class="trio"><figure><figcaption>Normal</figcaption><img class="actor" data-key="{name}" src="{name}-idle.png"></figure><figure><figcaption>Shiny — nieuwe kandidaat</figcaption><img class="actor" data-key="{name}@shiny" src="{name}@shiny-idle.png"></figure><figure><figcaption>Bestaande shiny-referentie</figcaption><img src="{name}-reference.png"></figure></div></article>')
    buttons=''.join(f'<button onclick="pose(\'{a}\')">{label}</button>' for a,_,label in actions)+'<button onclick="pose(\'loop\')">Vuur beweegt</button>'
    page='''<!doctype html><html lang="nl"><meta charset="utf-8"><title>Drie vuur-Pokémon — normal en shiny</title><style>body{font:17px system-ui;background:#142332;color:#eaf1f7;margin:24px}article{padding:18px;border:1px solid #547087;border-radius:12px;background:#203342;margin:20px 0}.trio{display:grid;grid-template-columns:1fr 1fr 1fr;gap:15px}figure{margin:0}img{width:100%;height:380px;object-fit:contain;background:#202020}figcaption{padding:10px}button{font:inherit;padding:10px;margin:4px;background:#315976;color:white;border:1px solid #78aed0;border-radius:5px}header{position:sticky;top:0;background:#142332;padding:12px;z-index:1}@media(max-width:850px){.trio{grid-template-columns:1fr}}</style><header><h1>Ponyta, Rapidash en Centiskorch</h1><p>Controleer vooral de shiny-kleuren, ogen en onderdelen. De normale vormen zijn gelijk gebleven aan de goedgekeurde preview. Battle-grootte volgt apart.</p>'''+buttons+'''<p>‘Vuur beweegt’ toont vier momentopnamen met de Pokémon stilgezet.</p></header>'''+''.join(cards)+'''<script>function pose(action){document.querySelectorAll('.actor').forEach(img=>{img.src=img.dataset.key+'-'+action+(action==='loop'?'.webp':'.png')})}</script></html>'''
    (out/'index.html').write_text(page)
    evidence={'schema':1,'normal_appearance_approved':True,'shiny_appearance_approved':False,'battle_approved':False,'runtime_approved':False,'review_url':f'http://127.0.0.1:8782/fire-shiny-{version}/review/index.html','method':'authored palettes based on local HOME references; not official recovered rare textures','entries':proof,'palette_receipt_sha256':sha(work/'palette-receipt.json'),'pack_job_sha256':sha(work/'job-verified-v2.json'),'shader_sha256':sha(ROOT/'tools/sprite_factory/catalog_fire_preview.gdshader'),'pack_worker_sha256':sha(ROOT/'tools/sprite_factory/catalog_fire_preview_pack.gd'),'limitations':['Only normal appearance is accepted; shiny and battle review pending','Diagnostic shader remains outside gameplay material whitelist','Initial body reload comparison mistakenly compared generated mipmaps with a base-only PNG; verification now compares the complete mip chains and aborts the pack on any mismatch']}
    (ROOT/'tools/sprite_factory/catalog_remaining_142_fire_shiny_candidates.json').write_text(json.dumps(evidence,indent=2)+'\n');print(evidence['review_url'])
if __name__=='__main__':main(sys.argv[1])
