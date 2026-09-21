"""Read-only source discovery for the explicit 3D review cohort. No approvals."""
import argparse
import json
import zipfile
from pathlib import Path

from scvi_batch import load_batch, source_entry


def inventory(batch, model_root, motion_root, legacy_archive):
    with zipfile.ZipFile(legacy_archive) as archive:
        members = {item.filename: item for item in archive.infolist()}
    results = []
    for candidate in load_batch(batch):
        entry = source_entry(candidate, model_root, motion_root)
        member = f"Gen1/pm{candidate['pm']:04d}_00.blend"
        legacy = members.get(member)
        entry['legacy_candidate'] = ({'archive': str(legacy_archive.resolve()),
                                      'member': member, 'bytes': legacy.file_size,
                                      'crc32': f'{legacy.CRC:08x}'} if legacy else None)
        entry['review_route'] = ('scvi_candidate' if 'missing_model' not in entry['warnings']
                                 and 'missing_all_motions' not in entry['warnings']
                                 else 'legacy_blend_inspection_required' if legacy
                                 else 'source_missing')
        entry['review_approved'] = False
        entry['variant_status'] = {
            'normal': 'source_found_not_rendered' if entry['review_route'] != 'source_missing' else 'missing',
            'shiny': 'scvi_material_source_found_not_rendered' if 'missing_official_rare_albedo' not in entry['warnings']
                     else 'unverified',
        }
        results.append(entry)
    return {'schema': 1, 'purpose': 'phase5_source_inventory_not_visual_certification',
            'entries': results}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batch', type=Path, default=Path(__file__).with_name('phase5_review_batch.json'))
    parser.add_argument('--model-root', type=Path, required=True)
    parser.add_argument('--motion-root', type=Path, required=True)
    parser.add_argument('--legacy-archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = inventory(args.batch, args.model_root, args.motion_root, args.legacy_archive)
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / 'inventory.json').write_text(json.dumps(report, indent=2) + '\n')
    for entry in report['entries']:
        actions = sum(value is not None for value in entry['motions'].values())
        print(f"{entry['species']}: {entry['review_route']}; actions={actions}/7; "
              f"motions={entry['motions_available']}; shiny={entry['variant_status']['shiny']}")


if __name__ == '__main__':
    main()
