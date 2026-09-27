"""Opt-in source quaternion sign repair; keeps authored key rotations and times."""
import math


def hemisphere_signs(values):
    signs = []
    previous = None
    for value in values:
        if (len(value) != 4 or not all(math.isfinite(v) for v in value)
                or abs(sum(v * v for v in value) - 1.0) > 0.01):
            raise ValueError('Source quaternion key is not finite and unit length')
        sign = -1 if previous is not None and sum(a * b for a, b in zip(previous, value)) < 0 else 1
        previous = [sign * v for v in value]
        signs.append(sign)
    return signs


def apply(actions, selected):
    import bpy

    if not isinstance(selected, list) or not selected or len(set(selected)) != len(selected):
        raise ValueError('Explicit unique quaternion repair clips required')
    records = []
    for name in selected:
        if name not in actions:
            raise ValueError('Quaternion repair clip is outside the export')
        action = bpy.data.actions[actions[name]]
        channels = {}
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        if not curve.data_path.endswith('.rotation_quaternion'):
                            continue
                        key = (curve.data_path, curve.array_index)
                        if key in channels:
                            raise ValueError('Duplicate quaternion channel')
                        channels[key] = curve
        changed = 0
        for path in sorted({key[0] for key in channels}):
            if any((path, i) not in channels for i in range(4)):
                raise ValueError('Incomplete quaternion channels')
            curves = [channels[path, i] for i in range(4)]
            times = [tuple(p.co.x for p in c.keyframe_points) for c in curves]
            if not times[0] or any(t != times[0] for t in times):
                raise ValueError('Quaternion channels have different key times')
            values = [tuple(c.keyframe_points[i].co.y for c in curves) for i in range(len(times[0]))]
            signs = hemisphere_signs(values)
            if -1 not in signs:
                continue
            # q and -q encode the same key rotation. Component interpolation
            # must use a continuous hemisphere to avoid crossing a zero norm.
            for curve in curves:
                for point, sign in zip(curve.keyframe_points, signs):
                    point.co.y *= sign
                    point.handle_left.y *= sign
                    point.handle_right.y *= sign
                curve.update()
            records.append({'clip': name, 'source_action': action.name, 'channel': path,
                            'flipped_key_times': [t for t, s in zip(times[0], signs) if s < 0],
                            'key_rotations_preserved': True, 'key_times_preserved': True})
            changed += 1
        if not changed:
            raise ValueError('Requested quaternion repair found no sign discontinuity')
    return records
