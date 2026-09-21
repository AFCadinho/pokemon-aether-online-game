"""Narrow TRACM UV reader for diagnostic material loops, not runtime approval.

Schema: https://github.com/pkZukan/PokeDocs/blob/master/SV/Flatbuffers/animation/tracm.fbs
Unknown interpolation metadata is retained and rejected by the affine sampler.
"""
import math
import struct
from pathlib import Path

from scvi_tracm import _Buffer


def read_uv_tracks(path):
    view = _Buffer(Path(path).read_bytes())
    root = view.u32(0)
    config = view.pointer(root, 0)
    if config is None:
        raise ValueError('Missing TRACM config')
    report = {'frames': view.scalar(config, 1, view.u32),
              'fps': view.scalar(config, 2, view.u32),
              'config_flag': view.scalar(config, 0, view.u32),
              'multiplier': view.scalar(root, 2, view.u8), 'tracks': []}
    f32 = lambda offset: struct.unpack_from('<f', view.data, offset)[0]
    for track in view.tables(root, 1):
        timeline = view.pointer(track, 4)
        if timeline is None:
            continue
        for material in view.tables(timeline, 2):
            for animation in view.tables(material, 2):
                name = view.string(animation, 0)
                if name not in ('UVScaleOffset', 'UVScaleOffset3'):
                    continue
                channels = view.pointer(animation, 1)
                if channels is None:
                    raise ValueError('Missing UV channels')
                values = []
                for index in range(4):
                    sequence = view.pointer(channels, index)
                    values.append([{'time': view.scalar(key, 0, f32),
                                    'value': view.scalar(key, 1, f32),
                                    'config': [view.scalar(key, n, view.u32) for n in (2, 3, 4)]}
                                   for key in view.tables(sequence, 0)] if sequence else [])
                report['tracks'].append({'material': view.string(material, 0),
                                         'parameter': name, 'channels': values})
    return report


def affine_channel(keys, endpoint):
    if len(keys) < 2:
        raise ValueError('UV probe requires explicit endpoint keys')
    if keys[0]['time'] != 0 or keys[-1]['time'] != endpoint:
        raise ValueError('UV keys do not cover the complete loop')
    previous = -1
    first, last = keys[0]['value'], keys[-1]['value']
    for key in keys:
        time, value = key['time'], key['value']
        if not math.isfinite(time) or not math.isfinite(value) or time <= previous:
            raise ValueError('Non-finite or unordered UV keys')
        if key['config'] not in ([0, 0, 0], [0, 0, 1]):
            raise ValueError('Unreviewed UV interpolation metadata')
        if abs(value - (first + (last - first) * time / endpoint)) > 1e-6:
            raise ValueError('UV probe only supports constant or affine channels')
        previous = time
    return first, last


def validate_loop(data):
    if data['multiplier'] != 1 or data['config_flag'] != 1:
        raise ValueError('Unreviewed UV loop config')
    if data['frames'] < 2 or data['fps'] < 1 or not data['tracks']:
        raise ValueError('Empty UV loop')
    seen = set()
    for track in data['tracks']:
        identity = track['material'], track['parameter']
        if identity in seen or len(track['channels']) != 4:
            raise ValueError('Ambiguous UV track')
        seen.add(identity)
        for keys in track['channels']:
            affine_channel(keys, data['frames'] - 1)
    return data


def sample_loop(data, seconds):
    validate_loop(data)
    if not math.isfinite(seconds) or seconds < 0:
        raise ValueError('Invalid material time')
    endpoint = data['frames'] - 1
    phase = (seconds * data['fps'] % endpoint) / endpoint
    result = {}
    for track in data['tracks']:
        values = []
        for keys in track['channels']:
            first, last = affine_channel(keys, endpoint)
            values.append(first + (last - first) * phase)
        result.setdefault(track['material'], {})[track['parameter']] = values
    return result
