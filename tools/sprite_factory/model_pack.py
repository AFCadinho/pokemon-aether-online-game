"""Build/install an offline, hash-approved 3D model pack; never change Settings.

Only the checked-in reviewed scene bytes are permitted. Archives contain a
portable catalog and self-contained scenes, never scripts or import caches.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import tempfile
import zipfile

REGISTRY = Path(__file__).parents[2] / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
KIND = 'pokeaether-reviewed-model-pack'
MAX_MANIFEST = 1024 * 1024
MAX_FILE = 128 * 1024 * 1024
MAX_TOTAL = 512 * 1024 * 1024


def encode(value):
    return (json.dumps(value, sort_keys=True, indent=2, allow_nan=False) + '\n').encode()


def read_json(path):
    if path.stat().st_size > MAX_MANIFEST:
        raise ValueError('Oversized catalog')
    return json.loads(path.read_bytes())


def digest_stream(source, target=None):
    digest, size = hashlib.sha256(), 0
    while chunk := source.read(1024 * 1024):
        size += len(chunk)
        if size > MAX_FILE:
            raise ValueError('Oversized scene')
        digest.update(chunk)
        if target is not None:
            target.write(chunk)
    return digest.hexdigest(), size


def identity(entry):
    species, variant = entry.get('species'), entry.get('variant', 'normal')
    if not isinstance(species, str) or variant not in ('normal', 'shiny') or '@' in species:
        raise ValueError('Invalid explicit model identity')
    return species + ('@shiny' if variant == 'shiny' else '')


def approved_digest(model, digest):
    return bool(model) and (digest == model['sha256'] or digest in model.get('previous_sha256', []))


def validate_manifest(manifest, registry):
    if (not isinstance(manifest, dict) or manifest.get('schema') != 1
            or manifest.get('kind') != KIND or manifest.get('godot') != '4.6'
            or manifest.get('qualification_sha256') != registry['qualification_sha256']):
        raise ValueError('Unsupported model pack/qualification')
    entries = manifest.get('entries')
    if not isinstance(entries, list) or not 0 < len(entries) <= len(registry['models']):
        raise ValueError('Invalid model count')
    seen, total = set(), 0
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError('Invalid model entry')
        key = identity(entry)
        approved = registry['models'].get(key)
        size = entry.get('bytes')
        if (key in seen or not approved_digest(approved, entry.get('runtime_sha256'))
                or entry.get('runtime_schema') != 1
                or entry.get('runtime_path') != 'models/' + str(entry.get('runtime_sha256')) + '.scn'
                or type(size) is not int or not 0 < size <= MAX_FILE):
            raise ValueError('Unapproved, duplicate or invalid model entry')
        seen.add(key)
        total += size
    if total > MAX_TOTAL:
        raise ValueError('Oversized model pack')
    return entries


def zip_info(name):
    info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    info.create_system = 3
    info.external_attr = (stat.S_IFREG | 0o644) << 16
    info.compress_type = zipfile.ZIP_STORED # SCN resources are already compressed.
    return info


def build(catalog, output, registry_path=REGISTRY):
    catalog, output = Path(catalog).resolve(), Path(output).absolute()
    if output.exists() or output.is_symlink():
        raise ValueError('Output already exists')
    registry, source = read_json(Path(registry_path)), read_json(catalog)
    if not isinstance(source, list) or not 0 < len(source) <= len(registry['models']):
        raise ValueError('Expected the admitted local catalog array')
    entries, sources = [], {}
    for item in source:
        if not isinstance(item, dict):
            raise ValueError('Invalid source entry')
        key = identity(item)
        approved = registry['models'].get(key)
        if not approved_digest(approved, item.get('runtime_sha256')):
            raise ValueError('Source is not approved')
        path = Path(item['runtime_path'])
        if not path.is_absolute():
            path = catalog.parent / path
        if path.is_symlink() or not path.is_file():
            raise ValueError('Source must be a regular scene')
        with path.open('rb') as stream:
            digest, size = digest_stream(stream)
        if digest != item['runtime_sha256']:
            raise ValueError('Source scene hash mismatch')
        entry = dict(species=item['species'], variant=item.get('variant', 'normal'),
                     runtime_schema=1, runtime_sha256=digest,
                     runtime_path='models/' + digest + '.scn', bytes=size)
        entries.append(entry)
        sources[entry['runtime_path']] = path
    manifest = dict(schema=1, kind=KIND, godot='4.6',
        qualification_sha256=registry['qualification_sha256'],
        entries=sorted(entries, key=identity))
    validate_manifest(manifest, registry)
    output.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.model-pack-', suffix='.zip', dir=output.parent)
    os.close(fd)
    try:
        with zipfile.ZipFile(temporary, 'w', allowZip64=False) as archive:
            archive.writestr(zip_info('catalog.json'), encode(manifest))
            for entry in manifest['entries']:
                with sources[entry['runtime_path']].open('rb') as stream:
                    with archive.open(zip_info(entry['runtime_path']), 'w') as target:
                        digest, size = digest_stream(stream, target)
                if digest != entry['runtime_sha256'] or size != entry['bytes']:
                    raise ValueError('Source changed during packaging')
        # Exclusive publication: even a concurrently created output is not overwritten.
        os.link(temporary, output)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return output


def verify(directory, registry_path=REGISTRY):
    directory = Path(directory)
    if directory.is_symlink() or (directory / 'catalog.json').is_symlink() or (directory / 'models').is_symlink():
        raise ValueError('Linked pack paths are not permitted')
    manifest = read_json(directory / 'catalog.json')
    entries = validate_manifest(manifest, read_json(Path(registry_path)))
    for entry in entries:
        path = directory / entry['runtime_path']
        if path.is_symlink() or not path.is_file():
            raise ValueError('Missing/linked scene')
        with path.open('rb') as stream:
            digest, size = digest_stream(stream)
        if digest != entry['runtime_sha256'] or size != entry['bytes']:
            raise ValueError('Installed scene hash/size mismatch')
    return directory / 'catalog.json'


def install(archive_path, directory, registry_path=REGISTRY):
    archive_path, directory = Path(archive_path), Path(directory).absolute()
    if directory.exists() or directory.is_symlink():
        raise ValueError('Install destination already exists; use a new version directory')
    if archive_path.stat().st_size > MAX_TOTAL + MAX_MANIFEST + 65536:
        raise ValueError('Oversized archive')
    registry = read_json(Path(registry_path))
    staging = None
    try:
        with zipfile.ZipFile(archive_path) as archive:
            infos = archive.infolist()
            names = [info.filename for info in infos]
            if (len(names) != len(set(names)) or not 1 < len(names) <= len(registry['models']) + 1
                    or names.count('catalog.json') != 1):
                raise ValueError('Unexpected or duplicate archive members')
            for info in infos:
                mode = info.external_attr >> 16
                if (info.flag_bits & 1 or info.is_dir() or stat.S_ISLNK(mode)
                        or stat.S_IFMT(mode) not in (0, stat.S_IFREG)
                        or info.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
                        or info.file_size > MAX_FILE):
                    raise ValueError('Unsupported archive member')
            if archive.getinfo('catalog.json').file_size > MAX_MANIFEST:
                raise ValueError('Oversized manifest')
            manifest = json.loads(archive.read('catalog.json'))
            entries = validate_manifest(manifest, registry)
            if set(names) != {'catalog.json'} | {e['runtime_path'] for e in entries}:
                raise ValueError('Archive contains undeclared files')
            for entry in entries:
                if archive.getinfo(entry['runtime_path']).file_size != entry['bytes']:
                    raise ValueError('Scene size mismatch')
            directory.parent.mkdir(parents=True, exist_ok=True)
            staging = Path(tempfile.mkdtemp(prefix='.model-install-', dir=directory.parent))
            (staging / 'models').mkdir()
            (staging / 'catalog.json').write_bytes(encode(manifest))
            for entry in entries:
                with archive.open(entry['runtime_path']) as source:
                    with (staging / entry['runtime_path']).open('xb') as target:
                        digest, size = digest_stream(source, target)
                if digest != entry['runtime_sha256'] or size != entry['bytes']:
                    raise ValueError('Scene hash/size mismatch')
        verify(staging, registry_path)
        if directory.exists() or directory.is_symlink():
            raise ValueError('Install destination appeared during extraction')
        staging.rename(directory)
        staging = None
    finally:
        if staging is not None:
            shutil.rmtree(staging) # Only the private directory created above.
    return directory / 'catalog.json'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    pack = commands.add_parser('build')
    pack.add_argument('catalog', type=Path)
    pack.add_argument('output', type=Path)
    unpack = commands.add_parser('install')
    unpack.add_argument('archive', type=Path)
    unpack.add_argument('directory', type=Path)
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'build':
            result = build(args.catalog, args.output)
        elif args.command == 'install':
            result = install(args.archive, args.directory)
        else:
            result = verify(args.directory)
    except (ValueError, OSError, KeyError, TypeError, zipfile.BadZipFile) as error:
        parser.exit(1, f'Model pack rejected: {error}\n')
    print(result)


if __name__ == '__main__':
    main()
