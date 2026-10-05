#!/usr/bin/env python3
"""Validate inspected SV inputs and reproducible runtime subsets for ten moves."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import tempfile
from extract_sv_ember import inspect_particle, legacy_bntx, read
from package_sv_fire_bubbles import package
from sv_batch_four import PARTS, FORMAT_FLAGS, TEXTURES

COUNTS = dict(shadowball=20, sludgebomb=15, focusblast=34, moonblast=33,
              iceshard=11, poisonsting=12, swift=17, flashcannon=33,
              magicalleaf=26, waterpulse=22)


def rejected(data, flags):
    try:
        legacy_bntx(data, **flags)
    except ValueError:
        return
    raise AssertionError('Unsupported format/swizzle accepted')


def check(source, extracted):
    for move, parts in PARTS.items():
        emitters = 0
        manifest = json.loads((extracted / move / 'manifest.json').read_text())
        for stem in parts:
            path = source / stem.split('_')[0] / (stem + '.ptcl')
            raw = path.read_bytes()
            parsed, bntx = inspect_particle(raw)
            emitters += len(parsed['emitters'])
            assert len(legacy_bntx(bntx, **FORMAT_FLAGS[move])) == len(bntx)
            assert hashlib.sha256(raw).hexdigest() == manifest['parts'][stem]['source_sha256']
            pos = read(bntx, read(bntx, 40, 'Q')[0], 'Q')[0]
            bad = bytearray(bntx)
            struct.pack_into('<I', bad, pos + 28, 0xFFFF)
            rejected(bad, FORMAT_FLAGS[move])
            bad = bytearray(bntx)
            bad[pos + 88] = 0
            rejected(bad, FORMAT_FLAGS[move])
            assert path.read_bytes() == raw
        assert emitters == COUNTS[move]
        with tempfile.TemporaryDirectory() as output:
            package(extracted / move, Path(output))
            report = json.loads((Path(output) / 'provenance.json').read_text())
            assert len(report['textures']) == sum(map(len, TEXTURES[move].values()))
            tracked = Path('assets/battles/moves_3d') / ('sv_' + move)
            assert report == json.loads((tracked / 'provenance.json').read_text())
            for texture in report['textures']:
                png = (Path(output) / texture['file']).read_bytes()
                assert hashlib.sha256(png).hexdigest() == texture['png_sha256']
                assert png == (tracked / texture['file']).read_bytes()
        print('BATCH_FOUR_SOURCE_OK move=%s emitters=%d immutable=true guards=true reproducible=true' % (move, emitters))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--extracted', type=Path, required=True)
    args = parser.parse_args()
    check(args.source, args.extracted)
