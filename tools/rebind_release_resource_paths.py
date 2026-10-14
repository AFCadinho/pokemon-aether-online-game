"""Strict equal-length Godot path rebinding including schema-1 internal names."""
import struct
from pathlib import PurePosixPath
from probe_v13_compression import require
from study_shared_form_textures import digest

def rebind_release_paths(raw, mapping, oldroot, newroot):
    """Godot 4.6 binary v6: change ONLY equal-length external path strings.

    Header, UIDs, property names, types, internal offsets and all resource body
    bytes remain untouched. Unknown layout/UIDs, unbound paths and size changes
    fail closed. Cold native scene/texture comparison is separately mandatory.
    """
    cursor = 0

    def number(kind='<I'):
        nonlocal cursor
        size = struct.calcsize(kind)
        require(cursor + size <= len(raw), 'Truncated native header')
        value, = struct.unpack_from(kind, raw, cursor)
        cursor += size
        return value

    def string():
        nonlocal cursor
        size = number()
        require(0 < size <= 8192 and cursor + size <= len(raw), 'Unbounded native string')
        start = cursor
        cursor += size
        data = raw[start:cursor]
        require(data.endswith(b'\0') and b'\0' not in data[:-1], 'Malformed native string')
        return data[:-1].decode('utf-8'), start, cursor - 1

    require([number() for _ in range(5)] == [0, 0, 4, 6, 6], 'Unsupported native version')
    cls, _, _ = string()
    require(cls in ['PackedScene', 'ImageTexture', 'PortableCompressedTexture2D', 'ArrayMesh', 'Skin', 'AnimationLibrary'], 'Unexpected native class')
    require(number('<Q') == 0 and number() == 3, 'Unexpected native imports/flags')
    require(number('<Q') == 2**64-1, 'Named native resource UID requires separate qualification')
    require([number() for _ in range(11)] == [0]*11, 'Unexpected reserved native fields')
    count = number()
    require(count <= 65536, 'Unbounded name table')
    for _ in range(count): string()
    count = number()
    require(count <= 128 and (cls == 'PackedScene' or count == 0), 'Unexpected external graph')
    result = bytearray(raw)
    spans = []
    for _ in range(count):
        kind, _, _ = string()
        path, start, end = string()
        require(kind in ['Texture2D', 'ImageTexture', 'ArrayMesh', 'Skin', 'AnimationLibrary'], 'Unexpected external type')
        require(number('<Q') == 2**64-1, 'External UID could redirect binding')
        require(path in mapping, 'Unbound external resource path')
        replacement = mapping[path].encode('utf-8')
        require(len(replacement) == end-start, 'External path length changed')
        result[start:end] = replacement
        spans.append((start, end))
    internal = number()
    require(1 <= internal <= 4096, 'Unbounded internal resource table')
    offsets = []
    for internal_index in range(internal):
        name, start, end = string()
        historical_main = (cls == 'PackedScene' and internal_index == internal-1
                           and PurePosixPath(name).is_absolute()
                           and PurePosixPath(name).suffix == '.scn'
                           and '..' not in PurePosixPath(name).parts)
        if not name.startswith('local://') and not historical_main:
            require(name.startswith(oldroot + '/'), f'Unexpected internal resource name: {name!r} expected {oldroot!r}')
            replacement = (newroot + name[len(oldroot):]).encode('utf-8')
            require(len(replacement) == end-start, 'Internal path length changed')
            result[start:end] = replacement
            spans.append((start, end))
        offsets.append(number('<Q'))
    require(offsets == sorted(set(offsets)) and offsets[0] == cursor and offsets[-1] < len(raw)-4 and raw.endswith(b'RSRC'), 'Malformed native body offsets')
    result = bytes(result)
    # Reconstruct the source by restoring only admitted path spans.
    restored = bytearray(result)
    for start, end in spans: restored[start:end] = raw[start:end]
    require(bytes(restored) == raw and len(result) == len(raw), 'Non-path native bytes changed')
    return result, {'external_paths': count, 'body_exact': result[cursor:] == raw[cursor:],
                    'source_raw_sha256': digest(raw), 'candidate_raw_sha256': digest(result)}

