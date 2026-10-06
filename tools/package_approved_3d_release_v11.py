#!/usr/bin/env python3
"""Bind the verified lossless collection locally; publication is a release step."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
REVISION = 'approved-pokemon-3d-v11'
BINDING = 'release/approved_3d_lossless_binding.json'
REGISTRIES = ['scripts/battle/battle_ui/reviewed_model_catalog.json', 'launcher/data/reviewed_model_catalog.json']
ARTIFACTS = ['release/approved_3d_bundles_v11_index.json', 'release/approved_3d_bundles_v11.json',
             'data/approved_3d_release_v11.json', 'launcher/data/approved_3d_release_v11.json']
EVIDENCE = ['tools/sprite_factory/native_catalog_preparation_results.json',
            'tools/sprite_factory/native_source_overlap_resolution_results.json',
            'launcher/tests/native_desktop_ci_qualification_results.json']


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False) + '\n').encode()


def file_sha(path):
    with Path(path).open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def registry_bytes(original, registry):
    # Keep the reviewed profiles byte-for-byte, including Godot's numeric
    # spelling. Only model admission records and the new binding are changed.
    text = original.decode('utf-8')
    start = text.index('\t"models":')
    end = text.index('\n\t},', start) + len('\n\t}')
    block = '\t"models": ' + json.dumps(registry['models'], indent='\t', sort_keys=True, ensure_ascii=False).replace('\n', '\n\t')
    text = text[:start] + block + text[end:]
    needle = '\n\t"profiles":'
    assert needle in text and '"native_lossless_binding_sha256"' not in text
    text = text.replace(needle, '\n\t"native_lossless_binding_sha256": "' + registry['native_lossless_binding_sha256'] + '",' + needle, 1)
    assert json.loads(text) == registry
    return text.encode('utf-8')


def outputs(index, binding, registries):
    source_bytes = (ROOT / 'release/approved_3d_bundles_v10_index.json').read_bytes()
    source = json.loads(source_bytes)
    assert binding['schema'] == 1 and binding['revision'] == REVISION
    assert binding['source_index_sha256'] == sha(source_bytes)
    assert index['catalog_revision'] == REVISION and len(index['assets']) == 1200
    assert not index.get('prototype_only') and not index.get('production_approved')
    old = {a['asset_id']: a for a in source['assets']}
    new = {a['asset_id']: a for a in index['assets']}
    assert len(new) == 1200 and set(new) == set(old)
    assert len(binding['models']) == 2400
    assert registries[0] == registries[1]
    seen = set()
    for key, asset in new.items():
        previous = old[key]
        assert asset['asset_id'] == f"pokemon_3d:{asset['species_id']}:{asset['form_id']}"
        assert {a['variant'] for a in asset['appearances']} == {'normal', 'shiny'} and len(asset['appearances']) == 2
        before = {a['runtime_identity']: a for a in previous['appearances']}
        assert {a['runtime_identity'] for a in asset['appearances']} == set(before)
        changed = asset['sha256'] != previous['sha256']
        if changed:
            assert asset['version'] == previous['version'] + 1 and asset['size_bytes'] < previous['size_bytes']
            assert asset['object_key'] == f"optional-assets/pokemon_3d/{asset['species_id']}/{asset['form_id']}/v{asset['version']}-{asset['sha256']}.zip"
        else:
            assert asset == previous
        for appearance in asset['appearances']:
            identity = appearance['runtime_identity']
            assert identity not in seen
            seen.add(identity)
            row = binding['models'][identity]
            model = registries[0]['models'][identity]
            assert row['source_sha256'] == before[identity]['runtime_sha256']
            assert row['candidate_sha256'] == appearance['runtime_sha256'] == model['sha256']
            assert row['cache_source_bytes'] == model['cache_source_bytes'] and row['candidate_bytes'] <= row['cache_source_bytes']
            assert row['source_sha256'] == model['sha256'] or row['source_sha256'] in model.get('previous_sha256', [])
            assert len(row['decoded_sha256']) == 64
    assert seen == set(binding['models']) == set(registries[0]['models'])
    assert binding['changed_pairs'] == sum(new[k]['sha256'] != old[k]['sha256'] for k in new) == 1198
    for name, digest in binding['evidence_sha256'].items():
        assert sha((ROOT / name).read_bytes()) == digest
    prep = json.loads((ROOT / EVIDENCE[0]).read_bytes())
    native = json.loads((ROOT / EVIDENCE[2]).read_bytes())
    assert prep['complete_preparation'] and prep['all_raw_bytes_unchanged'] and prep['appearances'] == 2400
    assert native['complete'] and len(native['targets']) == 4 and all(t['complete'] for t in native['targets'])
    assert json.loads((ROOT / EVIDENCE[1]).read_bytes())['warm_reference_for_measured_client_contract']
    binding_digest = sha(encoded(binding))
    assert registries[0]['native_lossless_binding_sha256'] == binding_digest
    data = encoded(index)
    assert len(data) <= 1024 * 1024
    pin = {'object_key': f'optional-assets/pokemon_3d/index/{REVISION}-{sha(data)}.json',
           'sha256': sha(data), 'size_bytes': len(data)}
    metadata = {'schema': 1, 'kind': 'pokeaether-approved-3d-release', 'revision': REVISION, 'index': pin,
                'bundles': [{k: a[k] for k in ('asset_id','object_key','sha256','size_bytes')} for a in index['assets']],
                'new_bundle_count': 1198, 'total_bundle_bytes': sum(a['size_bytes'] for a in index['assets']),
                'previous_index_sha256': sha(source_bytes), 'lossless_binding_sha256': binding_digest,
                'publication_required': True}
    client = {'schema': 1, 'revision': REVISION, 'index': pin, 'requiredAssetIds': [a['asset_id'] for a in index['assets']]}
    return data, encoded(metadata), encoded(client), encoded(client)


def validate_local():
    index = json.loads((ROOT / ARTIFACTS[0]).read_bytes())
    binding = json.loads((ROOT / BINDING).read_bytes())
    registries = [json.loads((ROOT / n).read_bytes()) for n in REGISTRIES]
    result = outputs(index, binding, registries)
    for name, data in zip(ARTIFACTS, result, strict=True):
        assert (ROOT / name).read_bytes() == data, 'Release artifact differs from bindings: ' + name
    return json.loads(result[1])


def prepare(directory):
    preparation = json.loads((ROOT / EVIDENCE[0]).read_bytes())
    for name, record in preparation['artifacts'].items():
        assert file_sha(directory / name) == record['sha256'], 'Preparation receipt changed: ' + name
    report = json.loads((directory / 'report.json').read_bytes())
    original_registry_bytes = (ROOT / REGISTRIES[0]).read_bytes()
    original = json.loads(original_registry_bytes)
    assert sha(original_registry_bytes) == report['registry_sha256'] == preparation['source_registry_sha256']
    assert (ROOT / REGISTRIES[1]).read_bytes() == original_registry_bytes
    source_bytes = (ROOT / 'release/approved_3d_bundles_v10_index.json').read_bytes()
    assert sha(source_bytes) == report['index_sha256'] == preparation['source_index_sha256']
    source = {a['asset_id']: a for a in json.loads(source_bytes)['assets']}
    index = json.loads((directory / 'draft-index.json').read_bytes())
    assert index['prototype_only'] and not index['production_approved'] and report['complete']
    index = {k:v for k,v in index.items() if k not in ['prototype_only','production_approved']}
    index['catalog_revision'] = REVISION
    sys.path.insert(0, str(ROOT / 'tools/sprite_factory'))
    from native_resource_compression_probe import Zstd, decode
    codec = Zstd()
    binding = {'schema':1, 'revision':REVISION, 'source_index_sha256':sha(source_bytes),
               'source_registry_sha256':sha(original_registry_bytes), 'changed_pairs':1198,
               'codec':{'block_size':262144,'level':9,'libzstd':report['libzstd']},
               'evidence_sha256':{n:sha((ROOT/n).read_bytes()) for n in EVIDENCE}, 'models':{}}
    registries = [copy.deepcopy(original), copy.deepcopy(original)]
    for number, receipt in enumerate(report['assets'], 1):
        asset = receipt['candidate_asset']
        assert receipt['source_asset'] == source[asset['asset_id']]
        path = Path(receipt['candidate_archive'])
        assert path.is_file() and not path.is_symlink()
        assert path.stat().st_size == asset['size_bytes'] and file_sha(path) == asset['sha256']
        with zipfile.ZipFile(path) as archive:
            manifest = json.loads(archive.read('bundle.json'))
            assert manifest['asset_id'] == asset['asset_id'] and manifest['version'] == asset['version']
            for row in receipt['entries']:
                identity = row['identity']
                variant = 'shiny' if identity.endswith('@shiny') else 'normal'
                data = archive.read('models/' + variant + '.scn')
                assert len(data) == row['candidate_bytes'] and sha(data) == row['candidate_sha256']
                raw = data[4:] if data[:4] == b'RSRC' else decode(data, codec)
                assert len(raw) == row['raw_bytes'] and sha(raw) == row['raw_sha256']
                previous = original['models'][identity]
                assert previous['sha256'] == row['source_sha256']
                binding['models'][identity] = {'source_sha256':row['source_sha256'], 'candidate_sha256':row['candidate_sha256'],
                                              'cache_source_bytes':row['source_bytes'],'candidate_bytes':row['candidate_bytes'],
                                              'decoded_sha256':row['raw_sha256']}
                for registry in registries:
                    model = registry['models'][identity]
                    model['sha256'] = row['candidate_sha256']
                    model['cache_source_bytes'] = row['source_bytes']
                    model['previous_sha256'] = sorted(set([row['source_sha256'], *previous.get('previous_sha256', [])]) - {row['candidate_sha256']})
        if number % 50 == 0:
            print('LOSSLESS_RELEASE_VERIFIED',number,'/ 1200',flush=True)
    for registry in registries:
        registry['native_lossless_binding_sha256'] = sha(encoded(binding))
    result = outputs(index, binding, registries)
    # Write only after every archive, stream and binding passed verification.
    (ROOT / BINDING).write_bytes(encoded(binding))
    for name, registry in zip(REGISTRIES, registries, strict=True):
        (ROOT/name).write_bytes(registry_bytes(original_registry_bytes, registry))
    for name, data in zip(ARTIFACTS,result,strict=True):
        (ROOT/name).write_bytes(data)
    print('V11_PREPARED bundles=1200 appearances=2400 bytes=' + str(json.loads(result[1])['total_bundle_bytes']))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--prepared',type=Path)
    args=p.parse_args()
    if args.prepared:
        prepare(args.prepared.resolve())
    else:
        validate_local()
        print('V11_LOCAL_OK bundles=1200 appearances=2400 no_network=true')


if __name__ == '__main__':
    main()
