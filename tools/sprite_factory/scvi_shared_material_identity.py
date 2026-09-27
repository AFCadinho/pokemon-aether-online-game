"""Verify only the default appearance of a shared SCVI material resource.

TRMMT schema: PokeDocs de20b28d82d5d8b473905eb2c24e5d8b47841ca8,
SV/Flatbuffers/model/trmmt.fbs. Other form frames need their own selector.
This checks source identity for review; it does not approve rendered colours.
"""
import math


def verify_default_materials(table_path, material_path):
    from scvi_identity import Buffer, sha

    source = Buffer(material_path.read_bytes())
    colours = {}
    for material in source.tables(source.number(0), 1):
        name = source.string(material, 0)
        if source.field(material, 7) is None:
            continue
        for parameter in source.tables(material, 7):
            key = name, source.string(parameter, 0)
            value = source.field(parameter, 1)
            if value is None or key in colours:
                raise ValueError('Missing or duplicate default material colour')
            colours[key] = tuple(source.number(value + 4 * i, 'f') for i in range(4))

    table = Buffer(table_path.read_bytes())
    normal = [row for row in table.tables(table.number(0), 2)
              if table.string(row, 0) == 'normal']
    if len(normal) != 1 or table.strings(normal[0], 1):
        raise ValueError('Shared default requires exactly one inherited normal material set')
    switches = table.tables(normal[0], 2)
    if not switches or any(table.scalar(row, 1, 'B') != 1 for row in switches):
        raise ValueError('Shared default changes mesh visibility')
    properties = table.tables(normal[0], 3)
    if len(properties) != 1 or table.string(properties[0], 0) != 'color':
        raise ValueError('Unreviewed shared material selector properties')
    prop = properties[0]
    mappings = {(table.string(m, 1), table.string(m, 2)) for m in table.tables(prop, 1)}
    embedded = table.pointer(prop, 4)
    vector = table.pointer(embedded, 0)
    size = table.number(vector)
    if size < 4 or vector + 4 + size > len(table.data):
        raise ValueError('Invalid embedded material selector')
    clip = Buffer(table.data[vector + 4:vector + 4 + size])
    root = clip.number(0)
    config = clip.pointer(root, 0)
    if clip.scalar(config, 0, 'I') != 0 or clip.scalar(config, 1, 'I') < 1:
        raise ValueError('Default form requires a non-looping material selector')
    selected = {}
    maximum_delta = 0.0
    for timeline in clip.tables(root, 1):
        if clip.field(timeline, 5) is not None or clip.field(timeline, 6) is not None:
            raise ValueError('Shared selector includes non-material channels')
        material_timeline = clip.pointer(timeline, 4)
        for material in clip.tables(material_timeline, 2):
            if clip.field(material, 1) is not None and clip.tables(material, 1):
                raise ValueError('Shared selector includes material flags')
            for parameter in clip.tables(material, 2):
                key = clip.string(material, 0), clip.string(parameter, 0)
                if key not in colours:
                    raise ValueError('Shared selector targets an unbound material colour')
                channels = clip.pointer(parameter, 1)
                values = []
                for index in range(4):
                    keys = clip.tables(clip.pointer(channels, index), 0)
                    if not keys or clip.scalar(keys[0], 0, 'f') != 0:
                        raise ValueError('Shared selector has no explicit frame-zero colour')
                    values.append(clip.scalar(keys[0], 1, 'f'))
                if key in selected and selected[key] != values:
                    raise ValueError('Shared selector has conflicting colour mappings')
                selected[key] = values
                for actual, expected in zip(values, colours[key], strict=True):
                    if not math.isfinite(actual) or not math.isfinite(expected):
                        raise ValueError('Non-finite shared material colour')
                    delta = abs(actual - expected)
                    # Some authored selector colours round the TRMTR value to
                    # three decimals. Retain the measured difference in evidence.
                    if delta > 0.000501:
                        raise ValueError('Frame-zero selector differs from default material colour')
                    maximum_delta = max(maximum_delta, delta)
    if not mappings or not mappings <= set(selected):
        raise ValueError('Incomplete shared default material selector')
    return {'policy': 'shared-default-frame-zero-v1', 'frame': 0,
            'material_table_sha256': sha(table_path), 'normal_material_sha256': sha(material_path),
            'verified_colours': len(selected), 'maximum_colour_delta': maximum_delta}
