"""Summarize measured payloads; never present them as actual runtime RSS/VRAM."""
import argparse
import json
from collections import defaultdict
from pathlib import Path


def unique(items, size):
    return sum({r['sha256']: r[size] for r in items}.values())


def summarize(report):
    rows = [r for r in report['entries'] if not r['control']]
    textures = [t for r in rows for t in r['textures']]
    roles = defaultdict(lambda: {'payload_bytes': 0, 'independent_zstd_bytes': 0, 'count': 0})
    for t in textures:
        labels = [v for v in t['roles'] if v != 'other']
        label = '+'.join(sorted(labels)) or 'other'
        roles[label]['payload_bytes'] += t['payload_bytes']
        roles[label]['independent_zstd_bytes'] += t['zstd_bytes']
        roles[label]['count'] += 1
    components = defaultdict(int)
    for r in rows:
        for c in r['components']:
            components[c['kind']] += c['bytes']
    per_model_unique = sum(unique(r['textures'], 'zstd_bytes') for r in rows)
    all_texture_zstd = sum(t['zstd_bytes'] for t in textures)
    global_unique = unique(textures, 'zstd_bytes')
    pairs = defaultdict(dict)
    for r in report['entries']:
        if r['control']:
            species = r['species'].removesuffix('@shiny')
            variant = 'shiny' if r['species'].endswith('@shiny') else r['variant']
            pairs[species][variant] = r
    shiny = []
    for species, pair in pairs.items():
        if set(pair) != {'normal', 'shiny'}:
            continue
        normal, alt = pair['normal'], pair['shiny']
        baseline_tex = {t['sha256'] for t in normal['textures']}
        new_tex = [t for t in alt['textures'] if t['sha256'] not in baseline_tex]
        identical = {}
        for kind in ('mesh', 'animation', 'skin'):
            a = {c['sha256'] for c in normal['components'] if c['kind'] == kind}
            b = {c['sha256'] for c in alt['components'] if c['kind'] == kind}
            identical[kind] = {'normal_count': len(a), 'shiny_count': len(b), 'shared_count': len(a & b)}
        shiny.append({'species': species, 'normal_disk_bytes': normal['disk_bytes'],
                      'shiny_disk_bytes': alt['disk_bytes'],
                      'normal_unique_texture_zstd_bytes': unique(normal['textures'], 'zstd_bytes'),
                      'incremental_unique_texture_zstd_bytes': unique(new_tex, 'zstd_bytes'),
                      'components': identical})
    return {'catalog_sha256': report['catalog_sha256'], 'count': len(rows),
            'disk_bytes': sum(r['disk_bytes'] for r in rows),
            'resaved_compressed_bytes': sum(r['resaved_compressed_bytes'] for r in rows),
            'outer_zstd_bytes': sum(r['outer_zstd_bytes'] for r in rows),
            'headers': sorted({r['file_header'] for r in rows}),
            'texture_roles': dict(roles), 'component_standalone_compressed_bytes': dict(components),
            'skeleton_serialized_bytes': sum(r['skeleton_serialized_bytes'] for r in rows),
            'texture_unique_payload_bytes': unique(textures, 'payload_bytes'),
            'texture_within_model_duplicate_zstd_bytes': all_texture_zstd - per_model_unique,
            'texture_between_model_duplicate_zstd_bytes': per_model_unique - global_unique,
            'texture_global_unique_zstd_bytes': global_unique,
            'shiny_pairs': shiny, 'rejected': report.get('rejected', []),
            'models': [{k: r[k] for k in ('species', 'source_sha256', 'disk_bytes')} for r in rows]}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('report', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    result = summarize(json.loads(args.report.read_text()))
    pack = args.report.parent / 'catalog.pck'
    result['pck_bytes'] = pack.stat().st_size
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'models'}, indent=2))
