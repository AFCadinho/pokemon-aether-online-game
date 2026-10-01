"""Build a local diagnostic page and pinned fire-loop evidence; no admission."""
import hashlib
import json
from pathlib import Path
import sys
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / '.tmp/remaining-142-production'

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main(version):
    work = BASE/'fire-live-preview-v1'
    poses = work/f'poses-{version}'
    loops = work/f'fire-only-{version}'
    rows = json.loads((work/f'runtime-inline-{version}/report.json').read_text())
    job = json.loads((work/f'job-inline-{version}.json').read_text())
    sources = {row['species']: row for row in job['entries']}
    output = work/f'review-{version}'
    output.mkdir(exist_ok=False)
    for directory in [poses, loops]:
        report = json.loads((directory/'review.json').read_text())
        assert all(not row.get('errors') for row in report['entries'])
    evidence = []
    cards = []
    for row in rows:
        name = row['species']
        assert row['native_geometry_skin_animation_unchanged']
        assert not row['runtime_approved'] and not row['appearance_approved']
        assert sha(row['runtime_path']) == row['runtime_sha256']
        frames = [Image.open(loops/f'{name}-idle-{phase}.png').convert('RGB')
                  for phase in [0,25,50,75,100]]
        assert ImageChops.difference(frames[0], frames[-1]).getbbox() is None
        assert any(ImageChops.difference(frames[0], frame).getbbox()
                   for frame in frames[1:4]), f'{name}: no visible fire motion'
        # All bone poses and framing are frozen during this comparison.
        bounds = None
        for frame in frames:
            background = Image.new('RGB',frame.size,frame.getpixel((0,0)))
            box = ImageChops.difference(frame,background).getbbox()
            assert box
            bounds = box if bounds is None else (min(bounds[0],box[0]),min(bounds[1],box[1]),max(bounds[2],box[2]),max(bounds[3],box[3]))
        x0,y0,x1,y1=bounds;box=(max(0,x0-30),max(0,y0-30),min(frames[0].width,x1+30),min(frames[0].height,y1+30))
        cropped = [frame.crop(box) for frame in frames[:4]]
        cropped[0].save(output/f'{name}-fire.webp',save_all=True,append_images=cropped[1:],duration=500,loop=0,lossless=True)
        source = BASE/'fire-source-reference-v1'/name/'idle-front.png'
        Image.open(source).save(output/f'{name}-source.png')
        pose_links=[]
        for action,label,phase in [('idle','Stilstand',50),('physical_attack','Fysieke aanval',50),('special_attack','Speciale aanval',50),('sleep','Slaap',50),('faint_start','Flauw',100)]:
            file=poses/f'{name}-{action}-{phase}.png'
            pose_links.append(f'<a target="_blank" href="../poses-{version}/{file.name}">{label}</a>')
        cards.append(f'<article><h2>{name.title()}</h2><div class="pair"><figure><figcaption>Bronweergave in Blender</figcaption><img src="{name}-source.png"></figure><figure><figcaption>Nieuwe vuurpreview — vier tijdstappen</figcaption><img src="{name}-fire.webp"></figure></div><nav>{" · ".join(pose_links)}</nav></article>')
        bake = BASE/('fire-live-mesh-v4' if name == 'centiskorch' else 'fire-live-mesh-v3')/name/'job.json'
        bake_job = json.loads(bake.read_text())
        assert sha(bake_job['source']) == bake_job['source_sha256']
        evidence.append({'source_blend_sha256':bake_job['source_sha256'],'bake_job_sha256':sha(bake),'bake_receipt_sha256':sha(bake_job['receipt']),'species':name,'runtime_sha256':row['runtime_sha256'],'source_scene_sha256':sources[name]['runtime_sha256'],'native_geometry_skin_animation_unchanged':True,'native_clips':6,'visible_fire_motion':True,'loop_boundary_pixels_identical':True,'appearance_approved':False,'runtime_approved':False,'captures':{str(p.relative_to(ROOT)):sha(p) for p in sorted(poses.glob(name+'-*.png'))+sorted(loops.glob(name+'-*.png'))},'fire_inputs':row['fire_materials']})
    page='''<!doctype html><html lang="nl"><meta charset="utf-8"><title>Vuurmodellen vergelijken</title><style>body{font:17px system-ui;background:#142332;color:#eaf1f7;margin:24px}article{background:#203342;border:1px solid #547087;border-radius:12px;padding:18px;margin:20px 0}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}figure{margin:0}img{width:100%;height:430px;object-fit:contain;background:#202020}figcaption{padding:10px}a{color:#8bd5ff}nav{margin-top:16px}@media(max-width:750px){.pair{grid-template-columns:1fr}}</style><h1>Ponyta, Rapidash en Centiskorch</h1><p>Vergelijk de vlammen, kleuren en volledigheid. Rechts beweegt alleen het vuur; de Pokémon staat stil. De animatie toont vier momentopnamen, dus geen vloeiende video.</p><p>Dit zijn normale vormen met een nieuw vuureffect. Shiny en battlecontrole volgen daarna. Bekijk via de links ook de aanvallen, slaap en flauw.</p>'''+''.join(cards)+'</html>'
    (output/'index.html').write_text(page)
    proof={'schema':1,'stage':'authored fire prototype; appearance review pending','approval_counts_changed':False,'review_url':f'http://127.0.0.1:8782/fire-live-preview-v1/review-{version}/index.html','shader_sha256':sha(ROOT/'tools/sprite_factory/catalog_fire_preview.gdshader'),'mesh_worker_sha256':sha(ROOT/'tools/sprite_factory/catalog_remaining_fire_mesh_worker.py'),'pack_job_sha256':sha(work/f'job-inline-{version}.json'),'entries':evidence,'limitations':['Authored reconstruction, not exact recovery of original source shaders','Horse flame cards use an authored UV cutout; outer fire masks are disabled','Only normal appearance preview; shiny, runtime whitelist, battle clearance and performance are not qualified','Four fire phases verify visible movement and exact sampled loop boundary; intermediate smoothness is not certified']}
    target=ROOT/'tools/sprite_factory/catalog_remaining_142_fire_preview.json'
    target.write_text(json.dumps(proof,indent=2)+'\n')
    print(proof['review_url'])

if __name__=='__main__':main(sys.argv[1])
