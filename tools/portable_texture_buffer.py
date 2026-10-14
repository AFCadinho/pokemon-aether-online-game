"""Strict single-resource Godot 4.6 native Portable texture buffer replacement.

No general resource writer: only the checked PackedByteArray changes. The
single main-resource offset and every byte outside that array remain intact.
Godot cold decoding is still required before counting any candidate.
"""
import hashlib
import struct
from probe_v13_compression import require


def replace_buffer(raw, row, buffer):
    cursor = 0

    def number(kind='<I'):
        nonlocal cursor
        size = struct.calcsize(kind)
        require(cursor+size <= len(raw), 'Truncated native resource')
        value, = struct.unpack_from(kind, raw, cursor)
        cursor += size
        return value

    def string():
        nonlocal cursor
        size = number()
        require(0 < size <= 4096 and cursor+size <= len(raw), 'Unbounded native string')
        payload = raw[cursor:cursor+size]
        cursor += size
        require(payload.endswith(b'\0'), 'Unterminated native string')
        return payload[:-1].decode('utf-8')

    require([number() for _ in range(5)] == [0, 0, 4, 6, 6], 'Unsupported native header')
    require(string() == 'PortableCompressedTexture2D', 'Wrong texture storage class')
    require(number('<Q') == 0 and number() == 3, 'Unexpected import metadata or flags')
    number('<Q')  # Resource UID is preserved, including the invalid-ID sentinel.
    require([number() for _ in range(11)] == [0]*11, 'Unsupported reserved header fields')
    count = number()
    require(1 <= count <= 64, 'Unbounded native property names')
    names = [string() for _ in range(count)]
    require(names.count('_data') == 1, 'Ambiguous data property')
    require(number() == 0 and number() == 1, 'Texture has external or additional internal resources')
    require(string().startswith('local://PortableCompressedTexture2D_'), 'Wrong internal resource')
    body = number('<Q')
    require(body == cursor, 'Unexpected main-resource body offset')
    require(string() == 'PortableCompressedTexture2D', 'Wrong main-resource class')
    properties = number()
    require(1 <= properties <= count, 'Unbounded property count')
    header = struct.pack('<HH4I', 0, 2, row['format'], row['mipmaps']+1, row['width'], row['height'])
    start = raw.find(header, cursor)
    require(start >= cursor+12 and raw.find(header, start+1) == -1, 'Ambiguous PNG buffer')
    index, variant, length = struct.unpack_from('<III', raw, start-12)
    require(index == names.index('_data') and variant == 31, 'Not the native data PackedByteArray')
    end = start+length
    padded_end = end+(-length % 4)
    require(end <= len(raw)-4 and raw[end:padded_end] == bytes(-length % 4) and raw.endswith(b'RSRC'),
            'Malformed native buffer boundary')
    require(buffer[:20] == struct.pack('<HH4I', 0, 3, row['format'], row['mipmaps']+1, row['width'], row['height']),
            'Changed WebP image shape, precision or mip count')
    offset = 20
    for _ in range(row['mipmaps']+1):
        require(offset+4 <= len(buffer), 'Truncated WebP mip length')
        size, = struct.unpack_from('<I', buffer, offset)
        offset += 4
        payload = buffer[offset:offset+size]
        require(len(payload) == size and payload.startswith(b'RIFF') and payload[8:12] == b'WEBP', 'Malformed WebP mip')
        offset += size
    require(offset == len(buffer), 'Trailing WebP data')
    prefix, suffix = raw[:start-4], raw[padded_end:]
    result = prefix+struct.pack('<I', len(buffer))+buffer+bytes(-len(buffer) % 4)+suffix
    # An evidence hash for everything except the variable codec byte array.
    return result, hashlib.sha256(prefix+suffix).hexdigest()
