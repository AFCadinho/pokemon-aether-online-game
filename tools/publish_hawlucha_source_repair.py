#!/usr/bin/env python3
"""Publish the qualified one-pair repair and immutable indexes; never activate a build."""
import argparse
import datetime
import json
from pathlib import Path

from admit_hawlucha_source_repair import ROOT, ASSET, IDENTITIES, read, sha, write, validate
from publish_shared_model_collection import load_credentials, publish_immutable, snapshot_manifests


def prepare(source, work):
    fixture, replacement, texture, geometry, qualification = validate(source, work)
    receipt_path = ROOT / 'release/hawlucha_source_repair_qualification.json'
    assert read(receipt_path) == qualification
    registry = read(ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json')
    assert registry['hawlucha_source_repair_qualification_sha256'] == sha(receipt_path)
    assert read(ROOT / 'launcher/data/reviewed_model_catalog.json') == registry
    for identity in IDENTITIES:
        assert registry['models'][identity]['sha256'] == fixture['models'][identity]['sha256']
    index_path = ROOT / 'release/approved_3d_bundles_v12_index.json'
    index, previous = read(index_path), read(ROOT / 'release/approved_3d_bundles_v11_index.json')
    pin = read(ROOT / 'data/approved_3d_release_v12.json')
    assert pin == read(ROOT / 'launcher/data/approved_3d_release_v12.json')
    assert index['catalog_revision'] == pin['revision']
    assert sha(index_path) == pin['index']['sha256'] and index_path.stat().st_size == pin['index']['size_bytes']
    before = {r['asset_id']: r for r in previous['assets']}
    after = {r['asset_id']: r for r in index['assets']}
    assert len(before) == len(after) == 1200 and before.keys() == after.keys()
    assert [k for k in before if before[k] != after[k]] == [ASSET]
    assert after[ASSET] == replacement
    published = read(ROOT / 'release/approved_3d_bundles_v11_r2_receipt.json')
    assert published['content_index']['sha256'] == sha(ROOT / 'release/approved_3d_bundles_v11_index.json')
    old_proofs = {r['asset_id']: r for r in published['bundles']}
    for identity, asset in before.items():
        proof = old_proofs[identity]
        assert all(proof.get(k) == asset[k] for k in ['object_key', 'sha256', 'size_bytes'])
        assert proof['public_get_sha256_verified'] and proof['public_head_size_verified']
    packs = [(work / 'replacement-bundles' / Path(replacement['object_key']).name, replacement),
             (work / 'shared-packs/textures/packs' / Path(texture['object_key']).name, texture),
             (Path(read(work / 'shared-packs/geometry/candidates.json')[0]['path']), geometry)]
    indexes = [(index_path, pin['index'])]
    for name, expected in [('model_pair_qualified', texture), ('model_pair_geometry', geometry)]:
        path = ROOT / 'data' / (name + '.json')
        data = read(path)
        row = next(r for r in data['assets'] if r['asset_id'] == ASSET)
        assert row['sha256'] == expected['sha256']
        assert not data['production_approved'] and data['prototype_only']
        assert path.read_bytes() == (ROOT / 'launcher/data' / path.name).read_bytes()
        indexes.append((path, dict(object_key='optional-assets/pokemon_3d/index/pilot-' + sha(path) + '.json',
                                  sha256=sha(path), size_bytes=path.stat().st_size)))
    rows = [(path, {k: asset[k] for k in ['asset_id', 'object_key', 'sha256', 'size_bytes']}) for path, asset in packs]
    for path, record in rows + indexes:
        assert path.is_file() and not path.is_symlink()
        assert sha(path) == record['sha256'] and path.stat().st_size == record['size_bytes']
    return rows, indexes, pin, old_proofs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--credentials', type=Path)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    rows, indexes, pin, old_proofs = prepare(args.source.resolve(), args.work.resolve())
    print('HAWLUCHA_PUBLICATION_LOCAL_OK payloads=3 indexes=3 unchanged_pairs=1199', flush=True)
    if not args.apply: return
    output = ROOT / 'release/approved_3d_bundles_v12_r2_receipt.json'
    assert not output.exists(), 'Preserve the existing publication receipt'
    config = load_credentials(args.credentials)
    before = snapshot_manifests()
    payload_proofs = [publish_immutable(config, path, record) for path, record in rows]
    index_proofs = [publish_immutable(config, path, record) for path, record in indexes]
    after = snapshot_manifests()
    assert before == after, 'A live manifest changed during publication; investigate before activation'
    old_proofs[ASSET] = payload_proofs[0]
    receipt = dict(schema=1, revision=pin['revision'], content_index=pin['index'],
        source_repair_qualification_sha256=sha(ROOT / 'release/hawlucha_source_repair_qualification.json'),
        previous_publication_receipt_sha256=sha(ROOT / 'release/approved_3d_bundles_v11_r2_receipt.json'),
        index_verification=index_proofs[0], bundles=[old_proofs[k] for k in pin['requiredAssetIds']],
        replacement_shared_packs=payload_proofs[1:], replacement_shared_indexes=index_proofs[1:],
        verified_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        active_manifest_activated=False, active_manifest_sha256_unchanged=True, manifest_snapshots=before,
        scope='New immutable replacement only; 1199 unchanged bundle proofs inherited from pinned v11 publication. Shared collections remain opt-in.')
    write(output, receipt)
    print('HAWLUCHA_PUBLICATION_VERIFIED manifests_unchanged=true', flush=True)


if __name__ == '__main__': main()
