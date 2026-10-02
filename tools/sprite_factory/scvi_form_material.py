"""Read mesh-bound Ogerpon form palettes from native TRMMT embedded TRACM.

Schema: pkZukan/PokeDocs SV/Flatbuffers/model/trmmt.fbs and
animation/tracm.fbs. The four authored samples select mask variants; these
are not skeletal animation seconds. Callers must supply the selected index.
"""
import math
from pathlib import Path
import struct

from scvi_tracm import _Buffer


def sample(keys, index):
    if not keys or any(not math.isfinite(v) for pair in keys for v in pair):
        raise ValueError('Invalid palette channel')
    if any(a[0] >= b[0] for a, b in zip(keys, keys[1:])):
        raise ValueError('Palette keys are not strictly ordered')
    if not keys[0][0] <= index <= keys[-1][0]:
        raise ValueError('Palette index outside authored channel')
    for time, value in keys:
        if time == index:
            return value
    # These are discrete form slots. Sparse channels retain their previous
    # value; blending toward a later mask invents lavender Wellspring fur.
    for (a, x), (b, y) in zip(keys, keys[1:]):
        if a < index < b:
            return x
    raise ValueError('No palette sample')


def palette(path, variant, index):
    if variant not in ('normal', 'rare') or index not in (1, 2, 3):
        raise ValueError('Unsupported Ogerpon form selector')
    if Path(path).name != f'pm1120_{11 + index}_00.trmmt':
        raise ValueError('Palette selector does not match Ogerpon form identity')
    view = _Buffer(Path(path).read_bytes())
    variants = [v for v in view.tables(view.u32(0), 2)
                if view.string(v, 0) == variant]
    if len(variants) != 1:
        raise ValueError('Missing or ambiguous variant')
    result = []
    for prop in view.tables(variants[0], 3):
        if view.string(prop, 0) != 'color':
            continue
        mappers = {tuple(view.string(m, i) for i in range(3))
                   for m in view.tables(prop, 1)}
        embedded = view.pointer(prop, 4)
        vector = view.pointer(embedded, 0)
        track = _Buffer(view.data[vector + 4:vector + 4 + view.u32(vector)])
        for row in track.tables(track.u32(0), 1):
            mesh = track.string(row, 0)
            for material in track.tables(track.pointer(row, 4), 2):
                name = track.string(material, 0)
                for animation in track.tables(material, 2):
                    key = track.string(animation, 0)
                    if (mesh, name, key) not in mappers:
                        raise ValueError('Unmapped material palette')
                    channels = track.pointer(animation, 1)
                    rgba = []
                    for channel in range(4):
                        values = track.pointer(channels, channel)
                        keys = [tuple(track.scalar(v, i, lambda o:
                            struct.unpack_from('<f', track.data, o)[0])
                            for i in (0, 1)) for v in track.tables(values, 0)]
                        rgba.append(sample(keys, index))
                    result.append({'mesh': mesh, 'material': name,
                                   'key': key, 'value': rgba})
    if len(result) != 7:
        raise ValueError('Expected seven Ogerpon mesh/layer bindings')
    return result
