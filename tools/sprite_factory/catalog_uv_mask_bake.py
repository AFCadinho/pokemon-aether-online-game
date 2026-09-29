"""Review-only UV2 mask bake onto an unchanged glTF UV1 atlas.

Rejects ambiguous overlapping samples and empty output. Integer atlas repeats
are preserved. This reconstructs a static material mask, not animated UVs or
full native shading. Callers must pin source files and visually review results.
"""
import math
import struct
from PIL import Image

def accessor(d, b, i):
    a = d['accessors'][i]
    if 'sparse' in a or a.get('normalized', False):
        raise ValueError('Unsupported sparse or normalized source accessor')
    v = d['bufferViews'][a['bufferView']]
    if v.get('buffer', 0) != 0:
        raise ValueError('External source buffer is unsupported')
    count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    fmt = {5126: 'f', 5123: 'H', 5125: 'I', 5121: 'B'}[a['componentType']]
    size = struct.calcsize(fmt) * count
    off = v.get('byteOffset', 0) + a.get('byteOffset', 0)
    return [struct.unpack_from('<' + fmt * count, b, off + j * v.get('byteStride', size)) for j in range(a['count'])]

def raster(d, b, material, im, scale, N=512, padding=0):
    if not isinstance(N, int) or N < 1 or N > 4096 or len(scale) != 4 or (not all((math.isfinite(x) for x in scale))):
        raise ValueError('Invalid bake size or source UV transform')
    if im.mode != 'RGBA':
        raise ValueError('Mask must retain four independent RGBA data channels')
    out = Image.new('RGBA', (N, N))
    pix = out.load()
    src = im.load()
    seen = {}
    conflicts = 0
    visits = 0
    for mesh in d['meshes']:
        for p in mesh['primitives']:
            if p['material'] != material:
                continue
            if p.get('mode', 4) != 4 or not {'TEXCOORD_0', 'TEXCOORD_1'} <= p['attributes'].keys():
                raise ValueError('UV bake requires triangles and both source UV sets')
            uv0 = accessor(d, b, p['attributes']['TEXCOORD_0'])
            if not uv0 or not all(len(v) == 2 and all(math.isfinite(x) for x in v) for v in uv0):
                raise ValueError('Invalid base UV coordinates')
            shift = [math.floor(min((v[j] for v in uv0))) for j in [0, 1]]
            uv0 = [tuple((v[j] - shift[j] for j in [0, 1])) for v in uv0]
            uv1 = accessor(d, b, p['attributes']['TEXCOORD_1'])
            if len(uv1) != len(uv0) or any(len(v) != 2 for v in uv1):
                raise ValueError('Source UV sets differ in size or shape')
            if not all((math.isfinite(x) for uv in uv0 + uv1 for x in uv)) or any((max((v[j] for v in uv0)) > 1.00001 for j in [0, 1])):
                raise ValueError('UV bake requires one finite base atlas tile')
            indices = [x[0] for x in accessor(d, b, p['indices'])]
            if len(indices) % 3 or any(not isinstance(i, int) or i < 0 or i >= len(uv0) for i in indices):
                raise ValueError('Invalid source triangle indices')
            for k in range(0, len(indices), 3):
                ids = indices[k:k + 3]
                pts = [(uv0[i][0] * N, uv0[i][1] * N) for i in ids]
                a, c, e = pts
                det = (c[1] - e[1]) * (a[0] - e[0]) + (e[0] - c[0]) * (a[1] - e[1])
                if abs(det) < 1e-08:
                    continue
                for y in range(max(0, math.floor(min((t[1] for t in pts)))), min(N, math.ceil(max((t[1] for t in pts))))):
                    for x in range(max(0, math.floor(min((t[0] for t in pts)))), min(N, math.ceil(max((t[0] for t in pts))))):
                        w0 = ((c[1] - e[1]) * (x + 0.5 - e[0]) + (e[0] - c[0]) * (y + 0.5 - e[1])) / det
                        w1 = ((e[1] - a[1]) * (x + 0.5 - e[0]) + (a[0] - e[0]) * (y + 0.5 - e[1])) / det
                        w2 = 1 - w0 - w1
                        if min(w0, w1, w2) < -1e-06:
                            continue
                        u = sum((w * uv1[i][0] for w, i in zip([w0, w1, w2], ids)))
                        v = sum((w * uv1[i][1] for w, i in zip([w0, w1, w2], ids)))
                        u = u * scale[0] + scale[2]
                        v = v * scale[1] - scale[3]
                        val = src[int(u % 1 * im.width) % im.width, int(v % 1 * im.height) % im.height]
                        key = (x, y)
                        if key in seen and max((abs(a - b) for a, b in zip(seen[key], val))) > 10:
                            conflicts += 1
                        seen[key] = val
                        pix[x, y] = val
                        visits += 1
    if not seen:
        raise ValueError('UV bake covered no pixels')
    if conflicts:
        raise ValueError('Overlapping UVs require conflicting source mask samples')
    covered = len(seen)
    if not isinstance(padding, int) or padding < 0 or padding > 32:
        raise ValueError('Invalid atlas padding')
    frontier = seen
    for _ in range(padding):
        extra = {}
        for (x, y), value in frontier.items():
            for xx, yy in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                if 0 <= xx < N and 0 <= yy < N and (xx, yy) not in seen and (xx, yy) not in extra:
                    extra[xx, yy] = value
                    pix[xx, yy] = value
        seen.update(extra)
        frontier = extra
    return (out, {'covered_pixels': covered, 'sample_visits': visits, 'conflicts': conflicts, 'padding_pixels': len(seen)-covered})
