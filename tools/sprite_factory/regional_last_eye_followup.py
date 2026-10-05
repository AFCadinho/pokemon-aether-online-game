"""Review proposals for Alola-cap Pikachu and Hisuian Typhlosion only.

Pikachu's source requests a fifth, white highlight layer but contains no
highlight bitmap. Bake a small static specular lobe from its convex eye normal
map as a portable approximation, not an assertion of shader equivalence.
Typhlosion retains its default neutral gaze in idle only: the imported idle
offsets move its pupils behind the eyelids. Other expressions stay authored.
"""
import copy
import json
import math
from io import BytesIO
from pathlib import Path

from PIL import Image

from catalog_galar_birds_candidates import sha
from catalog_remaining_eye_audit import embedded_image
from catalog_remaining_eye_bake import append_png, chunks, write_glb
from phase5_variant_parity import signature
from scvi_material_probe import inspect_materials

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.tmp/regional-production-v1'


def highlight(normal):
    half_vector = [-.35, .5, .79]
    length = math.sqrt(sum(v*v for v in half_vector))
    half_vector = [v/length for v in half_vector]
    pixels = []
    for pixel in normal.convert('RGB').getdata():
        vector = [v/127.5-1 for v in pixel]
        length = max(math.sqrt(sum(v*v for v in vector)), 1e-6)
        vector = [v/length for v in vector]
        dot = sum(a*b for a,b in zip(vector, half_vector))
        t = min(1, max(0, (dot-.955)/.027))
        # Suppress the flat normal outside the authored convex eye footprint.
        if math.hypot(*vector[:2]) < .1:
            t = 0
        pixels.append(round(255*t*t*(3-2*t)))
    mask = Image.new('L', normal.size)
    mask.putdata(pixels)
    return mask


def main():
    out = WORK / 'eye-last-two-v2'
    out.mkdir(exist_ok=False)
    current = json.loads((WORK / 'runtime-final-v3.json').read_text())
    table = WORK / 'shared-source/pm0025/pm0025_16_00/pm0025_16_00.trmtr'
    official = {r['name']: r for r in inspect_materials(table)}
    stage, proof = [], []
    for original in current:
        species = original['species']
        base = species.removesuffix('-shiny')
        if base not in {'pikachu-alola', 'typhlosion-hisui'}:
            continue
        row = copy.deepcopy(original)
        path = Path(row['path'])
        assert sha(path) == row['glb_sha256']
        doc, data = chunks(path)
        binary = bytearray(data)
        before = copy.deepcopy(doc['materials'])
        changes = []
        if base == 'pikachu-alola':
            for mat in doc['materials']:
                if mat['name'] not in {'l_eye', 'r_eye'}:
                    continue
                src = official[mat['name']]
                assert any(s['values'].get('EnableHighlight') == 'True' for s in src['shaders'])
                assert src['colors']['EmissionColorLayer5'] == [1, 1, 1, 1]
                assert src['floats']['EmissionIntensityLayer5'] > 0
                normal_path = (table.parent / Path(src['textures']['NormalMap1']).with_suffix('.png')).resolve()
                mask = highlight(Image.open(normal_path))
                for owner, key in [(mat['pbrMetallicRoughness'], 'baseColorTexture'), (mat, 'emissiveTexture')]:
                    old = embedded_image(doc, binary, owner[key]['index']).convert('RGBA')
                    glint = mask.resize(old.size, Image.Resampling.LANCZOS)
                    changed = Image.composite(Image.new('RGBA', old.size, 'white'), old, glint)
                    packed = BytesIO()
                    changed.save(packed, format='PNG')
                    owner[key] = {'index': append_png(doc, binary, packed.getvalue(), mat['name'] + '_portable_glint_' + key, 0)}
                changes.append({'material': mat['name'], 'proposal': 'static_source_normal_glint_approximation',
                                'normal_sha256': sha(normal_path), 'material_table_sha256': sha(table)})
        else:
            for spec in row['eye_motion']['materials']:
                old = copy.deepcopy(spec['clips']['idle']['parameters']['UVScaleOffset'])
                neutral = spec['defaults']['UVScaleOffset']
                assert neutral == [1, 1, 0, 0]
                for key in spec['clips']['idle']['parameters']['UVScaleOffset']:
                    key[1] = list(neutral)
                changes.append({'material': spec['material'], 'proposal': 'neutral_idle_gaze', 'old_idle_keys': old})
            # No GLB material or skeletal animation change for Typhlosion.
            assert doc['materials'] == before
        target = out / (species + '.glb')
        write_glb(target, doc, binary)
        assert signature(target) == signature(path)
        assert all(a == b for a, b in zip(before, doc['materials']) if a['name'] not in {'l_eye', 'r_eye'})
        row['path'], row['glb_sha256'] = str(target), sha(target)
        for key in ['eye_motion', 'visibility']:
            if key in row:
                row[key]['glb_sha256'] = sha(target)
        for key in ['runtime_path', 'runtime_sha256']:
            row.pop(key, None)
        row['last_eye_followup'] = {'input_sha256': sha(path), 'changes': changes, 'visual_approval_required': True}
        proof.append({'species': species, 'geometry_motion_sha256': signature(target), 'body_materials_unchanged': True})
        stage.append(row)
    assert len(stage) == 4
    (out / 'stage.json').write_text(json.dumps(stage, indent=2) + '\n')
    (out / 'source-proof.json').write_text(json.dumps(proof, indent=2) + '\n')
    print(out / 'stage.json')


if __name__ == '__main__':
    main()
