#!/usr/bin/env python3
"""Extract the bounded Ember/Water Gun VFXB v22 pilots, not a general particle converter.

Format references and limitations: docs/3d/ember-sv-effect-pilot.md.
BNTX decoding runs an explicitly supplied external BNTX-Extractor checkout.
No game files or third-party executable code are downloaded by this script.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import subprocess
import sys

NULL = 0xFFFFFFFF
PARTS = ('ew0052_fire_muzzle', 'ew0052_bullet', 'ew0052_hit')
MOVE_PARTS = {'ember': PARTS, 'watergun': ('ew0055_muzzle01', 'ew0055_shot01', 'ew0055_hit01')}


def read(data, pos, fmt):
    if pos < 0 or pos + struct.calcsize('<' + fmt) > len(data):
        raise ValueError('Offset outside source buffer')
    return struct.unpack_from('<' + fmt, data, pos)


def text(data, pos, size):
    if pos < 0 or pos + size > len(data):
        raise ValueError('String outside source buffer')
    return data[pos:pos + size].split(b'\0', 1)[0].decode('ascii')


def sections(data):
    if data[:8] != b'VFXB    ' or read(data, 12, 'H')[0] != 0xFEFF:
        raise ValueError('Expected little-endian VFXB')
    if read(data, 10, 'H')[0] != 22:
        raise ValueError('Only the inspected SV VFX version 22 is supported')
    if read(data, 28, 'I')[0] != len(data):
        raise ValueError('VFXB file length mismatch')
    seen = set()

    def visit(pos, count=None, parent=None):
        remaining = count
        while remaining is None or remaining > 0:
            if pos in seen or len(seen) > 512:
                raise ValueError('Cyclic or excessive section graph')
            seen.add(pos)
            magic, size, child, nxt, _, payload, _, children = read(data, pos, '4s7I')
            if not re.fullmatch(rb'[A-Z0-9]{4}', magic) or size > len(data) or children > 128:
                raise ValueError('Invalid VFXB section')
            row = dict(magic=magic.decode(), offset=pos, size=size, payload=payload, parent=parent)
            yield row
            if children and child != NULL:
                if child < 32:
                    raise ValueError('Invalid child section offset')
                yield from visit(pos + child, children, pos)
            if remaining is not None:
                remaining -= 1
                if remaining == 0:
                    break
            if nxt == NULL:
                if remaining is not None and remaining > 0:
                    raise ValueError('Section count mismatch')
                break
            if nxt < 32:
                raise ValueError('Invalid next section offset')
            pos += nxt

    return list(visit(read(data, 22, 'H')[0]))


def inspect_particle(data):
    rows = sections(data)
    names = {}
    bntx = None
    for row in rows:
        pos = row['offset'] + row['payload']
        if row['magic'] == 'GRTF':
            size = read(data, pos + 28, 'I')[0]
            if data[pos:pos + 8] != b'BNTX\0\0\0\0' or size > len(data) - pos:
                raise ValueError('Invalid embedded BNTX')
            bntx = data[pos:pos + size]
        if row['magic'] == 'GTNT':
            end = pos + row['size']
            while pos < end:
                key, nxt, length = read(data, pos, 'QII')
                name = text(data, pos + 16, length)
                if not re.fullmatch(r'[a-zA-Z0-9_]+', name):
                    raise ValueError('Unsafe texture name')
                names[key] = name
                if nxt == 0:
                    break
                if nxt < 16 or pos + nxt > end:
                    raise ValueError('Invalid texture descriptor offset')
                pos += nxt
    emitters = []
    for row in rows:
        if row['magic'] != 'EMTR':
            continue
        pos = row['offset'] + row['payload']
        base = pos + 80
        colors = list(read(data, base + 2384, '8f'))
        curves = [list(read(data, base + 880 + i * 128, '32f')) for i in range(4)]
        if not all(math.isfinite(v) for v in colors + sum(curves, [])):
            raise ValueError('Non-finite emitter colors')
        samplers = [read(data, base + 2464 + i * 32, 'Q')[0] for i in range(3)]
        if any(key != 0xFFFFFFFFFFFFFFFF and key not in names for key in samplers):
            raise ValueError('Unresolved emitter texture binding')
        emitters.append(dict(name=text(data, pos + 16, 64), offset=row['offset'],
                             parent_offset=row['parent'], colors=colors,
                             color_key_counts=list(read(data, base + 16, '4I')),
                             color_curves=curves,
                             textures=[names.get(key, '') for key in samplers]))
    if bntx is None or not emitters:
        raise ValueError('Missing Ember emitters/textures')
    return dict(emitters=emitters, sections=rows), bntx


def legacy_bntx(data, allow_bc5=False):
    """Adapt BRTI flags/tile enum for external BNTX-Extractor 0.6 only.

    Current struct: flags:u8, dim:u8, tile:u16. Old extractor reads
    tile:u8, dim:u8, flags:u16 and uses the opposite tile enum.
    Retain source BNTX byte-for-byte in the output; modify only a decode copy.
    """
    if data[:8] != b'BNTX\0\0\0\0' or read(data, 12, 'H')[0] != 0xFEFF:
        raise ValueError('Expected little-endian BNTX')
    out = bytearray(data)
    count = read(data, 36, 'I')[0]
    table = read(data, 40, 'Q')[0]
    if not 1 <= count <= 32:
        raise ValueError('Unexpected texture count')
    for i in range(count):
        pos = read(data, table + 8 * i, 'Q')[0]
        if data[pos:pos + 4] != b'BRTI':
            raise ValueError('Missing BRTI')
        flags, dim, tile = read(data, pos + 16, 'BBH')
        fmt = read(data, pos + 28, 'I')[0]
        channels = read(data, pos + 88, '4B')
        supported = fmt == 0x1D01 and channels == (2, 2, 2, 2)
        supported |= allow_bc5 and fmt == 0x1E01 and channels in ((2, 2, 2, 3), (2, 3, 3, 3))
        if tile not in (0, 1) or dim != 2 or not supported:
            raise ValueError('Unsupported pilot texture format/swizzle/tile mode')
        struct.pack_into('<BBH', out, pos + 16, 1 - tile, dim, flags)
    return out


def extract(source, output, decoder, move="ember"):
    from PIL import Image
    if output.exists():
        raise ValueError('Output directory must be new (source files are never overwritten)')
    decoder = decoder.resolve()
    if not decoder.is_file():
        raise ValueError('Supply external bntx_extract.py with its dds.py and swizzle.py siblings')
    # Inspect every source before producing output.
    inspected = [(stem, (source / (stem + '.ptcl')).read_bytes()) for stem in MOVE_PARTS[move]]
    parsed = [(stem, raw, *inspect_particle(raw)) for stem, raw in inspected]
    manifest = dict(schema=1, move=move, conversion='partial-textures-and-colors',
                    native_timeline_converted=False, native_simulation_converted=False,
                    decoder_sha256=hashlib.sha256(decoder.read_bytes()).hexdigest(), parts={})
    output.mkdir(parents=True)
    for stem, raw, info, bntx in parsed:
        folder = output / stem
        folder.mkdir()
        (folder / 'source.bntx').write_bytes(bntx)
        legacy = folder / 'decoder-input.bntx'
        legacy.write_bytes(legacy_bntx(bntx, allow_bc5=move == "watergun"))
        run = subprocess.run([sys.executable, str(decoder), str(legacy.resolve())],
                             cwd=folder, capture_output=True, text=True, timeout=60)
        (folder / 'decoder.log').write_text(run.stdout + run.stderr)
        if run.returncode:
            raise ValueError('Texture decoder failed; see ' + str(folder / 'decoder.log'))
        textures = sorted({name for e in info['emitters'] for name in e['textures'] if name})
        metadata = {}
        for i in range(read(bntx, 36, 'I')[0]):
            pos = read(bntx, read(bntx, 40, 'Q')[0] + i * 8, 'Q')[0]
            name_pos = read(bntx, pos + 96, 'Q')[0]
            name = text(bntx, name_pos + 2, read(bntx, name_pos, 'H')[0])
            metadata[name] = {'format': read(bntx, pos + 28, 'I')[0],
                              'channels': read(bntx, pos + 88, '4B')}
        for name in textures:
            image = Image.open(folder / (name + '.dds'))
            meta = metadata[name]
            if meta['format'] == 0x1D01:
                if image.mode != 'L':
                    raise ValueError('Unexpected decoded BC4 image mode')
            else:
                if image.mode != 'RGB':
                    raise ValueError('Unexpected decoded BC5 image mode')
                red, green, _ = image.split()
                channels = {2: red, 3: green}
                image = Image.merge('RGBA', [channels[c] for c in meta['channels']])
            image.save(folder / (name + '.png'))
        info['texture_metadata'] = metadata
        info.update(source_sha256=hashlib.sha256(raw).hexdigest(), textures=textures)
        manifest['parts'][stem] = info
    effect_id = MOVE_PARTS[move][0].split('_')[0]
    timeline = (source / (effect_id + '.trtml')).read_bytes()
    manifest['timeline'] = dict(source_sha256=hashlib.sha256(timeline).hexdigest(),
                               audio_event_names=sorted({s.decode() for s in re.findall(('PLAY_' + effect_id.upper() + r'_\d+').encode(), timeline)}),
                               note='String inventory only; event timing not decoded.')
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(dict(output=str(output), emitters=sum(len(p['emitters']) for p in manifest['parts'].values()),
                          textures=sum(len(p['textures']) for p in manifest['parts'].values()),
                          full_animation_converted=False)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True, help='SV romfs/effect/battle_ew/ew0052')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--move', choices=sorted(MOVE_PARTS), default='ember')
    parser.add_argument('--bntx-extractor', type=Path, required=True)
    args = parser.parse_args()
    try:
        extract(args.source, args.output, args.bntx_extractor, args.move)
    except (ValueError, OSError, struct.error) as exc:
        parser.exit(1, str(exc) + '\n')
