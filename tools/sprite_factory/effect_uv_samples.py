"""Bounded source-key UV playback for diagnostic exports, without affine fitting.

Only the previously reviewed zero-tangent key metadata is accepted. Integer
source-frame keys are sampled piecewise linearly; unknown tangents/configuration
remain blocked. Samples include the original endpoint, including UV wrap jumps.
"""
import math


def channel_samples(keys, endpoint):
    if not 1 <= endpoint <= 4095 or not keys or keys[0]['time'] != 0 or keys[-1]['time'] != endpoint:
        raise ValueError('Effect keys must cover a bounded complete loop')
    previous = -1
    for key in keys:
        time, value = key['time'], key['value']
        if not math.isfinite(time) or time != int(time) or time <= previous or not math.isfinite(value):
            raise ValueError('Invalid effect key time/value')
        if key['config'] not in ([0, 0, 0], [0, 0, 1]):
            raise ValueError('Unreviewed effect interpolation metadata')
        previous = time
    samples, cursor = [], 0
    for frame in range(endpoint + 1):
        while cursor + 1 < len(keys) - 1 and keys[cursor + 1]['time'] < frame:
            cursor += 1
        a, b = keys[cursor:cursor + 2]
        phase = (frame - a['time']) / (b['time'] - a['time'])
        samples.append(a['value'] + (b['value'] - a['value']) * phase)
    return samples


def sample_tracks(data):
    if 'declared_timeline_counts' in data:
        counts = data['declared_timeline_counts']
        if counts != data.get('actual_timeline_counts') or len(counts) != 3 or not counts[0] or counts[0] != data['multiplier']:
            raise ValueError('Effect timeline count mismatch')
        if any(c != [data['config_flag'], data['frames'], data['fps']] for c in data.get('nested_timing', [])):
            raise ValueError('Independent material timeline requires review')
    elif data['multiplier'] != 1:
        raise ValueError('Missing evidence for multiple material timelines')
    if data['config_flag'] != 1 or not 1 <= data['fps'] <= 240:
        raise ValueError('Unreviewed effect loop config')
    result = {}
    for track in data['tracks']:
        name = track['parameter']
        if name in result or len(track['channels']) != 4:
            raise ValueError('Ambiguous effect tracks')
        channels = [channel_samples(c, data['frames'] - 1) for c in track['channels']]
        for index, values in enumerate(channels):
            if index < 2 and (values[0] <= 0 or any(v != values[0] for v in values)):
                raise ValueError('Animated/nonpositive effect UV scale needs review')
            if index >= 2 and abs((values[-1] - values[0]) - round(values[-1] - values[0])) > 1e-5:
                raise ValueError('Nonperiodic effect UV loop')
        result[name] = [list(frame) for frame in zip(*channels)]
    if set(result) != {'UVScaleOffset', 'UVScaleOffset3'}:
        raise ValueError('Effect needs both reviewed UV tracks')
    return result
