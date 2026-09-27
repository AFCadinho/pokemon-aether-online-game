"""Explicit source-table defaults for missing, provably unanimated effect UVs."""
import copy
import hashlib
import math

from scvi_uv_probe import read_uv_tracks


def complete(data, material, job, directory):
    result = copy.deepcopy(data)
    unique = {}
    for track in result['tracks']:
        key = track['parameter']
        if key in unique and unique[key] != track:
            raise ValueError('Conflicting duplicate effect tracks')
        unique[key] = track
    missing = {'UVScaleOffset', 'UVScaleOffset3'} - unique.keys()
    if unique.keys() - {'UVScaleOffset', 'UVScaleOffset3'}:
        raise ValueError('Unreviewed effect parameter')
    hashes = job['identity_intake']['identity_evidence']['source_sha256']
    sources = sorted(directory.glob('*.tracm'))
    if not sources:
        raise ValueError('Effect default requires an identity-bound motion bank')
    for path in sources:
        if hashlib.sha256(path.read_bytes()).hexdigest() != hashes.get(str(path)):
            raise ValueError('Effect default motion provenance changed')
        if any(t['material'] == material['name'] and t['parameter'] in missing
               for t in read_uv_tracks(path)['tracks']):
            raise ValueError('Missing effect parameter is animated elsewhere')
    defaults = {}
    for key in sorted(missing):
        value = material.get('colors', {}).get(key)
        if (not isinstance(value, list) or len(value) != 4
                or not all(math.isfinite(v) for v in value) or min(value[:2]) <= 0):
            raise ValueError('Invalid native effect UV default')
        defaults[key] = value
        unique[key] = {'material': material['name'], 'parameter': key,
                       'channels': [[{'time': 0, 'value': v, 'config': [0, 0, 0]},
                                     {'time': data['frames'] - 1, 'value': v, 'config': [0, 0, 0]}]
                                    for v in value]}
    audit = {'source_uv_defaults': defaults,
             'identical_tracks_collapsed': len(data['tracks']) - (len(unique) - len(missing)),
             'default_motion_bank_sha256': {str(p): hashes[str(p)] for p in sources}}
    result['tracks'] = list(unique.values())
    return result, audit
