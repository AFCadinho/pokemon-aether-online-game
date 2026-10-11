#!/usr/bin/env python3
"""Build and check one private shared-geometry pair; never publishes or admits it."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/sprite_factory'))
from native_resource_compression_probe import Zstd, decode, encode


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def run(output, stage, arguments, render=False, script_name=None):
    script = script_name or ('model_texture_render_probe.gd' if render else 'shared_geometry_prototype.gd')
    command = ['godot', '--path', str(ROOT), '--log-file', str(output / (stage + '.engine.log'))]
    command += ['--rendering-method', 'mobile'] if render else ['--headless']
    command += ['--script', 'res://tools/sprite_factory/' + script, '--'] + arguments
    with (output / (stage + '.log')).open('w') as stream:
        child = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT)
        try:
            code = child.wait(timeout=300)
        except BaseException:
            child.terminate()
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
            raise
    log = (output / (stage + '.log')).read_text()
    if code or re.search(r'(?:SCRIPT ERROR|^ERROR:|GEOMETRY_PROTOTYPE_ERROR)', log, re.M):
        raise RuntimeError('Prototype failed: ' + stage + '\n' + log[-3000:])
    print(stage.upper() + '_OK', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True, help='One checked PCK job from the geometry audit')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--audit-report', type=Path, help='Optional full audit report for a secondary mesh-name comparison')
    parser.add_argument('--render', action='store_true', help='Compare 20 source/candidate frames with source repeats on Mobile Vulkan')
    args = parser.parse_args()
    if os.environ.get('POKEAETHER_SLOT') != ROOT.parent.name:
        parser.error('Use the assigned slot-env')
    output = args.output.resolve()
    output.relative_to(ROOT / '.tmp')
    output.mkdir(parents=True, exist_ok=False)
    jobs = json.loads(args.input.read_bytes())['jobs']
    assert len(jobs) == 1 and jobs[0]['asset']['format'] == 'model-pair-pck-v1'
    source = Path(jobs[0]['source'])
    assert sha(source) == jobs[0]['asset']['sha256']
    scripts = [Path(__file__), ROOT / 'tools/sprite_factory/shared_geometry_prototype.gd',
               ROOT / 'tools/sprite_factory/model_geometry_audit.gd', ROOT / 'tools/sprite_factory/model_texture_audit.gd',
               ROOT / 'tools/sprite_factory/native_resource_compression_probe.py',
               ROOT / 'tools/sprite_factory/model_texture_render_probe.gd',
               ROOT / 'tools/sprite_factory/shared_geometry_name_probe.gd']
    pins = {str(p.relative_to(ROOT)): sha(p) for p in scripts}
    write(output / 'input.json', {'jobs': jobs})
    lock = (ROOT / '.tmp/diagnostic-project.lock').open('a+')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    project = ROOT / 'project.godot'
    original = project.read_bytes()
    config = re.sub(r'\[autoload\].*?(?=\n\[)', '', original.decode(), flags=re.S)
    config = re.sub(r'\[editor_plugins\].*?(?=\n\[)', '', config, flags=re.S)
    def interrupt(_signal, _frame):
        raise KeyboardInterrupt('Prototype interrupted; restoring project')
    signal.signal(signal.SIGTERM, interrupt)
    try:
        project.write_text(config)
        if args.audit_report:
            run(output, 'mesh-name-check', [str(args.audit_report.resolve()), str(output / 'mesh-name-check.json')],
                script_name='shared_geometry_name_probe.gd')
        run(output, 'prepare', ['prepare', str(output / 'input.json'), str(output / 'payload')])
        prepared = json.loads((output / 'payload/prepared.json').read_bytes())
        codec = Zstd()
        for relative, path in prepared['files'].items():
            if relative.startswith('textures/'):
                continue # Retain exactly the source pack's compressed image payloads.
            resource = Path(path)
            raw = decode(resource.read_bytes(), codec)
            native = encode(raw, 262144, 9, codec)
            assert decode(native, codec) == raw
            resource.write_bytes(native)
        prepared['file_hashes'] = {name: sha(path) for name, path in prepared['files'].items()}
        for row in prepared['models']:
            relative = row['candidate_path'].removeprefix(prepared['resource_root'] + '/')
            row['candidate_sha256'] = prepared['file_hashes'][relative]
        manifest = output / 'payload/prototype.json'
        write(manifest, {'prototype_only': True, 'production_approved': False,
                        'source_sha256': prepared['source_sha256'], 'files': prepared['file_hashes']})
        prepared['files']['prototype.json'] = str(manifest)
        prepared['file_hashes']['prototype.json'] = sha(manifest)
        config_path = output / 'candidate.json'
        write(config_path, prepared)
        candidate = output / 'candidate.pck'
        run(output, 'pack', ['pack', str(config_path), str(candidate)])
        prepared.update(pack_path=str(candidate), pack_sha256=sha(candidate), pack_bytes=candidate.stat().st_size)
        prepared['packs'] = [{'path': str(source), 'sha256': prepared['source_sha256']},
                             {'path': str(candidate), 'sha256': prepared['pack_sha256']}]
        write(config_path, prepared)
        run(output, 'cold-check', ['check', str(config_path), str(output / 'cold-check.json')])
        if args.render:
            run(output, 'render', [str(config_path), str(output / 'render')], render=True)
            records = json.loads((output / 'render/report.json').read_bytes())['records']
            assert len(records) == 2 and all(r['all_pixels_exact'] and r['repeat_source_pixels_exact'] for r in records)
        assert sha(source) == prepared['source_sha256']
        assert {str(p.relative_to(ROOT)): sha(p) for p in scripts} == pins
        saved = int(prepared['source_bytes']) - prepared['pack_bytes']
        report = {'schema': 1, 'prototype_only': True, 'production_approved': False,
                  'asset_id': prepared['asset_id'], 'source_sha256': prepared['source_sha256'],
                  'candidate_sha256': prepared['pack_sha256'], 'source_bytes': int(prepared['source_bytes']),
                  'candidate_bytes': prepared['pack_bytes'], 'saved_bytes': saved,
                  'saved_percent': 100 * saved / prepared['source_bytes'], 'source_scripts': pins,
                  'cold_check': json.loads((output / 'cold-check.json').read_bytes()),
                  'rendered_appearances': 2 if args.render else 0, 'pixel_exact_frames': 20 if args.render else 0,
                  'note': 'Actual private pack sizes; future production manifest/loader overhead can differ.'}
        write(output / 'report.json', report)
        print('SHARED_GEOMETRY_PROTOTYPE_OK', json.dumps(report), flush=True)
    finally:
        project.write_bytes(original)
        lock.close()


if __name__ == '__main__':
    main()
