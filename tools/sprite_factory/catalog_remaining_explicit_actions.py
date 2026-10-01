"""Export source-pinned action mappings as review candidates, never admissions."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import re
import zipfile

HERE = Path(__file__).resolve().parent
REQUIRED = {'idle', 'physical_attack', 'special_attack', 'damage', 'sleep', 'faint_start'}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')


def export(row, output):
    directory = output / row['species']
    directory.mkdir()
    source_name = Path(row['source']['member']).name
    if re.fullmatch(r'pm\d{4}\.blend', source_name):
        source_name = source_name[:-6] + '_00.blend'
    source = directory / source_name
    try:
        probe = Path(row['probe'])
        if sha(probe) != row['probe_sha256']:
            raise ValueError('Pinned source probe changed')
        report = json.loads(probe.read_text())
        mapping = row['actions']
        if report['species'] != row['species'] or not REQUIRED <= mapping.keys():
            raise ValueError('Incomplete explicit action mapping')
        if not set(mapping.values()) <= set(report['action_names']):
            raise ValueError('Mapped action does not exist in source')
        if report['source_member'] != row['source']['member']:
            raise ValueError('Source identity differs from probe')
        with zipfile.ZipFile(row['source']['archive']) as archive:
            info = archive.getinfo(row['source']['member'])
            if info.file_size != row['source']['bytes'] or f'{info.CRC:08x}' != row['source']['crc32']:
                raise ValueError('Pinned archive member changed')
            source.write_bytes(archive.read(info))
        if sha(source) != report['source_sha256']:
            raise ValueError('Archived source differs from probe')
        job = {'species': row['species'], 'source': str(source),
               'source_sha256': report['source_sha256'], 'actions': mapping,
               'output': str(directory), 'scvi_pbr_probe': False}
        if row.get('diagnostic_rig_selection'):
            job['diagnostic_rig_selection'] = row['diagnostic_rig_selection']
        job['review_action_aliases'] = row.get('review_action_aliases', {})
        job['authored_motion_review'] = row.get('authored_motion_review', [])
        write(directory / 'job.json', job)
        command = ['flatpak', 'run', '--unshare=network', '--nofilesystem=host',
                   '--filesystem=' + str(directory), '--filesystem=' + str(HERE) + ':ro',
                   'org.blender.Blender', '--background', '--factory-startup',
                   '--disable-autoexec', '--python-exit-code', '1', '--python',
                   str(HERE / 'phase5_godot_export_worker.py'), '--', str(directory / 'job.json')]
        with (directory / 'export.log').open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
        exported = json.loads((directory / 'export.json').read_text())
        if exported['status'] != 'exported_for_review' or set(exported['animations']) != set(mapping):
            raise ValueError('Export does not preserve requested action set')
        if sha(exported['path']) != exported['glb_sha256']:
            raise ValueError('Exported scene hash differs')
        return {'species': row['species'], 'status': 'normal_review_candidate',
                'report': str(directory / 'export.json'), 'runtime_approved': False}
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        return {'species': row['species'], 'status': 'held', 'reason': str(error),
                'runtime_approved': False}
    finally:
        source.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mapping', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    rows = json.loads(args.mapping.read_text())['entries']
    results = []
    for row in rows:
        result = export(row, output)
        results.append(result)
        write(output / 'status.json', {'total': len(rows), 'processed': len(results),
                                      'runtime_approved': False, 'entries': results})
        print(result['species'], result['status'], flush=True)


if __name__ == '__main__':
    main()
