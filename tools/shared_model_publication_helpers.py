"""Bind immutable staging to the exact committed qualification and Linux record."""
import hashlib
import json
import sys


def validate_selection(root):
    if not __debug__:
        raise ValueError('Run without -O; qualification reconciliation requires assertions')
    sys.path.insert(0, str(root / 'tests'))
    from shared_model_qualified_metadata_check import check
    read = lambda name: json.loads((root / name).read_bytes())
    wire_bytes = (root / 'data/model_pair_qualified.json').read_bytes()
    wire = json.loads(wire_bytes)
    full = read('data/model_pair_catalog.json')
    proof_bytes = (root / 'tools/shared_model_qualification_results.json').read_bytes()
    proof = json.loads(proof_bytes)
    if wire_bytes != (root / 'launcher/data/model_pair_qualified.json').read_bytes():
        raise ValueError('Game/launcher selection differs')
    if wire['qualification_sha256'] != hashlib.sha256(proof_bytes).hexdigest():
        raise ValueError('Qualification hash differs')
    check(wire, full, read('release/approved_3d_bundles_v11_index.json'), proof)
    readiness = read('data/shared_model_readiness_checks.json')
    if readiness['linux_checks_passed'] is not True or readiness['production_approved'] is not False:
        raise ValueError('Expected the completed Linux-only readiness record')
    if readiness['index_sha256'] != hashlib.sha256(wire_bytes).hexdigest() or readiness['index_bytes'] != len(wire_bytes):
        raise ValueError('Readiness index differs')
    for phase in ('installation', 'consumers', 'session'):
        inputs = readiness['phase_inputs'][phase]['inputs']
        for name in ('data/model_pair_catalog.json', 'launcher/data/model_pair_catalog.json',
                     'data/model_pair_qualified.json', 'launcher/data/model_pair_qualified.json',
                     'release/approved_3d_bundles_v11_index.json'):
            if hashlib.sha256((root / name).read_bytes()).hexdigest() != inputs[name]:
                raise ValueError('Catalog differs from completed ' + phase + ' evidence: ' + name)
    trusted = {a['asset_id']: a for a in full['assets']}
    assets = [trusted[a['asset_id']] if a.get('format') == 'model-pair-ref-v1' else a for a in wire['assets']]
    if len({a['object_key'] for a in assets}) != 1200:
        raise ValueError('Nonunique physical object keys')
    return wire_bytes, assets
