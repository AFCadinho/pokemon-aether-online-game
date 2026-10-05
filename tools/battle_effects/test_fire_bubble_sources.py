#!/usr/bin/env python3
"""Check the new bounded format opt-ins and packaged fire/bubble assets."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import tempfile
from extract_sv_ember import inspect_particle, legacy_bntx, read, MOVE_PARTS
from package_sv_fire_bubbles import package


def rejected(raw, **flags):
    try:
        legacy_bntx(raw, **flags)
    except ValueError:
        return
    raise AssertionError('Unsupported format/swizzle accepted')


def check(root, extracted):
    for move, effect_id, count in [('flamethrower', 'ew0053', 32), ('bubblebeam', 'ew0061', 24)]:
        emitters = 0
        extras = 0
        for stem in MOVE_PARTS[move]:
            path = root / effect_id / (stem + '.ptcl')
            raw = path.read_bytes()
            parsed, bntx = inspect_particle(raw)
            emitters += len(parsed['emitters'])
            flags = dict(allow_bc3=True, allow_bc5=True,
                         allow_r8=move == 'flamethrower', allow_bc7=move == 'bubblebeam')
            assert len(legacy_bntx(bntx, **flags)) == len(bntx)
            for i in range(read(bntx, 36, 'I')[0]):
                pos = read(bntx, read(bntx, 40, 'Q')[0] + i * 8, 'Q')[0]
                if read(bntx, pos + 28, 'I')[0] not in (0x0201, 0x2006):
                    continue
                extras += 1
                rejected(bntx, allow_bc3=True, allow_bc5=True)
                broken = bytearray(bntx)
                struct.pack_into('<I', broken, pos + 28, 0xFFFF)
                rejected(broken, **flags)
                broken = bytearray(bntx)
                broken[pos + 88] = 0
                rejected(broken, **flags)
            assert path.read_bytes() == raw
        assert emitters == count and extras > 0
        # Decode output must match the selected source formats; packaging is reproducible.
        with tempfile.TemporaryDirectory() as output:
            package(extracted / move, Path(output))
            report = json.loads((Path(output) / 'provenance.json').read_text())
            folder = 'sv_flamethrower' if move == 'flamethrower' else 'sv_bubbles'
            for texture in report['textures']:
                png = (Path(output) / texture['file']).read_bytes()
                assert hashlib.sha256(png).hexdigest() == texture['png_sha256']
                assert png == (Path('assets/battles/moves_3d') / folder / texture['file']).read_bytes()
        print('FIRE_BUBBLE_SOURCE_OK move=%s emitters=%d format_guards=true unchanged_sources=true reproducible=true' % (move, emitters))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True, help='SV effect/battle_ew')
    parser.add_argument('--extracted', type=Path, required=True)
    args = parser.parse_args()
    check(args.source, args.extracted)
