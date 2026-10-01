"""Diagnostic Unity transform-clip intake; never admits models into the catalog.

Requires UnityPy (see the pinned intake receipt for the tested version). Only Transform bindings are converted;
other bindings are reported explicitly. The source bundle must match its pinned
SHA-256. This does not establish material, visibility or battle qualification.
"""
import argparse
import bisect
import hashlib
import json
import math
from pathlib import Path
import struct
import zlib


def streamed_curves(stream):
    """Decode Unity's sparse scalar cubic-polynomial keys (little endian)."""
    curves = [[] for _ in range(stream['curveCount'])]
    data = struct.pack('<' + 'I' * len(stream['data']), *stream['data'])
    position = 0
    while position < len(data):
        time, count = struct.unpack_from('<fi', data, position)
        position += 8
        if count < 0 or position + count * 20 > len(data):
            raise ValueError('Invalid streamed frame length')
        for _ in range(count):
            index, *coefficients = struct.unpack_from('<i4f', data, position)
            position += 20
            if not 0 <= index < len(curves):
                raise ValueError('Streamed curve index outside bank')
            if curves[index] and time < curves[index][-1][0]:
                raise ValueError('Unordered streamed key times')
            curves[index].append((time, coefficients))
    if any(not curve for curve in curves):
        raise ValueError('Streamed scalar curve has no keys')
    return curves


def scalar_value(index, time, streams, dense, constants):
    if index < len(streams):
        keys = streams[index]
        key_index = max(0, bisect.bisect_right([key[0] for key in keys], time) - 1)
        key_time, coefficients = keys[key_index]
        delta = time - key_time if math.isfinite(key_time) else 0
        a, b, c, value = coefficients
        return ((a * delta + b) * delta + c) * delta + value
    index -= len(streams)
    if index < dense['m_CurveCount']:
        at = (time - dense['m_BeginTime']) * dense['m_SampleRate']
        left = max(0, min(dense['m_FrameCount'] - 1, math.floor(at)))
        right = min(dense['m_FrameCount'] - 1, left + 1)
        fraction = max(0, min(1, at - left))
        values, width = dense['m_SampleArray'], dense['m_CurveCount']
        return values[left * width + index] * (1 - fraction) + values[right * width + index] * fraction
    return constants[index - dense['m_CurveCount']]


def decode_clip(clip, paths):
    bank = clip['m_MuscleClip']['m_Clip']['data']
    streams = streamed_curves(bank['m_StreamedClip'])
    dense = bank['m_DenseClip']
    constants = bank['m_ConstantClip']['data']
    bindings, ignored, offset = [], [], 0
    for row in clip['m_ClipBindingConstant']['genericBindings']:
        attribute = row['attribute']
        transform = row['typeID'] == 4
        size = (4 if attribute == 2 else 3) if transform else 1
        if transform:
            if attribute not in (1, 2, 3):
                raise ValueError('Unsupported transform attribute: ' + str(attribute))
            if row['path'] not in paths:
                raise ValueError('Unresolved transform path hash')
            bindings.append({'bone': paths[row['path']], 'attribute': attribute,
                             'offset': offset, 'size': size})
        else:
            ignored.append({'typeID': row['typeID'], 'attribute': attribute, 'offset': offset})
        offset += size
    if offset != len(streams) + dense['m_CurveCount'] + len(constants):
        raise ValueError('Binding and scalar bank lengths differ')
    duration = clip['m_MuscleClip']['m_StopTime'] - clip['m_MuscleClip']['m_StartTime']
    fps = clip['m_SampleRate']
    if not (math.isfinite(duration) and duration > 0 and math.isfinite(fps) and 0 < fps <= 120):
        raise ValueError('Invalid clip duration or sample rate')
    frames = []
    frame_count = duration * fps
    steps = round(frame_count) if abs(frame_count - round(frame_count)) < 1e-4 else math.ceil(frame_count)
    for frame in range(steps + 1):
        time = min(frame / fps, duration)
        tracks = {}
        for binding in bindings:
            values = [scalar_value(binding['offset'] + i, time, streams, dense, constants)
                      for i in range(binding['size'])]
            if not all(math.isfinite(value) for value in values):
                raise ValueError('Nonfinite transform sample')
            tracks.setdefault(binding['bone'], {})[str(binding['attribute'])] = values
        frames.append({'time': time, 'tracks': tracks})
    return {'name': clip['m_Name'], 'duration': duration, 'fps': fps,
            'bindings': bindings, 'ignored_non_transform_bindings': ignored, 'frames': frames}


def decode_bundle(source, expected_sha256):
    data = Path(source).read_bytes()
    if hashlib.sha256(data).hexdigest() != expected_sha256:
        raise ValueError('Source bundle hash changed')
    if not data.startswith(b'UnityFS\0'):
        raise ValueError('Expected UnityFS source bundle')
    import UnityPy
    environment = UnityPy.load(data)
    transforms = {obj.path_id: obj.read_typetree() for obj in environment.objects
                  if obj.type.name == 'Transform'}
    names = {obj.path_id: obj.read_typetree()['m_Name'] for obj in environment.objects
             if obj.type.name == 'GameObject'}

    def node_path(index, visited=()):
        if index in visited:
            raise ValueError('Transform parent cycle')
        node = transforms[index]
        name = names[node['m_GameObject']['m_PathID']]
        parent = node['m_Father']['m_PathID']
        return (node_path(parent, visited + (index,)) + '/' if parent in transforms else '') + name

    nodes, paths = [], {}
    for index, node in transforms.items():
        path = node_path(index)
        name = names[node['m_GameObject']['m_PathID']]
        parent = node['m_Father']['m_PathID']
        nodes.append({'name': name, 'path': path,
                      'parent': names[transforms[parent]['m_GameObject']['m_PathID']] if parent in transforms else None,
                      'position': [node['m_LocalPosition'][axis] for axis in 'xyz'],
                      'rotation': [node['m_LocalRotation'][axis] for axis in 'xyzw'],
                      'scale': [node['m_LocalScale'][axis] for axis in 'xyz']})
        segments = path.split('/')
        for start in range(len(segments)):
            digest = zlib.crc32('/'.join(segments[start:]).encode())
            if digest in paths and paths[digest] != name:
                raise ValueError('Ambiguous transform path hash')
            paths[digest] = name
    clips = [decode_clip(obj.read_typetree(), paths) for obj in environment.objects
             if obj.type.name == 'AnimationClip']
    if not clips:
        raise ValueError('Source bundle has no animation clips')
    return {'source_sha256': expected_sha256, 'runtime_approved': False,
            'scope': 'transform_motion_intake_only', 'nodes': nodes, 'clips': clips}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--sha256', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError('Output already exists; keep prior diagnostic evidence')
    result = decode_bundle(args.source, args.sha256)
    args.output.write_text(json.dumps(result, separators=(',', ':')) + '\n')
    print(json.dumps({'clips': len(result['clips']), 'runtime_approved': False}))


if __name__ == '__main__':
    main()
