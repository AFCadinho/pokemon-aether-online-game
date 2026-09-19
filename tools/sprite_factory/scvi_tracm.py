"""Small, read-only decoder for the reviewed Scarlet/Violet TRACM subset.

The schema comes from PokeDocs' SV/Flatbuffers/animation/tracm.fbs.  Keeping
this decoder local avoids executing an add-on or requiring a FlatBuffers
compiler merely to inventory side-channel animation data.
"""

import struct
from pathlib import Path


class _Buffer:
    def __init__(self, data):
        self.data = data

    def u8(self, offset):
        return self.data[offset]

    def u16(self, offset):
        return struct.unpack_from("<H", self.data, offset)[0]

    def u32(self, offset):
        return struct.unpack_from("<I", self.data, offset)[0]

    def field(self, table, slot):
        vtable = table - struct.unpack_from("<i", self.data, table)[0]
        length = self.u16(vtable)
        entry = vtable + 4 + slot * 2
        return self.u16(entry) if entry < vtable + length else 0

    def scalar(self, table, slot, reader, default=0):
        offset = self.field(table, slot)
        return reader(table + offset) if offset else default

    def pointer(self, table, slot):
        offset = self.field(table, slot)
        if not offset:
            return None
        location = table + offset
        return location + self.u32(location)

    def tables(self, table, slot):
        vector = self.pointer(table, slot)
        if vector is None:
            return []
        length = self.u32(vector)
        first = vector + 4
        return [first + index * 4 + self.u32(first + index * 4)
                for index in range(length)]

    def string(self, table, slot):
        value = self.pointer(table, slot)
        if value is None:
            return None
        length = self.u32(value)
        return self.data[value + 4:value + 4 + length].decode("utf-8")


def inspect_tracm(path):
    """Return channel counts/names without interpreting artistic intent."""
    data = Path(path).read_bytes()
    view = _Buffer(data)
    root = view.u32(0)
    config = view.pointer(root, 0)
    if config is None:
        raise ValueError("TRACM has no TrackConfig")
    result = {
        "loop": bool(view.scalar(config, 0, view.u32)),
        "frames": view.scalar(config, 1, view.u32),
        "fps": view.scalar(config, 2, view.u32),
        "tracks": [],
        "material_tracks": 0,
        "visibility_tracks": 0,
        "blendshape_tracks": 0,
    }
    if result["frames"] < 1 or result["fps"] < 1:
        raise ValueError("TRACM has an invalid frame count or frame rate")
    for track in view.tables(root, 1):
        name = view.string(track, 0)
        material = view.pointer(track, 4)
        visibility = view.pointer(track, 5)
        blendshape = view.pointer(track, 6)
        material_count = len(view.tables(material, 2)) if material is not None else 0
        blendshape_count = len(view.tables(blendshape, 2)) if blendshape is not None else 0
        item = {"name": name, "material_tracks": material_count,
                "visibility": visibility is not None,
                "blendshape_tracks": blendshape_count}
        result["tracks"].append(item)
        result["material_tracks"] += material_count
        result["visibility_tracks"] += int(visibility is not None)
        result["blendshape_tracks"] += blendshape_count
    return result
