"""Compose closed source eye cells into a review texture, without altering meshes.

Only explicit idle-as-sleep aliases are considered. Reject missing/ambiguous
closed cells. This creates offline proposals, never runtime admission.
"""
from io import BytesIO
from pathlib import Path
from statistics import median
import hashlib
import json
from PIL import Image
from catalog_remaining_eye_bake import chunks


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def texture(doc, binary, material):
    info = material['pbrMetallicRoughness']['baseColorTexture']
    image = doc['images'][doc['textures'][info['index']]['source']]
    view = doc['bufferViews'][image['bufferView']]
    offset = view.get('byteOffset', 0)
    return Image.open(BytesIO(binary[offset:offset + view['byteLength']])).convert('RGBA'), info


def closed_cell(cell):
    pixels = list(cell.get_flattened_data())
    opaque = [p for p in pixels if p[3] > 200]
    if not opaque:
        return None
    white = sum(min(p[:3]) > 190 for p in opaque) / len(opaque)
    luminance = lambda p: .2126*p[0] + .7152*p[1] + .0722*p[2]
    level = median(luminance(p) for p in opaque)
    dark = [(i % cell.width, i // cell.width) for i,p in enumerate(pixels)
            if p[3] > 200 and luminance(p) < min(90, level*.60)]
    if len(dark) < len(pixels)*.005:
        return None
    xs, ys = zip(*dark)
    width, height = max(xs)-min(xs)+1, max(ys)-min(ys)+1
    # A closed horizontal/arched eyelid has neither a round pupil nor an
    # opaque flat placeholder. Wider masks remain held for explicit review.
    if width/height > 1.5 and height/cell.height < .35 and len(dark)/len(pixels) < .25:
        return white + .7*height/cell.height
    return None


def compose(source, original_export, receipt, output):
    doc, binary = chunks(source)
    old, old_binary = chunks(original_export)
    domains = {r['material']:r for r in receipt.get('native_uv_domains', [])}
    result = []
    for material in doc['materials']:
        name = material['name']
        if 'eye' not in name.lower() or name not in domains:
            continue
        image, _ = texture(doc, binary, material)
        original = next(m for m in old['materials'] if m['name'] == name)
        original_image, info = texture(old, old_binary, original)
        domain = domains[name]['source_uv_domain']
        scale = info.get('extensions', {}).get('KHR_texture_transform', {}).get('scale', [1,1])
        cols = round(2*scale[0]*(domain[2]-domain[0]))
        rows = round(2*original_image.height/original_image.width*scale[1]*(domain[3]-domain[1]))
        if not 1 <= cols <= 16 or not 2 <= rows <= 8:
            continue
        closed = Image.new('RGBA', image.size)
        chosen=[]
        for x in range(cols):
            cells=[image.crop((round(x*image.width/cols),round(y*image.height/rows),
                   round((x+1)*image.width/cols),round((y+1)*image.height/rows))) for y in range(rows)]
            candidates=[(score,y) for y,cell in enumerate(cells) if (score := closed_cell(cell)) is not None]
            if not candidates:
                break
            _,y=min(candidates);chosen.append({'column':x,'source_row':y})
            for row in range(rows):
                box=(round(x*image.width/cols),round(row*image.height/rows),
                     round((x+1)*image.width/cols),round((row+1)*image.height/rows))
                closed.paste(cells[y].resize((box[2]-box[0],box[3]-box[1])),box)
        if len(chosen) != cols:
            result.append({'material':name,'status':'held','reason':'No unambiguous closed eyelid in every source column'})
            continue
        path=output/(name+'.png');path.parent.mkdir(parents=True,exist_ok=True);closed.save(path)
        result.append({'material':name,'status':'closed_cell_proposal','path':str(path),
                       'sha256':sha(path),'source_glb_sha256':sha(source),
                       'source_cell_grid':[cols,rows],'chosen_cells':chosen,'runtime_approved':False})
    return result
