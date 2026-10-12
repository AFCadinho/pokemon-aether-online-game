"""Inspect all legacy source families needed by the missing-form batch."""
import os
from pathlib import Path
import shutil
import zipfile

from alternate_forms_batch import HERE, ROOT, WORK, SOURCE, INTAKE, read, write, sha
from catalog_shiny_za_17_probe import run_flatpak


def main():
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name
    spec = read(INTAKE)
    selected = {(a['archive'], a['member']): a for r in spec['entries']
        if r['status'] != 'native_candidate' for a in r['archive_candidates']}
    sources = []
    for (archive, member), pin in sorted(selected.items()):
        target = WORK / 'archive-sources' / Path(archive).stem / member
        target.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(SOURCE / archive) as z:
            info = z.getinfo(member)
            assert info.file_size == pin['bytes'] and f'{info.CRC:08x}' == pin['crc32']
            if not target.exists():
                with z.open(info) as src, target.open('xb') as dst: shutil.copyfileobj(src, dst)
        assert target.stat().st_size == pin['bytes']
        sources.append({**pin, 'path': str(target), 'sha256': sha(target),
            'output': str(WORK / 'archive-probes' / Path(archive).stem / (Path(member).stem + '.json'))})
    write(WORK / 'archive-probe-job.json', {'sources': sources, 'intake_sha256': sha(INTAKE)})
    run_flatpak(HERE / 'alternate_forms_archive_probe_worker.py', WORK / 'archive-probe-job.json',
        [(WORK, ''), (HERE, ':ro')], WORK / 'archive-probe.log')
    print('ARCHIVE_INVENTORY_COMPLETE', len(sources))


if __name__ == '__main__': main()
