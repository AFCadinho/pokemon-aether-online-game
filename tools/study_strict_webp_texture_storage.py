#!/usr/bin/env python3
"""Compare exact-channel WebP without Godot's near-opaque alpha heuristic."""
import argparse
import hashlib
import io
from pathlib import Path
import struct

from PIL import Image, features
import study_lossless_texture_storage as study
from probe_v13_compression import checked_bytes, decode, encode, read, require, unpack_pck, write, Zstd
from study_new_pair_geometry import diagnostic_project

SCRIPT = 'tools/sprite_factory/strict_webp_texture_storage.gd'


def native_pixels(image, format):
    if format == 0: return image.convert('L').tobytes()
    if format == 1: return image.convert('LA').tobytes()
    if format == 4: return image.convert('RGB').tobytes()
    if format == 5: return image.convert('RGBA').tobytes()
    rgba = image.convert('RGBA').tobytes()
    if format == 2: return rgba[0::4]
    require(format == 3, 'Unsupported format')
    return bytes(v for i in range(0, len(rgba), 4) for v in rgba[i:i+2])


def exact_webp_buffer(row, source_png):
    codec = Zstd()
    raw = decode(Path(source_png).read_bytes(), codec)
    signature = struct.pack('<HH4I', 0, 2, row['format'], row['mipmaps']+1, row['width'], row['height'])
    start = raw.find(signature)
    require(start >= 4 and raw.find(signature, start+1) == -1, 'Ambiguous native PNG header')
    offset = start + 20
    result = bytearray(struct.pack('<HH4I', 0, 3, row['format'], row['mipmaps']+1, row['width'], row['height']))
    evidence = []
    for level, mip in enumerate(row['codecs']['png']['mips']):
        length, = struct.unpack_from('<I', raw, offset)
        offset += 4
        payload = raw[offset:offset+length]
        offset += length
        require(len(payload) == length and payload.startswith(b'PNG \x89PNG\r\n\x1a\n'), 'Malformed native PNG mip')
        with Image.open(io.BytesIO(payload[4:])) as source:
            source.load()
            require(source.size == (mip['width'], mip['height']), 'Changed mip dimensions')
            pixels = native_pixels(source, row['format'])
            require(hashlib.sha256(pixels).hexdigest() == mip['source_sha256'], 'Independent PNG decode differs from source')
            image = source.convert('RGBA') if row['format'] in (1, 3, 5) else source.convert('RGB')
        output = io.BytesIO()
        image.save(output, format='WEBP', lossless=True, exact=True, quality=100, method=6)
        encoded = output.getvalue()
        with Image.open(io.BytesIO(encoded)) as decoded:
            restored = native_pixels(decoded, row['format'])
        require(restored == pixels, 'External WebP changed a pixel or alpha channel')
        result += struct.pack('<I', len(encoded)) + encoded
        evidence.append({'level': level, 'source_sha256': hashlib.sha256(pixels).hexdigest(),
                         'decoded_sha256': hashlib.sha256(restored).hexdigest(), 'encoded_bytes': len(encoded)})
    require(struct.unpack_from('<I', raw, start-4)[0] == offset-start, 'Unexpected native buffer boundary')
    return bytes(result), evidence


def measure(key, asset, baseline, folder):
    folder.mkdir(parents=True, exist_ok=False)
    source = Path(baseline['source_path'])
    source_report = read(baseline['source_report'])
    original = checked_bytes(source, asset)
    members, _ = unpack_pck(original, asset)
    buffers = []
    rows = []
    for row in source_report['textures']:
        png = row['codecs'].get('png', {})
        if not png.get('exact'): continue
        payload, mips = exact_webp_buffer(row, png['path'])
        path = folder / 'buffers' / (Path(row['path']).stem + '.bin')
        path.parent.mkdir(exist_ok=True)
        path.write_bytes(payload)
        buffers.append({'path': row['path'], 'buffer_path': str(path), 'buffer_sha256': study.sha(path)})
        rows.append({'path': row['path'], 'mips': mips})
    original_script = study.SCRIPT
    try:
        study.SCRIPT = SCRIPT
        encoded = study.native_run('encode', {'asset': asset, 'path': str(source), 'buffers': buffers}, folder / 'encoded')
    finally:
        study.SCRIPT = original_script
    require(encoded['script_sha256'] == study.sha(study.ROOT / SCRIPT), 'Changed strict encoder')
    # Include original, PNG, Godot WebP and strict WebP; select by persisted native
    # size after the same Zstd framing. All selected choices are byte-exact.
    replacements = {}
    decisions = []
    previous_report = read(baseline['checkpoint'])
    previous_best = next(c for c in previous_report['candidates'] if c['codec'] == 'best')
    previous_asset = read(Path(previous_best['path']).parent / 'asset.json')
    previous_members, _ = unpack_pck(checked_bytes(previous_best['path'], previous_asset), previous_asset)
    codec = Zstd()
    for row in encoded['textures']:
        path = Path(row['native_path'])
        raw = decode(path.read_bytes(), codec)
        data = encode(raw, 262144, 19, codec)
        require(decode(data, codec) == raw, 'Native framing changed strict texture')
        path.write_bytes(data)
        name = row['path']
        old = previous_members[name]
        selected = data if len(data) < len(old) else old
        if selected != members[name]: replacements[name] = selected
        decisions.append({'path': name, 'strict_bytes': len(data), 'previous_best_bytes': len(old),
                          'selected_bytes': len(selected), 'strict_selected': selected == data,
                          'sha256': hashlib.sha256(selected).hexdigest()})
    # Preserve successful previous replacements for any unsupported strict mip.
    for name, data in previous_members.items():
        if name.startswith('textures/') and name not in {r['path'] for r in decisions} and data != members[name]:
            replacements[name] = data
    candidate, path = study.rewrite_pack(asset, original, replacements, folder)
    verified = study.native_run('verify', {'asset': candidate, 'path': str(path)}, folder / 'cold-verify')
    require(verified['models'] == source_report['models'], 'Strict cold model or animation changed')
    require({r['path']: r['state_signature'] for r in verified['textures']} ==
            {r['path']: r['state_signature'] for r in source_report['textures']}, 'Strict cold pixels changed')
    result = {'asset_id': key, 'source_bytes': asset['size_bytes'], 'candidate_bytes': candidate['size_bytes'],
              'selected_bytes': min(asset['size_bytes'], candidate['size_bytes']), 'path': str(path), 'sha256': candidate['sha256'],
              'native_non_texture_bytes_exact': True, 'cold_native_verified': True, 'textures': rows, 'decisions': decisions,
              'engine_report_sha256': study.sha(folder / 'cold-verify/report.json')}
    write(folder / 'checkpoint.json', result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--limit', type=int)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    configuration = read(args.baseline / 'configuration.json')
    require(configuration['inputs'] == {p: study.sha(study.ROOT/p) for p in study.CODE}, 'Baseline inputs changed')
    _, assets = study.catalog()
    by_id = {a['asset_id']: a for a in assets}
    ids = configuration['sample_ids'][:args.limit] if args.limit else configuration['sample_ids']
    bindings = {p: study.sha(study.ROOT/p) for p in [SCRIPT, 'tools/study_strict_webp_texture_storage.py', *study.CODE]}
    records = []
    with diagnostic_project():
        for i, key in enumerate(ids):
            matches = [p for p in args.baseline.glob(f'pair-{i:04d}*/checkpoint.json') if read(p)['asset_id'] == key]
            require(len(matches) == 1, 'Missing/ambiguous baseline checkpoint')
            folder = matches[0].parent
            baseline = {'source_path': configuration['sources'][key]['path'], 'source_report': str(folder/'source/report.json'), 'checkpoint': str(matches[0])}
            record = measure(key, by_id[key], baseline, output/f'pair-{i:04d}')
            records.append(record)
            print(f'STRICT_WEBP_PAIR_OK {i+1}/{len(ids)} {key}', flush=True)
    require(bindings == {p: study.sha(study.ROOT/p) for p in bindings}, 'Strict study code changed')
    report = {'schema': 1, 'complete': len(records) == 20, 'prototype_only': True, 'production_approved': False,
              'pairs': len(records), 'pillow_webp': features.version('webp'), 'baseline_configuration_sha256': study.sha(args.baseline/'configuration.json'),
              'inputs': bindings, 'source_sample_bytes': sum(r['source_bytes'] for r in records),
              'selected_sample_bytes': sum(r['selected_bytes'] for r in records), 'records': records}
    write(output/'report.json', report)
    print('STRICT_WEBP_COMPLETE '+str({k:v for k,v in report.items() if k not in ('records','inputs')}), flush=True)


if __name__ == '__main__': main()
