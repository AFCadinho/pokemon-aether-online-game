"""Native skeletal timing, including constant poses with a nonzero duration."""
import math


def constant_pose_endpoint(info, first, last, scene_fps):
    frames, fps = info.keyFrames, info.frameRate
    if type(frames) is not int or not 1 <= frames <= 100000:
        raise ValueError('Invalid native clip frame count')
    if not math.isfinite(fps) or fps <= 0 or fps != scene_fps:
        raise ValueError('Native clip frame rate differs from imported scene')
    if not math.isfinite(first) or not math.isfinite(last) or first < 0 or last < first:
        raise ValueError('Invalid imported clip range')
    if last > first:
        return None
    if first != 0 or frames <= 1:
        raise ValueError('No native duration for constant pose')
    return frames - 1


def preserve_constant_pose(action, info, scene_fps):
    """Duplicate the actual fixed keys, not a guessed idle or rest pose."""
    endpoint = constant_pose_endpoint(info, *action.frame_range, scene_fps)
    if endpoint is None:
        return False
    if len(action.slots) != 1:
        raise ValueError('Constant pose needs one native action slot')
    curves = []
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                curves.extend(bag.fcurves)
    if not curves or any(len(c.keyframe_points) != 1 or c.keyframe_points[0].co.x != 0 for c in curves):
        raise ValueError('Not a fully fixed native pose')
    for curve in curves:
        value = curve.keyframe_points[0].co.y
        curve.keyframe_points.insert(endpoint, value).interpolation = 'CONSTANT'
        curve.update()
    return True
