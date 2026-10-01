"""Review-only shiny Paras: retain source pink mushrooms, adapt orange skin."""
import argparse
import colorsys
import io
import json
from PIL import Image
from pathlib import Path
from catalog_remaining_paras_normal_review import ROOT, SOURCE_HASH, sha
from catalog_remaining_eye_bake import append_png, chunks, write_glb
from phase5_variant_parity import compare


def build(output):
    source = ROOT / '.tmp/remaining-142-production/native-transparent-v4/paras/model.glb'
    reference = ROOT / 'assets/sprites/pokemon/pokemon_home_shiny/paras.png'
    if sha(source) != SOURCE_HASH or output.exists():
        raise ValueError('Pinned source changed or output occupied')
    doc, original_binary = chunks(source)
    material = next(m for m in doc['materials'] if m['name'] == 'BodyA00')
    texture_info = material['pbrMetallicRoughness']['baseColorTexture']
    texture = doc['textures'][texture_info['index']]
    view = doc['bufferViews'][doc['images'][texture['source']]['bufferView']]
    start = view.get('byteOffset', 0)
    original = Image.open(io.BytesIO(original_binary[start:start + view['byteLength']])).convert('RGBA')
    if original.size != (512, 512):
        raise ValueError('Source atlas layout changed')
    image = original.copy()
    count = 0
    for y in range(190, 512):
        for x in range(512):
            red, green, blue, alpha = original.getpixel((x, y))
            h, saturation, value = colorsys.rgb_to_hsv(red/255, green/255, blue/255)
            if .055 < h < .145 and saturation > .22:
                rgb = tuple(round(z*255) for z in colorsys.hsv_to_rgb(
                    .033, min(1, saturation*1.4), value*.94))
                image.putpixel((x, y), (*rgb, alpha))
                count += 1
    assert count > 0
    assert image.getchannel('A').tobytes() == original.getchannel('A').tobytes()
    assert image.crop((0, 0, 512, 190)).tobytes() == original.crop((0, 0, 512, 190)).tobytes()
    binary = bytearray(original_binary)
    png = io.BytesIO()
    image.save(png, 'PNG')
    texture_info['index'] = append_png(doc, binary, png.getvalue(),
                                      'paras_authored_shiny_skin_review', texture.get('sampler', 0))
    output.mkdir(parents=True)
    target = output / 'model.glb'
    write_glb(target, doc, binary)
    receipt = {'species': 'paras', 'variant': 'shiny', 'runtime_approved': False,
               'appearance_approved': False, 'method': 'authored-local-home-reference-shiny-palette-v1',
               'source_glb_sha256': SOURCE_HASH, 'glb_sha256': sha(target),
               'reference_sha256': sha(reference), 'worker_sha256': sha(Path(__file__)),
               'changed_skin_pixels': count, 'alpha_unchanged': True,
               'mushroom_strip_unchanged': True, 'geometry_motion_sha256': compare(source, target)}
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    print(json.dumps(build(parser.parse_args().output.resolve())))
