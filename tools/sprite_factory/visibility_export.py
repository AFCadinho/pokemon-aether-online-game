"""Source-bound visibility export; no species rules or inferred clip clocks."""
import hashlib
import math
from pathlib import Path

from scvi_tracm import inspect_tracm, inspect_visibility
from visibility_variants import binding, verify


def keys(track, frames, fps):
    if track['time_raw'] != 0 or track['value_raw'] != 0:
        raise ValueError('Unsupported visibility timeline metadata')
    kind = track['encoding']
    if kind == 'fixed_bool':
        return [[0.0, track['fixed_value']]]
    if kind == 'dynamic_bool':
        # The observed byte streams can be shorter than the clip. Their
        # sample clock/truncation semantics are not established: do not guess.
        raise ValueError('Unsupported dynamic visibility clock')
    if kind not in ('framed8_bool', 'framed16_bool'):
        raise ValueError('Unsupported visibility encoding')
    indices, packed = track['frames'], track['packed_bytes']
    if (not indices or indices[0] != 0 or indices != sorted(set(indices))
            or indices[-1] >= frames or len(packed) != (len(indices)+7)//8):
        raise ValueError('Invalid framed visibility keys or payload length')
    # Source bitsets: least-significant bit first; explicit frame keys.
    if len(indices) % 8 and packed[-1] >> (len(indices) % 8):
        raise ValueError('Nonzero visibility padding bits')
    return [[frame/fps, bool((packed[i//8] >> (i%8)) & 1)]
            for i, frame in enumerate(indices)]


def prepare(intake, animations, gltf, glb_hash):
    channels = intake['motion_channels']
    expected_hashes = intake['identity_evidence']['source_sha256']
    mesh_names = [node.get('name') for node in gltf['nodes'] if 'mesh' in node]
    if not mesh_names or None in mesh_names or len(mesh_names) != len(set(mesh_names)):
        raise ValueError('Ambiguous exported visibility mesh names')
    if set(animations) != {key for key, value in channels.items() if value}:
        raise ValueError('Visibility clip coverage differs from skeletal clips')
    source_tracks = {}
    for action in animations:
        path = Path(channels[action])
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected_hashes.get(str(path)):
            raise ValueError('Visibility source hash mismatch')
        source_tracks[action] = inspect_visibility(path)
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected_hashes[str(path)]:
            raise ValueError('Visibility source changed during decoding')
    membership = binding(intake, mesh_names, [t['target'] for tracks in source_tracks.values() for t in tracks])
    result = {'schema': 1, 'glb_sha256': glb_hash, 'clips': {}, 'variant_binding': membership}
    for action, timing in animations.items():
        path = Path(channels[action])
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != expected_hashes.get(str(path)):
            raise ValueError('Visibility source hash mismatch')
        if path.stem != timing['source_action']:
            raise ValueError('Visibility and skeletal source actions differ')
        config = inspect_tracm(path)
        duration = (config['frames']-1)/config['fps']
        if (not math.isfinite(timing['duration']) or duration <= 0
                or abs(duration-timing['duration']) > 1e-6
                or config['loop'] != timing['loop']):
            raise ValueError('Visibility and skeletal clocks differ')
        tracks = []
        seen_targets = set()
        excluded = []
        for track in source_tracks[action]:
            target = track['target']
            if target in seen_targets:
                raise ValueError('Duplicate visibility source target')
            seen_targets.add(target)
            if target in membership['excluded_targets']:
                excluded.append(target)
                continue
            if not target or not target.endswith('_shape'):
                raise ValueError('Unknown source visibility target convention')
            mesh = target.removesuffix('_shape')
            if mesh_names.count(mesh) != 1:
                raise ValueError('Unresolved visibility mesh: ' + target)
            tracks.append({'mesh': mesh, 'source_target': target,
                           'keys': keys(track, config['frames'], config['fps'])})
        if sorted(t['mesh'] for t in tracks) != sorted(mesh_names):
            raise ValueError('Incomplete or duplicate visibility mesh coverage')
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError('Visibility source changed during export')
        result['clips'][action] = {'duration': duration, 'loop': config['loop'],
                                  'source_sha256': digest, 'tracks': tracks,
                                  'excluded_variant_targets': excluded}
    verify(membership)
    return result
