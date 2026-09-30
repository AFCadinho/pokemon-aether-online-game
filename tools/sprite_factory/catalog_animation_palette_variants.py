"""Create source-pinned authored palette candidates; never grant approval.

Explicit per-material RGB anchors come from reviewed local colour references.
Geometry, animations, alpha and materials without rules remain unchanged.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import math
from functools import lru_cache
from PIL import Image
from catalog_remaining_shiny_glb import read_glb
from catalog_remaining_eye_bake import append_png, write_glb
from phase5_variant_parity import compare


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def recolour(image, rules):
    for rule in rules:
        for key in ('from', 'to'):
            if len(rule[key]) != 3 or any(not math.isfinite(v) or not 0 <= v <= 255 for v in rule[key]):
                raise ValueError('Valid RGB anchors required')
        if not any(rule['from']) or not 0 < rule['tolerance'] <= 100:
            raise ValueError('Invalid source anchor or tolerance')

    @lru_cache(maxsize=65536)
    def pixel(rgba):
        rgb = rgba[:3]
        rule = min(rules, key=lambda r: sum((a-b)**2 for a,b in zip(rgb,r['from'])))
        source = rule['from']
        distance = sum((a-b)**2 for a,b in zip(rgb,source))
        if distance > rule['tolerance']**2:
            return rgba
        shade = sum(a*b for a,b in zip(rgb,source)) / sum(v*v for v in source)
        return (*[min(255,max(0,round(v*shade))) for v in rule['to']], rgba[3])

    data = image.convert('RGBA')
    output = Image.new('RGBA',data.size)
    output.putdata([pixel(p) for p in data.get_flattened_data()])
    return output



def build(job):
    source, target = Path(job['source']), Path(job['output'])
    if sha(source) != job['source_sha256'] or target.exists():
        raise ValueError('Source changed or output occupied')
    for reference in job['references']:
        if sha(reference['path']) != reference['sha256']:
            raise ValueError('Colour reference changed')
    doc, original = read_glb(source)
    binary = bytearray(original)
    materials = {m['name']: m for m in doc['materials']}
    if not set(job['materials']) <= materials.keys():
        raise ValueError('Unknown material palette binding')
    changes = []
    for name, rules in job['materials'].items():
        material = materials[name]
        info = material['pbrMetallicRoughness']['baseColorTexture']
        texture = doc['textures'][info['index']]
        view = doc['bufferViews'][doc['images'][texture['source']]['bufferView']]
        offset = view.get('byteOffset', 0)
        image = Image.open(io.BytesIO(original[offset:offset + view['byteLength']])).convert('RGBA')
        changed = recolour(image, rules)
        assert image.getchannel('A').tobytes() == changed.getchannel('A').tobytes()
        if image.tobytes() == changed.tobytes():
            raise ValueError('Palette matched no pixels: ' + name)
        png = io.BytesIO()
        changed.save(png, 'PNG')
        info['index'] = append_png(doc, binary, png.getvalue(), name + '_authored_shiny', texture.get('sampler', 0))
        changes.append({'material': name, 'png_sha256': hashlib.sha256(png.getvalue()).hexdigest()})
    if not changes:
        raise ValueError('No palette changes')
    target.parent.mkdir(parents=True, exist_ok=True)
    write_glb(target, doc, binary)
    result = {'species': job['species'], 'variant': 'shiny', 'source_sha256': job['source_sha256'],
              'glb_sha256': sha(target), 'geometry_motion_sha256': compare(source, target),
              'policy': 'authored-local-home-reference-palette-v1', 'changes': changes,
              'alpha_unchanged': True, 'runtime_approved': False}
    target.with_suffix('.receipt.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--jobs', type=Path, required=True)
    args = parser.parse_args()
    results = []
    for job in json.loads(args.jobs.read_text()):
        results.append(build(job))
        print(job['species'], 'authored shiny candidate', flush=True)
    args.jobs.with_suffix('.results.json').write_text(json.dumps(results, indent=2) + '\n')
