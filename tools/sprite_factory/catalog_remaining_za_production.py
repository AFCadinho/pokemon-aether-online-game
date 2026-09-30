"""Import explicitly mapped remaining ZA pairs for review, without admission."""

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import re
import subprocess

from catalog_shiny_za_17_probe import probe, write


def validate_identity(row):
    """Require the mapped developer number and default form before any writes."""
    name = row['species']
    if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', name):
        raise ValueError('Invalid species directory identity')
    member = Path(row['legacy_source']['member']).name
    match = re.fullmatch(r'pm(\d{4})(?:_\d{2}){0,2}\.blend', member)
    if not match or row['resource_id'] != 'pm' + match[1]:
        raise ValueError('ZA developer number differs from mapped archive member')
    if row['za_identity'] != row['resource_id'] + '_00_00':
        raise ValueError('This intake accepts only the explicitly mapped default ZA form')


def process(row, root, output):
    try:
        validate_identity(row)
        return probe(row, root, output)
    except (OSError, ValueError, KeyError, IndexError, subprocess.SubprocessError) as error:
        return {'species': row.get('species', ''), 'status': 'held',
                'reason': str(error), 'runtime_approved': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', type=Path, required=True)
    parser.add_argument('--source-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--workers', type=int, choices=(1, 2), default=2)
    args = parser.parse_args()
    rows = json.loads(args.inventory.read_text())['entries']
    if len({row['species'] for row in rows}) != len(rows):
        raise ValueError('Duplicate species in ZA intake')
    output, root = args.output.resolve(), args.source_root.resolve()
    # Existing evidence must remain immutable; use a new output for a rerun.
    output.mkdir(parents=True, exist_ok=False)
    results = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for result in pool.map(lambda row: process(row, root, output), rows):
            results.append(result)
            write(output / 'status.json', {
                'schema': 1, 'runtime_approved': False, 'processed': len(results),
                'total': len(rows), 'counts': dict(Counter(r['status'] for r in results)),
                'entries': results})
            print(len(results), result['species'], result['status'],
                  result.get('reason', ''), flush=True)


if __name__ == '__main__':
    main()
