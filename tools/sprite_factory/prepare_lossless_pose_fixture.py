#!/usr/bin/env python3
"""Make six verified original/native rig fixtures for the real pose check."""
import argparse
import json
from pathlib import Path
import zipfile

from native_resource_compression_probe import Zstd, decode, encode, sha
from native_bundle_validation_fixture import write_json
from prepare_native_compressed_catalog import file_sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archives', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.relative_to(root / '.tmp')
    output.mkdir(parents=True, exist_ok=False)
    index_bytes = (root / 'release/approved_3d_bundles_v10_index.json').read_bytes()
    index = json.loads(index_bytes)
    ledger_path = root / 'resources/battle/model_animations/lossless_model_revisions.json'
    ledger = json.loads(ledger_path.read_text())
    originals, helpers = {}, {}
    for name in ['gliscor_flight', 'mega_garchomp_standing', 'charmander_breath']:
        data = json.loads((ledger_path.parent / (name + '.json')).read_text())
        for identity, digest in data['models'].items():
            originals[identity], helpers[identity] = digest, name
    if set(originals) != set(ledger['models']) or len(originals) != 6:
        raise ValueError('Correction ledger does not match six measured rigs')
    archives = json.loads(args.archives.read_text())
    codec = Zstd()
    if codec.version != ledger['encoding']['libzstd']:
        raise ValueError('Use the qualified libzstd version for reproducible fixture hashes')
    entries = []
    for asset in index['assets']:
        selected = [a for a in asset['appearances'] if a['runtime_identity'] in originals]
        if not selected:
            continue
        source = Path(archives[Path(asset['object_key']).name])
        if file_sha(source) != asset['sha256'] or source.stat().st_size != asset['size_bytes']:
            raise ValueError('Unverified original archive')
        with zipfile.ZipFile(source) as archive:
            for appearance in selected:
                identity = appearance['runtime_identity']
                revision = ledger['models'][identity]
                original = archive.read('models/' + appearance['variant'] + '.scn')
                if sha(original) != originals[identity] or originals[identity] != revision['source_sha256'] or sha(original) != appearance['runtime_sha256']:
                    raise ValueError('Source rig changed: ' + identity)
                raw = decode(original, codec)
                candidate = encode(raw, 262144, 9, codec)
                if decode(candidate, codec) != raw or sha(raw) != revision['raw_sha256'] or sha(candidate) != revision['sha256']:
                    raise ValueError('Lossless correction revision changed: ' + identity)
                before, after = output / (identity + '-source.scn'), output / (identity + '-native.scn')
                before.write_bytes(original)
                after.write_bytes(candidate)
                entries.append({'identity': identity, 'helper': helpers[identity],
                    'source_path': str(before), 'candidate_path': str(after), 'raw_sha256': sha(raw)})
        if file_sha(source) != asset['sha256']:
            raise ValueError('Original archive changed during fixture creation')
    if len(entries) != 6:
        raise ValueError('Missing source rigs')
    write_json(output / 'fixture.json', {'entries': entries, 'index_sha256': sha(index_bytes),
        'ledger_sha256': file_sha(ledger_path), 'libzstd': codec.version,
        'source_script_sha256': file_sha(Path(__file__)), 'raw_byte_exact': True})
    print('LOSSLESS_POSE_FIXTURE_READY', len(entries), flush=True)


if __name__ == '__main__':
    main()
