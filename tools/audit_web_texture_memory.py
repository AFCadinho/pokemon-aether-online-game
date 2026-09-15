#!/usr/bin/env python3
"""Read-only imported-texture inventory. Packed presence is NOT residency/RAM.

Read texture dimensions directly from the exported PCK, respecting importer
size limits. RGBA estimates exclude compression, mipmaps and driver overhead.
No resources are loaded into Godot, resized, removed or evicted.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]


def entries(stream):
    stream.seek(0, 2)
    end = stream.tell()
    stream.seek(0)
    header = stream.read(40)
    if len(header) != 40:
        raise ValueError('Truncated PCK header')
    magic, version = struct.unpack_from('<II', header)
    if magic != 0x43504447 or version not in (2, 3):
        raise ValueError('Unsupported PCK')
    if struct.unpack_from('<I', header, 20)[0] & 1:
        raise ValueError('Encrypted PCK directory')
    base = struct.unpack_from('<Q', header, 24)[0]
    directory = struct.unpack_from('<Q', header, 32)[0] if version == 3 else 96
    stream.seek(directory)
    count_bytes = stream.read(4)
    if len(count_bytes) != 4:
        raise ValueError('Truncated PCK directory')
    count, = struct.unpack('<I', count_bytes)
    if count > end // 40:
        raise ValueError('Invalid PCK entry count')
    result = []
    for _ in range(count):
        length_bytes = stream.read(4)
        if len(length_bytes) != 4:
            raise ValueError('Truncated PCK entry')
        length, = struct.unpack('<I', length_bytes)
        if not 0 < length <= 65536:
            raise ValueError('Invalid PCK path length')
        name = stream.read(length).rstrip(b'\0').decode('utf-8').removeprefix('res://')
        tail = stream.read(36)
        if len(tail) != 36:
            raise ValueError('Truncated PCK entry')
        offset, size = struct.unpack_from('<QQ', tail)
        flags, = struct.unpack_from('<I', tail, 32)
        if flags & 1 or base + offset + size > end:
            raise ValueError('Encrypted or out-of-bounds PCK payload')
        result.append((name, base + offset, size))
    return result


def texture_dimensions(header):
    if len(header) < 16 or header[:4] != b'GST2':
        raise ValueError('Unsupported CTEX header')
    version, width, height = struct.unpack_from('<III', header, 4)
    if version != 1 or not width or not height:
        raise ValueError('Unsupported CTEX version/dimensions')
    return width, height


def source_paths():
    result = {}
    for directory in ('assets', 'generated/tiled_visuals'):
        for metadata in (ROOT / directory).rglob('*.import'):
            text = metadata.read_text()
            source = re.search(r'^source_file="res://([^"]+)"', text, re.M)
            if source:
                for imported in re.findall(r'res://(\.godot/imported/[^"\n]+\.ctex)', text):
                    result[imported] = source[1]
    return result


def audit(pack):
    sources = source_paths()
    rows, groups, portable, effect_payloads = [], {}, [], {}
    with pack.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        for name, offset, size in entries(stream):
            if name.startswith('generated/tiled_visuals/') and name.endswith('.texture.res'):
                portable.append(dict(source=name, packedBytes=size))
            if not name.endswith('.ctex'):
                continue
            stream.seek(offset)
            width, height = texture_dimensions(stream.read(min(16, size)))
            source = sources.get(name, name)
            if source.startswith('generated/tiled_visuals/'):
                group = 'map-atlases'
            elif source.startswith('assets/battles/animations/'):
                group = 'battle-effects'
            elif source.startswith('assets/sprites/pokemon/'):
                group = 'pokemon'
            elif source.startswith('assets/ui/'):
                group = 'ui'
            else:
                group = 'other'
            rgba = width * height * 4
            row = dict(source=source, imported=name, width=width, height=height,
                       packedBytes=size, estimatedRGBABytes=rgba, group=group)
            if group == 'battle-effects':
                stream.seek(offset)
                payload = stream.read(size)
                content_hash = hashlib.sha256(payload).hexdigest()
                effect_payloads.setdefault(content_hash, []).append(row)
            rows.append(row)
            bucket = groups.setdefault(group, dict(textures=0, packedBytes=0, estimatedRGBABytes=0))
            bucket['textures'] += 1
            bucket['packedBytes'] += size
            bucket['estimatedRGBABytes'] += rgba
    rows.sort(key=lambda row: (-row['estimatedRGBABytes'], row['source']))
    duplicates = [dict(sha256=key, sources=sorted(row['source'] for row in bucket),
                       packedBytesPerTexture=bucket[0]['packedBytes'],
                       estimatedRGBABytesPerTexture=bucket[0]['estimatedRGBABytes'])
                  for key, bucket in effect_payloads.items() if len(bucket) > 1]
    duplicates.sort(key=lambda row: (-len(row['sources']) * row['estimatedRGBABytesPerTexture'], row['sha256']))
    return dict(pack=pack.name, sha256=digest, textureCount=len(rows), groups=groups,
                textures=rows, portableMapResources=portable, identicalBattleEffectPayloads=duplicates, limits=[
                    'Packed presence is not loaded texture residency or live RAM',
                    'RGBA estimates are not GPU allocation measurements',
                    'No remote sprite packs or runtime-created textures included',
                    'Portable map resources have packed sizes only, no decoded-dimension estimate',
                    'Identical payloads are sharing candidates, not measured resident-memory savings',
                    'Source names use local import metadata; dimensions come from this PCK'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pack', nargs='?', type=Path, default=ROOT / 'builds/web/index.pck')
    args = parser.parse_args()
    print(json.dumps(audit(args.pack), indent=2))
