"""Source-bound visibility export; no species rules or inferred clip clocks."""
import hashlib
import math
from pathlib import Path

from scvi_tracm import inspect_tracm, inspect_visibility
from visibility_variants import binding, verify


def keys(track, frames, fps, *, dynamic_review=False):
    if track['time_raw'] != 0 or track['value_raw'] != 0:
        raise ValueError('Unsupported visibility timeline metadata')
    kind = track['encoding']
    if kind == 'fixed_bool':
        return [[0.0, track['fixed_value']]]
    if kind == 'dynamic_bool':
        if not dynamic_review:
            raise ValueError('Unsupported dynamic visibility clock')
        # Diagnostic interpretation of the observed packed stream: one bit
        # per source frame, least-significant bit first, then hold its final
        # bit. This requires independent pose/battle review before admission.
        packed = track['packed_bytes']
        if not packed or track['frames'] or 8 * len(packed) >= frames:
            raise ValueError('Unsupported dynamic visibility payload')
        values = [bool((byte >> bit) & 1) for byte in packed for bit in range(8)]
        return [[i / fps, value] for i, value in enumerate(values)
                if i == 0 or value != values[i - 1]]
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
    redundant = {}
    if intake.get('redundant_visibility_diagnostic') is True:
        active = {name + '_shape' for name in mesh_names}
        all_targets = {track['target'] for tracks in source_tracks.values() for track in tracks}
        fields = ('encoding', 'fixed_value', 'frames', 'packed_bytes', 'time_raw', 'value_raw')
        by_action = {action: {track['target']: track for track in tracks}
                     for action, tracks in source_tracks.items()}
        for extra in all_targets - active:
            owners = [target for target in active if all(
                extra in tracks and target in tracks
                and all(tracks[extra].get(field) == tracks[target].get(field) for field in fields)
                for tracks in by_action.values())]
            if len(owners) == 1:
                redundant[extra] = owners[0]
    membership = binding(intake, mesh_names,
                         [t['target'] for tracks in source_tracks.values() for t in tracks], redundant)
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
                           'keys': keys(track, config['frames'], config['fps'],
                                        dynamic_review=intake.get('dynamic_visibility_diagnostic') is True)})
        if sorted(t['mesh'] for t in tracks) != sorted(mesh_names):
            raise ValueError('Incomplete or duplicate visibility mesh coverage')
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError('Visibility source changed during export')
        result['clips'][action] = {'duration': duration, 'loop': config['loop'],
                                  'source_sha256': digest, 'tracks': tracks,
                                  'excluded_variant_targets': excluded}
    verify(membership)
    return result
