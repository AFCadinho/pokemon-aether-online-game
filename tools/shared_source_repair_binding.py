"""Reconcile the one qualified source delta before using frozen cohort evidence.

The previous 1,199 pairs retain their exact descriptors. Historical render and
Linux readiness checks describe the frozen cohort, while the repaired pair has
separate native, delivery, shared-resource and publication evidence.
"""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def digest(data): return hashlib.sha256(data).hexdigest()


def historical_bytes(value, name, root=ROOT):
    binding = json.loads((root / 'release/hawlucha_source_repair_shared_binding.json').read_bytes())
    record = binding['files'][name]
    assert digest(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()) == record['current_canonical_sha256'], 'Unrecorded shared catalog mutation'
    qualification = (root / 'release/hawlucha_source_repair_qualification.json').read_bytes()
    assert digest(qualification) == binding['qualification_sha256'] == value['source_repair_qualification_sha256']
    q = json.loads(qualification)
    assert q['runtime_approved'] and q['appearance_approved'] and q['battle_approved'] and q['pairs'] == 1
    publication = (root / 'release/approved_3d_bundles_v12_r2_receipt.json').read_bytes()
    assert digest(publication) == binding['publication_receipt_sha256']
    published = json.loads(publication)
    assert published['source_repair_qualification_sha256'] == binding['qualification_sha256']
    revision = binding['baseline_commit']
    assert re.fullmatch(r'[0-9a-f]{40}', revision)
    assert name in ('model_pair_catalog', 'model_pair_qualified', 'model_pair_geometry_catalog', 'model_pair_geometry')
    raw = subprocess.check_output(['git', 'show', revision + ':data/' + name + '.json'], cwd=root)
    assert digest(raw) == record['baseline_sha256']
    old = json.loads(raw)
    before = {a['asset_id']: a for a in old['assets']}
    after = {a['asset_id']: a for a in value['assets']}
    assert len(after) == len(value['assets']) and before.keys() == after.keys()
    assert [k for k in before if before[k] != after[k]] == [binding['asset_id']]
    replacement = after[binding['asset_id']]
    receipts = published['replacement_shared_packs']
    assert any(r['sha256'] == replacement['sha256'] and r['public_get_sha256_verified'] and r['public_head_size_verified'] for r in receipts)
    if replacement['format'] == 'model-pair-pck-v1':
        expected = {a['runtime_identity']: a['runtime_sha256'] for a in q['bundle_index']['assets'][0]['appearances']}
        assert {a['runtime_identity']: a['source_sha256'] for a in replacement['appearances']} == expected
        assert replacement['appearances'] == replacement['pair_manifest']['appearances']
    return raw


def historical(value, name, root=ROOT):
    if 'source_repair_qualification_sha256' not in value:
        return value
    return json.loads(historical_bytes(value, name, root))


def evidence_bytes(root, path):
    raw = (root / path).read_bytes()
    value = json.loads(raw)
    if 'source_repair_qualification_sha256' not in value:
        return raw
    return historical_bytes(value, Path(path).stem, root)
