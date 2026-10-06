#!/usr/bin/env python3
"""Prepare an unpublished lossless catalog; never alter approval or release pins.

Read verified approved archives in place. Preserve uncompressed RSRC files and
containers that would grow. Keep all ZIP members, and retain original object
references for rollback. A draft index is written only after every pair passes.
"""
import argparse
import copy
import json
from pathlib import Path
import zipfile

from native_resource_compression_probe import Zstd, decode, encode, sha
from native_bundle_validation_fixture import write_json, write_zip


def file_sha(path):
    import hashlib
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def transform(data, codec):
    if data[:4] == b'RSRC' and data[-4:] == b'RSRC':
        return data, {'raw_sha256': sha(data[4:]), 'raw_bytes': len(data) - 4,
                      'reason': 'Uncompressed RSRC retained unchanged'}
    raw = decode(data, codec)
    candidate = encode(raw, 262144, 9, codec)
    if decode(candidate, codec) != raw:
        raise ValueError('Native resource stream changed')
    receipt = {'raw_sha256': sha(raw), 'raw_bytes': len(raw), 'raw_byte_exact': True}
    if len(candidate) >= len(data):
        receipt['reason'] = 'Original retained: candidate would not save space'
        candidate = data
    return candidate, receipt


def prepare_asset(original_asset, source, directory, registry, codec):
    if source.stat().st_size != original_asset['size_bytes'] or file_sha(source) != original_asset['sha256']:
        raise ValueError('Source archive hash/size mismatch: ' + original_asset['asset_id'])
    asset = copy.deepcopy(original_asset)
    rows, models = [], {}
    with zipfile.ZipFile(source) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError('Duplicate ZIP members')
        # Preserve auxiliary members too; no re-export, image conversion or
        # silent removal of author-supplied bundle content.
        payloads = {name: archive.read(name) for name in names if name != 'bundle.json'}
        manifest = json.loads(archive.read('bundle.json'))
        for field in ['species_id', 'form_id', 'version']:
            if manifest[field] != asset[field]:
                raise ValueError('Source manifest mismatch: ' + field)
        expected = {a['variant'] for a in asset['appearances']}
        if len(expected) != 2 or expected != {'normal', 'shiny'} or len(manifest['appearances']) != 2:
            raise ValueError('Exactly one normal/shiny pair required')
        if {a['variant'] for a in manifest['appearances']} != expected:
            raise ValueError('Source manifest appearance mismatch')
        for appearance in asset['appearances']:
            identity = appearance['runtime_identity']
            model = copy.deepcopy(registry['models'][identity])
            original = payloads['models/' + appearance['variant'] + '.scn']
            digest = sha(original)
            manifest_row = next(a for a in manifest['appearances'] if a['variant'] == appearance['variant'])
            if digest != appearance['runtime_sha256'] or digest != manifest_row['runtime_sha256'] or len(original) != manifest_row['bytes']:
                raise ValueError('Source appearance hash/size mismatch: ' + identity)
            if digest not in [model['sha256'], *model.get('previous_sha256', [])]:
                raise ValueError('Source appearance is not approved: ' + identity)
            candidate, receipt = transform(original, codec)
            receipt.update(identity=identity, source_sha256=digest, source_bytes=len(original),
                           candidate_sha256=sha(candidate), candidate_bytes=len(candidate))
            rows.append(receipt)
            payloads['models/' + appearance['variant'] + '.scn'] = candidate
            appearance['runtime_sha256'] = sha(candidate)
            manifest_row.update(runtime_sha256=sha(candidate), bytes=len(candidate))
            model['sha256'] = sha(candidate)
            model['cache_source_bytes'] = len(original)
            model['previous_sha256'] = sorted(set([digest, *model.get('previous_sha256', [])]) - {sha(candidate)})
            models[identity] = model
    changed = any(r['source_sha256'] != r['candidate_sha256'] for r in rows)
    target = source
    if changed:
        asset['version'] += 1
        manifest['version'] = asset['version']
        temporary = directory / (asset['species_id'] + '-' + asset['form_id'] + '.zip')
        write_zip(temporary, manifest, payloads)
        asset['sha256'] = file_sha(temporary)
        asset['size_bytes'] = temporary.stat().st_size
        basename = 'v' + str(asset['version']) + '-' + asset['sha256'] + '.zip'
        target = directory / basename
        temporary.rename(target)
        asset['object_key'] = 'optional-assets/pokemon_3d/' + asset['species_id'] + '/' + asset['form_id'] + '/' + basename
        with zipfile.ZipFile(target) as archive:
            if json.loads(archive.read('bundle.json')) != manifest or archive.namelist() != ['bundle.json', *payloads]:
                raise ValueError('Candidate ZIP manifest or member set changed')
            for name, data in payloads.items():
                if archive.read(name) != data:
                    raise ValueError('Candidate ZIP verification failed: ' + name)
    if file_sha(source) != original_asset['sha256']:
        raise ValueError('Source archive changed during preparation')
    return asset, models, {'asset_id': asset['asset_id'], 'changed': changed, 'entries': rows,
        'source_archive': str(source.resolve()), 'source_asset': original_asset,
        'candidate_archive': str(target.resolve()), 'candidate_asset': asset}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archives', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.relative_to(root / '.tmp')
    output.mkdir(parents=True, exist_ok=False)
    directory = output / 'archives'
    directory.mkdir()
    index_path = root / 'release/approved_3d_bundles_v10_index.json'
    index_bytes = index_path.read_bytes()
    index = json.loads(index_bytes)
    registry_path = root / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    registry_bytes = registry_path.read_bytes()
    registry = json.loads(registry_bytes)
    archives = json.loads(args.archives.read_text())
    missing = [a['asset_id'] for a in index['assets'] if not Path(archives.get(Path(a['object_key']).name, '/nonexistent')).is_file()]
    if missing:
        write_json(output / 'missing.json', missing)
        raise ValueError('Missing verified source archives: ' + str(len(missing)))
    codec = Zstd()
    report = {'schema': 1, 'complete': False, 'prototype_only': True, 'production_approved': False,
        'index_sha256': sha(index_bytes), 'registry_sha256': sha(registry_bytes),
        'source_script_sha256': sha(Path(__file__).read_bytes()), 'libzstd': codec.version,
        'block_size': 262144, 'level': 9, 'assets': []}
    write_json(output / 'report.json', report)
    models, assets = {}, []
    with (output / 'receipts.jsonl').open('x') as receipts:
        for i, original in enumerate(index['assets']):
            path = Path(archives[Path(original['object_key']).name])
            asset, new_models, receipt = prepare_asset(original, path, directory, registry, codec)
            if set(models) & set(new_models):
                raise ValueError('Duplicate runtime identities')
            models.update(new_models)
            assets.append(asset)
            report['assets'].append(receipt)
            receipts.write(json.dumps(receipt) + '\n')
            receipts.flush()
            if (i + 1) % 25 == 0 or i + 1 == len(index['assets']):
                print('NATIVE_CATALOG_PREPARED', i + 1, '/', len(index['assets']), flush=True)
    if sha(index_path.read_bytes()) != sha(index_bytes) or sha(registry_path.read_bytes()) != sha(registry_bytes):
        raise ValueError('Tracked approval inputs changed during preparation')
    draft = copy.deepcopy(index)
    draft.update(catalog_revision='lossless-native-256k-draft', assets=assets,
                 prototype_only=True, production_approved=False)
    (output / 'draft-index.json').write_text(json.dumps(draft, separators=(',', ':')) + '\n')
    # This standalone candidate metadata is never placed in an active catalog.
    write_json(output / 'draft-models.json', {'models': models, 'prototype_only': True,
        'production_approved': False, 'source_registry_sha256': sha(registry_bytes)})
    write_json(output / 'rollback-index.json', index)
    report.update(complete=True, pairs=len(assets), appearances=len(models),
        original_download_bytes=sum(a['size_bytes'] for a in index['assets']),
        candidate_download_bytes=sum(a['size_bytes'] for a in assets),
        original_scene_bytes=sum(r['source_bytes'] for a in report['assets'] for r in a['entries']),
        candidate_scene_bytes=sum(r['candidate_bytes'] for a in report['assets'] for r in a['entries']),
        changed_pairs=sum(a['changed'] for a in report['assets']),
        draft_index_sha256=file_sha(output / 'draft-index.json'),
        draft_models_sha256=file_sha(output / 'draft-models.json'),
        rollback_index_sha256=file_sha(output / 'rollback-index.json'))
    write_json(output / 'report.json', report)
    print('NATIVE_CATALOG_COMPLETE', report['original_download_bytes'], report['candidate_download_bytes'], flush=True)


if __name__ == '__main__':
    main()
