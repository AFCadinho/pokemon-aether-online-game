#!/usr/bin/env python3
"""Package only verified model test assets; relocate them on native CI runners."""
import argparse
import copy
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import urllib.request
import zipfile

MAX_PACKAGE = 2 * 1024**3
MAX_MEMBER = 512 * 1024**2
MAX_JSON = 1024**2


def sha_file(path):
    with Path(path).open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def safe_member(name):
    path = PurePosixPath(name)
    if not name or '\\' in name or ':' in name or path.is_absolute() or path.as_posix() != name or any(p in ['', '.', '..'] for p in name.split('/')):
        raise ValueError('Unsafe fixture member')
    if name not in ['fixture.json', 'manifest.json', 'indexes/original.json', 'indexes/native-256k.json'] and not re.fullmatch(r'archives/[0-9a-f]{64}\.zip', name):
        raise ValueError('Fixture contains a file outside the model-input allowlist')
    return path


def package(fixture_path, output):
    # Decode equality is rechecked in preparation. Runtime CI then exercises
    # the real native engine reader/installer against these exact encoded bytes.
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/sprite_factory'))
    from native_resource_compression_probe import Zstd, decode
    codec = Zstd()
    source = json.loads(Path(fixture_path).read_text())
    if not source.get('prototype_only') or source.get('production_approved'):
        raise ValueError('Expected an unpublished qualification fixture')
    selected = [s for s in source['stages'] if s['label'] in ['original', 'native-256k']]
    if [s['label'] for s in selected] != ['original', 'native-256k']:
        raise ValueError('Missing original/native-256k stages')
    root = Path(__file__).resolve().parents[2]
    current = {a['asset_id']: a for a in json.loads((root / 'release/approved_3d_bundles_v10_index.json').read_text())['assets']}
    portable = {k: copy.deepcopy(source[k]) for k in ['prototype_only', 'production_approved', 'source_report_sha256', 'libzstd', 'profiles', 'failure_asset_id']}
    portable.update(stages=[], routes={})
    files = {}
    decoded = {}
    for stage in selected:
        index_path = Path(stage['index_path'])
        if sha_file(index_path) != stage['descriptor']['sha256'] or index_path.stat().st_size != stage['descriptor']['sizeBytes']:
            raise ValueError('Fixture index checksum mismatch')
        index = json.loads(index_path.read_text())
        if sorted(a['asset_id'] for a in index['assets']) != sorted(stage['descriptor']['requiredAssetIds']):
            raise ValueError('Fixture index identities differ from its pin')
        for asset in index['assets']:
            if stage['label'] == 'original' and current.get(asset['asset_id'], {}).get('sha256') != asset['sha256']:
                raise ValueError('Original fixture is not part of the currently pinned release')
            archive_path = Path(source['routes']['/' + asset['object_key']])
            if archive_path.stat().st_size != asset['size_bytes'] or sha_file(archive_path) != asset['sha256']:
                raise ValueError('Fixture bundle checksum mismatch')
            member = 'archives/' + asset['sha256'] + '.zip'
            files[member] = archive_path
            portable['routes']['/' + asset['object_key']] = member
            with zipfile.ZipFile(archive_path) as archive:
                manifest = json.loads(archive.read('bundle.json'))
                for appearance in asset['appearances']:
                    identity = appearance['runtime_identity']
                    row = next(a for a in manifest['appearances'] if a['variant'] == appearance['variant'])
                    data = archive.read(row['runtime_path'])
                    if hashlib.sha256(data).hexdigest() != appearance['runtime_sha256'] or len(data) != row['bytes']:
                        raise ValueError('Fixture model checksum mismatch')
                    raw_hash = hashlib.sha256(decode(data, codec)).hexdigest()
                    if stage['label'] == 'original':
                        decoded[identity] = raw_hash
                    elif decoded.get(identity) != raw_hash:
                        raise ValueError('Candidate has changed decoded model data')
        name = 'indexes/' + stage['label'] + '.json'
        files[name] = index_path
        moved = copy.deepcopy(stage)
        moved['index_path'] = name
        portable['stages'].append(moved)
        portable['routes']['/' + stage['descriptor']['object_key']] = name
    if set(decoded) != set(selected[1]['models']):
        raise ValueError('Candidate appearance set differs from originals')
    payload = (json.dumps(portable, indent=2) + '\n').encode()
    members = {name: {'bytes': path.stat().st_size, 'sha256': sha_file(path)} for name, path in files.items()}
    members['fixture.json'] = {'bytes': len(payload), 'sha256': hashlib.sha256(payload).hexdigest()}
    manifest = {'schema': 1, 'kind': 'pokeaether-native-qualification-input', 'files': members,
                'decoded_model_sha256': decoded, 'production_approved': False}
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        raise ValueError('A fresh package output is required')
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_STORED) as archive:
        for name, path in sorted(files.items()):
            safe_member(name)
            info = zipfile.ZipInfo(name, (2026, 10, 6, 0, 0, 0))
            info.external_attr = 0o100644 << 16
            with path.open('rb') as source_file, archive.open(info, 'w') as target:
                shutil.copyfileobj(source_file, target, 1024**2)
        archive.writestr('fixture.json', payload)
        archive.writestr('manifest.json', json.dumps(manifest, indent=2) + '\n')
    if output.stat().st_size > MAX_PACKAGE:
        raise ValueError('Qualification package exceeds the bound')
    receipt = {'sha256': sha_file(output), 'bytes': output.stat().st_size, 'bundles': len(selected[0]['models']) // 2,
               'appearances': len(decoded), 'decoded_equality': True, 'production_approved': False}
    output.with_suffix('.receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


def unpack(archive_path, expected_sha, destination):
    if not re.fullmatch('[0-9a-f]{64}', expected_sha) or sha_file(archive_path) != expected_sha:
        raise ValueError('Qualification input checksum mismatch')
    if Path(archive_path).stat().st_size > MAX_PACKAGE:
        raise ValueError('Qualification input exceeds the bound')
    destination = Path(destination).resolve()
    if destination.exists():
        raise ValueError('A fresh fixture destination is required')
    with zipfile.ZipFile(archive_path) as archive:
        infos = archive.infolist()
        if len(infos) > 2600 or len({i.filename for i in infos}) != len(infos):
            raise ValueError('Duplicate or excessive fixture members')
        total = 0
        for info in infos:
            safe_member(info.filename)
            mode = (info.external_attr >> 16) & 0o170000
            limit = MAX_JSON if info.filename.endswith('.json') else MAX_MEMBER
            if mode not in [0, stat.S_IFREG] or info.is_dir() or info.flag_bits & 1 or not 0 < info.file_size <= limit:
                raise ValueError('Invalid fixture member type or size')
            total += info.file_size
        if total > MAX_PACKAGE:
            raise ValueError('Extracted fixture exceeds the bound')
        manifest = json.loads(archive.read('manifest.json'))
        if manifest.get('schema') != 1 or manifest.get('kind') != 'pokeaether-native-qualification-input' or manifest.get('production_approved') is not False:
            raise ValueError('Unsupported qualification package')
        if set(manifest['files']) != {i.filename for i in infos} - {'manifest.json'}:
            raise ValueError('Package contains undeclared files')
        destination.mkdir(parents=True)
        for info in infos:
            target = destination / info.filename
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(info) as source, target.open('xb') as writer:
                shutil.copyfileobj(source, writer, 1024**2)
            if info.filename != 'manifest.json' and (target.stat().st_size != manifest['files'][info.filename]['bytes'] or sha_file(target) != manifest['files'][info.filename]['sha256']):
                raise ValueError('Extracted qualification input failed verification')
    fixture_path = destination / 'fixture.json'
    fixture = json.loads(fixture_path.read_text())
    for name in fixture['routes'].values():
        safe_member(name)
        if name not in manifest['files']:
            raise ValueError('Fixture route points outside the package')
    fixture['routes'] = {url: str(destination / name) for url, name in fixture['routes'].items()}
    for stage in fixture['stages']:
        name = stage['index_path']
        safe_member(name)
        if name not in manifest['files']:
            raise ValueError('Fixture index points outside the package')
        stage['index_path'] = str(destination / name)
    fixture_path.write_text(json.dumps(fixture, indent=2) + '\n')
    (destination / 'input-receipt.json').write_text(json.dumps({'input_sha256': expected_sha, 'decoded_model_sha256': manifest['decoded_model_sha256']}, indent=2) + '\n')
    return fixture_path


def fetch(url, destination, maximum=MAX_PACKAGE):
    if not url.startswith('https://'):
        raise ValueError('Qualification downloads require HTTPS')
    destination = Path(destination)
    if destination.exists():
        raise ValueError('A fresh download path is required')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=60) as response, destination.open('xb') as output:
        if not response.url.startswith('https://'):
            raise ValueError('HTTPS downgrade rejected')
        received = 0
        while chunk := response.read(1024**2):
            received += len(chunk)
            if received > maximum:
                raise ValueError('Qualification download exceeds the bound')
            output.write(chunk)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    pack = commands.add_parser('pack'); pack.add_argument('fixture', type=Path); pack.add_argument('output', type=Path)
    extract = commands.add_parser('unpack'); extract.add_argument('archive', type=Path); extract.add_argument('sha256'); extract.add_argument('destination', type=Path)
    download = commands.add_parser('download'); download.add_argument('url'); download.add_argument('output', type=Path)
    args = parser.parse_args()
    if args.command == 'pack':
        root = Path(__file__).resolve().parents[2]
        args.output.resolve().relative_to(root / '.tmp')
        package(args.fixture, args.output)
    elif args.command == 'unpack':
        print(unpack(args.archive, args.sha256, args.destination))
    else:
        fetch(args.url, args.output)


if __name__ == '__main__':
    main()
