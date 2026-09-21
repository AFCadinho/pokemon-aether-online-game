"""Exact glTF geometry/skin/motion parity, ignoring only material/image data."""
import hashlib
import json
from pathlib import Path
import struct


def signature(path):
    payload = Path(path).read_bytes()
    if payload[:4] != b'glTF' or struct.unpack_from('<I', payload, 4)[0] != 2:
        raise ValueError('Expected GLB v2')
    length, kind = struct.unpack_from('<II', payload, 12)
    if kind != 0x4E4F534A:
        raise ValueError('Expected JSON chunk')
    doc = json.loads(payload[20:20 + length])
    start = 20 + length
    binary_length, binary_kind = struct.unpack_from('<II', payload, start)
    if binary_kind != 0x004E4942:
        raise ValueError('Expected BIN chunk')
    binary = payload[start + 8:start + 8 + binary_length]
    result = {key: doc.get(key) for key in ('scenes', 'scene', 'nodes', 'meshes', 'skins', 'animations')}
    accessors = []
    for accessor in doc.get('accessors', []):
        if 'sparse' in accessor or 'bufferView' not in accessor:
            raise ValueError('Unsupported sparse/unbacked accessor')
        view = doc['bufferViews'][accessor['bufferView']]
        if view.get('buffer', 0) != 0:
            raise ValueError('External buffer')
        offset = view.get('byteOffset', 0)
        contents = binary[offset:offset + view['byteLength']]
        accessors.append({'accessor': {k: v for k, v in accessor.items() if k != 'bufferView'},
            'view': {k: v for k, v in view.items() if k not in ('buffer', 'byteOffset')},
            'data': hashlib.sha256(contents).hexdigest()})
    result['accessors'] = accessors
    return hashlib.sha256(json.dumps(result, sort_keys=True).encode()).hexdigest()


def compare(normal, shiny):
    a, b = signature(normal), signature(shiny)
    if a != b:
        raise ValueError('Geometry/animation mismatch; independent placement review required')
    if Path(normal).read_bytes() == Path(shiny).read_bytes():
        raise ValueError('Variant is identical to normal')
    return a


if __name__ == '__main__':
    import sys
    print(compare(sys.argv[1], sys.argv[2]))
