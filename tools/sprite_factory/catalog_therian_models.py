"""Build source-pinned Therian candidates using the existing native importer.

Does not publish or admit models. Both palettes use their own source material
tables; the two appearances must preserve identical geometry, skin and motion.
"""
import argparse
from pathlib import Path
import os

from catalog_galar_birds_candidates import export, material, verify, sha, read, write

ROOT = Path(__file__).resolve().parents[2]
INTAKE = Path(__file__).with_name('catalog_therian_source_intake.json')
WORK = ROOT / '.tmp/therian-models-v1'
NAMES = {'tornadus-therian': 641, 'thundurus-therian': 642, 'landorus-therian': 645}


def run(phase):
    if os.environ.get('POKEAETHER_SLOT') != ROOT.parent.name:
        raise ValueError('Run through the assigned slot-env')
    intake = read(INTAKE)
    if {r['species'] for r in intake['entries']} != set(NAMES):
        raise ValueError('Expected exactly the three Therian forms')
    WORK.mkdir(parents=True, exist_ok=True)
    if phase == 'stage':
        results = read(WORK / 'material-status.json')['entries']
        if len(results) != 3 or any(r['status'] != 'review_candidate' for r in results):
            raise ValueError('Incomplete Therian candidates')
        rows = [v for r in results for v in r['variants']]
        for row in rows:
            if sha(row['path']) != row['glb_sha256']:
                raise ValueError('Candidate changed: ' + row['species'])
        write(WORK / 'stage.json', rows)
        return
    source = Path(intake['source_root'])
    results = []
    for row in intake['entries']:
        verify(row, source)
        result = (export if phase == 'export' else material)(row, source, WORK)
        results.append({'species': row['species'], 'status': 'review_candidate', **result})
        write(WORK / (phase + '-status.json'), {'schema': 1, 'intake_sha256': sha(INTAKE),
              'runtime_approved': False, 'entries': results})
        print('THERIAN', phase, row['species'], 'OK', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('export', 'material', 'stage'))
    run(parser.parse_args().phase)
