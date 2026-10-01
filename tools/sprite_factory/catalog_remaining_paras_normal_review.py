"""Pinned Paras normal palette proposal, requiring visual approval.

The Blend's embedded body texture has pink mushrooms and a pale body. This
authored colour adaptation uses the local normal HOME image as reference.
It is not an official recovered normal texture. Eyes, teeth, alpha, UVs,
geometry, skinning and animation data remain unchanged.
"""
import argparse
import colorsys
import hashlib
import io
import json
from pathlib import Path
from PIL import Image
from catalog_remaining_eye_bake import append_png, chunks, write_glb
from phase5_variant_parity import compare

ROOT = Path(__file__).resolve().parents[2]
SOURCE_HASH = '7bcd5125950e27f81b862823b7aa7e4afbd2935ef06c4cb2023c4723bf05eb51'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(output):
    source = ROOT / '.tmp/remaining-142-production/native-transparent-v4/paras/model.glb'
    reference = ROOT / 'assets/sprites/pokemon/pokemon_home/Paras.png'
    if sha(source) != SOURCE_HASH or output.exists():
        raise ValueError('Pinned source changed or output occupied')
    doc, binary = chunks(source)
    material = next(m for m in doc['materials'] if m['name'] == 'BodyA00')
    texture_info = material['pbrMetallicRoughness']['baseColorTexture']
    texture = doc['textures'][texture_info['index']]
    view = doc['bufferViews'][doc['images'][texture['source']]['bufferView']]
    start = view.get('byteOffset', 0)
    original = Image.open(io.BytesIO(binary[start:start + view['byteLength']])).convert('RGBA')
    if original.size != (512, 512):
        raise ValueError('Source atlas layout changed')
    changed = original.copy()
    counts = {'mushroom': 0, 'body': 0}
    for y in range(512):
        for x in range(512):
            r, g, b, alpha = original.getpixel((x, y))
            h, saturation, value = colorsys.rgb_to_hsv(r/255, g/255, b/255)
            if y < 190 and .72 < h < .98 and saturation > .12:
                h, saturation, value = .955, .91, value * .86
                counts['mushroom'] += 1
            elif y >= 190 and .055 < h < .145 and saturation > .22:
                h, saturation = .043, min(1, saturation * 1.65)
                counts['body'] += 1
            else:
                continue
            rgb = tuple(round(v * 255) for v in colorsys.hsv_to_rgb(h, saturation, value))
            changed.putpixel((x, y), (*rgb, alpha))
    assert all(counts.values())
    assert original.getchannel('A').tobytes() == changed.getchannel('A').tobytes()
    output.mkdir(parents=True)
    packed = io.BytesIO()
    changed.save(packed, 'PNG')
    binary = bytearray(binary)
    texture_info['index'] = append_png(doc, binary, packed.getvalue(),
                                      'paras_authored_normal_reference', texture.get('sampler', 0))
    target = output / 'model.glb'
    write_glb(target, doc, binary)
    receipt = {'species': 'paras', 'variant': 'normal', 'runtime_approved': False,
               'appearance_approved': False, 'method': 'authored-local-home-reference-normal-palette-v1',
               'limitation': 'Colour adaptation; original glass cover remains a reviewed-only approximation',
               'source_glb_sha256': SOURCE_HASH, 'glb_sha256': sha(target),
               'reference_sha256': sha(reference), 'worker_sha256': sha(Path(__file__)),
               'changed_pixels': counts, 'alpha_unchanged': True,
               'geometry_motion_sha256': compare(source, target)}
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    rows = json.loads((ROOT / 'tools/sprite_factory/catalog_remaining_142_checkpoint.json').read_text())['entries']
    row = next(r for r in rows if r['species'] == 'paras')
    row.update(path=str(target), glb_sha256=sha(target), status='normal_review_candidate')
    (output / 'stage.json').write_text(json.dumps([row], indent=2) + '\n')
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    print(json.dumps(build(parser.parse_args().output.resolve())))
