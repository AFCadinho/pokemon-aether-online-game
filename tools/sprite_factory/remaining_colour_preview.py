"""Build five normal/shiny local previews, without runtime/catalog admission."""
from io import BytesIO
import json
import os
from pathlib import Path

from PIL import Image
from catalog_galar_birds_candidates import read, write, sha
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from catalog_shiny_za_17_probe import run_flatpak
from phase5_variant_parity import compare

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
WORK = ROOT / '.tmp/remaining-colour-visibility-v1/colour-v2'
OLD = ROOT / '.tmp/alternate-forms-batch-v1'
FAMILIES = {
    'pm0412': ['burmy-sandy', 'burmy-trash'],
    'pm0413': ['wormadam-sandy', 'wormadam-trash'],
    'pm0421': ['cherrim-sunshine'],
}


def png(image):
    out = BytesIO(); image.save(out, format='PNG'); return out.getvalue()


def build():
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name
    recipe = read(HERE/'remaining_colour_recipe.json')
    assert recipe['runtime_approved'] is False
    entries = []
    for family, names in FAMILIES.items():
        job = read(OLD/'legacy-export'/names[0]/'job.json')
        spec = recipe['families'][family]
        assert job['source_sha256'] == spec['source_sha256'] == sha(job['source'])
        refs = []
        for name in names:
            for folder, filename in [('front', 'sheet.png'), ('shiny_front', 'sheet.png'),
                                     ('pokemon_home_shiny', None)]:
                path = ROOT/'assets/sprites/pokemon'/folder/(name+'.png' if filename is None else name+'/'+filename)
                refs.append({'path': str(path), 'sha256': sha(path)})
        materials = sorted({m['name'] for name in names for m in chunks(OLD/'legacy-export'/name/'model.glb')[0]['materials']})
        output = WORK/'baked'/family
        output.mkdir(parents=True, exist_ok=True)
        bake_job = {'source': job['source'], 'source_sha256': job['source_sha256'],
            'materials': materials, 'shiny_srgb': spec['shiny_srgb'],
            'output': str(output), 'references': refs, 'recipe_sha256': sha(HERE/'remaining_colour_recipe.json')}
        job_path = output/'job.json'
        if not (output/'bake.json').exists():
            write(job_path, bake_job)
            run_flatpak(HERE/'remaining_colour_bake.py', job_path,
                        [(OLD, ':ro'), (HERE, ':ro'), (WORK, '')], output/'bake.log')
        receipt = read(output/'bake.json')
        assert read(job_path) == bake_job and receipt['job_sha256'] == sha(job_path)
        assert receipt['worker_sha256'] == sha(HERE/'remaining_colour_bake.py')
        textures = {(r['material'], r['variant'], r['channel']): r for r in receipt['textures']}
        for r in textures.values(): assert sha(r['path']) == r['sha256']
        for name in names:
            source = OLD/'legacy-export'/name/'model.glb'
            exported = read(source.with_name('export.json'))
            assert sha(source) == exported['glb_sha256']
            pair = []
            for variant in ('normal', 'shiny'):
                doc, binary = chunks(source)
                if not doc.get('samplers'): doc['samplers'] = [{}]
                for m in doc['materials']:
                    label = m['name']
                    def texture(channel):
                        r = textures[label, variant if channel == 'albedo' else 'normal', channel]
                        return Image.open(r['path']).convert('RGBA')
                    albedo = texture('albedo'); albedo.putalpha(texture('alpha').getchannel('R'))
                    orm = Image.merge('RGB', (Image.new('L', albedo.size, 255),
                                             texture('roughness').getchannel('R'), texture('metallic').getchannel('R')))
                    m.clear(); m['name'] = label
                    m['pbrMetallicRoughness'] = {'baseColorFactor': [1, 1, 1, 1],
                        'baseColorTexture': {'index': append_png(doc, binary, png(albedo), label+'-albedo', 0)},
                        'metallicFactor': 1, 'roughnessFactor': 1,
                        'metallicRoughnessTexture': {'index': append_png(doc, binary, png(orm), label+'-orm', 0)}}
                    m['normalTexture'] = {'index': append_png(doc, binary, png(texture('normal')), label+'-normal', 0)}
                    if albedo.getchannel('A').getextrema() != (255, 255): m['alphaMode'] = 'BLEND'
                target = WORK/'models'/name/variant/'model.glb'; target.parent.mkdir(parents=True, exist_ok=True)
                write_glb(target, doc, binary)
                proof = compare(source, target); pair.append(target)
                entries.append({'species': name+('-shiny' if variant == 'shiny' else ''),
                    'base_species': name, 'variant': variant, 'runtime_approved': False,
                    'path': str(target), 'glb_sha256': sha(target), 'animations': exported['animations'],
                    'source_glb': str(source), 'source_glb_sha256': sha(source),
                    'geometry_motion_signature': proof, 'bake_receipt_sha256': sha(output/'bake.json'),
                    'material_limitations': 'Archived normal graph; shiny mask palettes are an explicit visual reconstruction pending review.'})
            compare(*pair)
    write(WORK/'colour-stage.json', {'runtime_approved': False, 'entries': entries,
        'recipe_sha256': sha(HERE/'remaining_colour_recipe.json')})
    print('COLOUR_PREVIEW_GLB_BUILT', len(entries), flush=True)


if __name__ == '__main__':
    build()
