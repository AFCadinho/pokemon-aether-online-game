"""Rebake native Ogerpon form palettes for review; never admit automatically."""
import argparse
import copy
import hashlib
import html
import json
from pathlib import Path

from catalog_remaining_eye_bake import append_png, chunks, write_glb
from catalog_shiny_za_17_probe import run_flatpak
from phase5_variant_parity import compare
from scvi_form_material import palette

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OLD = ROOT / '.tmp/battle-forms-first-five-v1'


def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p): return json.loads(Path(p).read_text())
def write(p, v):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(v, indent=2, allow_nan=False)+'\n')


def build(output):
    output.mkdir(parents=True, exist_ok=False)
    intake = read(HERE/'catalog_battle_forms_first_five_intake.json')
    catalog = read(OLD/'captures-v6/catalog.json')
    entries = []
    for index, row in enumerate(intake['entries'][:3], 1):
        name = row['species']
        source = Path(intake['source_root'])/row['model']
        table = source.with_suffix('.trmmt')
        normal, rare = [palette(table, v, index) for v in ('normal', 'rare')]
        if normal != rare:
            raise ValueError('Normal/rare cloak palettes differ; separate bakes required')
        folder = output/name;folder.mkdir()
        job = read(OLD/'pre-hierarchy-fix/materials'/name/'normal/bake-job.json')
        # Use the corrected hierarchy Blend, not the obsolete pre-fix hash.
        job['source_sha256'] = sha(job['source'])
        job['receipt'] = str(folder/'shader-receipt.json')
        job['materials'] = [m for m in job['materials'] if m['name'] in ('body_c','body_a_02')]
        for item in job['materials']:
            item['output'] = str(folder/(item['name']+'.png'))
            item['glow_output'] = str(folder/(item['name']+'-glow.png'))
            item.pop('colour_overrides', None)
            item.pop('texture_overrides', None)
            item['form_palette'] = {'path':str(table),'sha256':sha(table),'variant':'normal','index':index}
        write(folder/'job.json',job)
        run_flatpak(HERE/'catalog_animation_material_worker.py', folder/'job.json',
                    [(OLD,''),(output,''),(HERE,':ro'),(Path(intake['source_root']),':ro')],folder/'bake.log')
        receipts = read(folder/'shader-receipt.json')
        if not all(r['native_emission_output_zero'] for r in receipts):
            raise ValueError('Unexpected cloak emission')
        for variant in ('normal','shiny'):
            identity = name+('-shiny' if variant == 'shiny' else '')
            previous = OLD/'rest'/identity/'model.glb'
            target = folder/(variant+'.glb')
            doc, binary = chunks(previous)
            for material in doc['materials']:
                if material['name'] not in ('body_c','body_a_02'):continue
                pbr = material['pbrMetallicRoughness'];bound=pbr['baseColorTexture']
                sampler = doc['textures'][bound['index']].get('sampler',0)
                pbr['baseColorTexture']={**bound,'index':append_png(doc,binary,
                    (folder/(material['name']+'.png')).read_bytes(),material['name']+'_native_form_palette',sampler)}
            write_glb(target,doc,binary)
            parity = compare(previous,target)
            entry=copy.deepcopy(next(r for r in catalog['entries'] if r['species']==identity))
            entry.update(path=str(target),glb_sha256=sha(target),runtime_approved=False)
            entry.pop('runtime_path',None);entry.pop('runtime_sha256',None)
            entries.append(entry)
            write(folder/(variant+'-receipt.json'),{'source_glb_sha256':sha(previous),
                'glb_sha256':sha(target),'trmmt_sha256':sha(table),'palette_index':index,
                'bindings':normal,'geometry_skin_animation_parity':parity,
                'visual_approved':False,'runtime_approved':False})
        print('PALETTE',name,flush=True)
    write(output/'captures/catalog.json',{'entries':entries})
    write(output/'stage.json',entries)


def page(output):
    report = read(output/'captures/godot-review.json')
    if len(report['entries']) != 6 or any(r['errors'] for r in report['entries']):
        raise ValueError('Six-model Godot pose check must pass before review')
    cards=[];files={}
    for name in ('ogerpon-wellspring','ogerpon-hearthflame','ogerpon-cornerstone'):
        figures=[]
        for variant in ('normal','shiny'):
            identity=name+('-shiny' if variant=='shiny' else '')
            poses=next(r['poses'] for r in report['entries'] if r['species']==identity)
            before={};after={}
            for pose in poses:
                key=pose['action']+('-back' if pose['view']=='back' else '')
                filename=pose['image']
                after[key]='captures/'+filename
                before[key]='../battle-forms-first-five-v1/captures-v6/'+filename
                files[after[key]]=sha(output/after[key])
            for label,mapping in [('Voor · '+variant,before),('Na · '+variant,after)]:
                figures.append('<figure><figcaption>'+label+'</figcaption><a target="_blank" href="'+mapping['idle']+'"><img data-poses="'+html.escape(json.dumps(mapping),quote=True)+'" src="'+mapping['idle']+'"></a></figure>')
        cards.append('<article><h2>'+name.replace('-',' ').title()+'</h2><div class="row">'+''.join(figures)+'</div></article>')
    content='''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Ogerpon mantelkleuren</title><style>body{background:#111923;color:#eef4fb;font:16px system-ui;margin:18px}header{position:sticky;top:0;background:#172331;padding:14px}article{background:#1d2a38;padding:14px;margin:14px 0;border-radius:8px}.row{display:grid;grid-template-columns:repeat(4,1fr)}figure{margin:6px;text-align:center}img{width:100%;display:block}select{font:inherit;padding:8px}@media(max-width:800px){.row{grid-template-columns:repeat(2,1fr)}}</style><header><h1>Ogerpon — oorspronkelijke mantelkleuren hersteld</h1><p>Wellspring blauw/cyaan/wit, Hearthflame rood/geel, Cornerstone grijs. Normal en shiny naast elkaar. Klik op een beeld voor groter.</p><select id="pose"><option value="idle">Stilstand</option><option value="idle-back">Achterkant</option><option value="physical_attack">Aanval</option><option value="physical_attack_2">Tweede aanval</option><option value="special_attack">Speciale aanval</option><option value="sleep">Slaap</option><option value="faint_start">Flauw</option><option value="faint_loop">Blijft flauw</option></select></header>CARDS<script>document.querySelector('#pose').onchange=e=>document.querySelectorAll('img').forEach(im=>{im.src=JSON.parse(im.dataset.poses)[e.target.value];im.parentElement.href=im.src});</script></html>'''
    (output/'review.html').write_text(content.replace('CARDS',''.join(cards)))
    write(output/'review-manifest.json',{'images':files,'godot_report_sha256':sha(output/'captures/godot-review.json'),'visual_approved':False})


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True,type=Path)
    p.add_argument('--page-only',action='store_true')
    args=p.parse_args()
    (page if args.page_only else build)(args.output.resolve())
