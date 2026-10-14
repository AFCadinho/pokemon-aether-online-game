#!/usr/bin/env python3
"""Exercise the full compiled v16 index through loopback downloads and presenters."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading
import subprocess

from probe_v13_compression import read, write, require
from run_shared_texture_runtime_checks import project, run
from study_lossless_texture_storage import ROOT, sha


def check(output, configuration):
    require(output.is_relative_to(ROOT / '.tmp') and not output.exists(), 'Fresh slot-local checks required')
    output.mkdir(parents=True)
    scripts = ['tests/model_release_v16_runtime_check.gd', 'tests/approved_3d_release_v16_check.gd']
    folder = project(output, scripts)
    inputs = {str(p.relative_to(folder)): sha(p) for p in folder.rglob('*') if p.is_symlink()}
    with (output / 'import.log').open('w') as log:
        result = subprocess.run(['godot', '--headless', '--editor', '--path', str(folder),
            '--log-file', str(output / 'import-engine.log'), '--import'], stdout=log, stderr=subprocess.STDOUT, timeout=180)
    require(result.returncode == 0 and 'ERROR:' not in (output / 'import.log').read_text(), 'Runtime project import failed')
    text = run(folder, scripts[1], output / 'bindings')
    require('APPROVED_3D_V16_OK' in text, 'Compiled v16 bindings failed')
    config = read(configuration)
    pool = next(j for j in config['jobs'] if j['asset'].get('format') == 'model-texture-pck-v1')
    # The pool's exact inline binding identifies its eight consumers.
    jobs = [j for j in config['jobs'] if pool['asset'] in j['asset'].get('pair_manifest', {}).get('texture_pools', [])]
    require(len(jobs) == 8, 'Incomplete pooled consumer cohort')
    jobs.sort(key=lambda j: j['asset']['asset_id'])
    parent = read(ROOT / 'release/shared_form_texture_study_v15.json')
    source_path = Path(parent['report_path']).parent / 'source/report.json'
    require(sha(source_path) == parent['source_report_sha256'], 'Changed native source proof')
    source = read(source_path)
    pin = read(ROOT / 'data/approved_3d_release_v16.json')['index']
    index = ROOT / 'release/approved_3d_bundles_v16_index.json'
    require(sha(index) == pin['sha256'], 'Wrong compiled index')
    paths = {j['asset']['object_key']: Path(j['path']) for j in [pool, *jobs]}
    paths[pin['object_key']] = index
    requests = []

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            key = self.path.removeprefix('/')
            requests.append(key)
            if key == pool['asset']['object_key'] and requests.count(key) == 1:
                self.send_error(503, 'Injected pool failure')
                return
            path = paths.get(key)
            if path is None:
                self.send_error(404)
                return
            data = path.read_bytes()
            self.send_response(200)
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *_args):
            pass

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    fixture = output / 'runtime-input.json'
    write(fixture, {'origin': f'http://127.0.0.1:{server.server_port}/', 'pool': pool,
          'jobs': jobs, 'source_models': source['models']})
    try:
        for phase in ['cold', 'restart']:
            text = run(folder, scripts[0], output / phase, [fixture, output / phase, phase])
            require('V16_SHARED_TEXTURE_RUNTIME_OK' in text, 'Runtime checks incomplete')
            print(f'V16_RUNTIME_OK {phase}', flush=True)
    finally:
        server.shutdown()
        server.server_close()
        thread.join()
        write(output / 'http-requests.json', requests)
    require(inputs == {str(p.relative_to(folder)): sha(p) for p in folder.rglob('*') if p.is_symlink()}, 'Runtime sources changed during checks')
    cold, restart = read(output / 'cold/report.json'), read(output / 'restart/report.json')
    require(cold['models'] == restart['models'] == source['models'], 'Native state mismatch')
    require(cold['pool_http_requests'] == 3 and restart['pool_http_requests'] == 0, 'Pool reuse failed')
    write(output / 'qualification.json', {'schema': 1, 'complete': True, 'revision': 'approved-pokemon-3d-v16',
          'configuration_sha256': sha(configuration), 'inputs': inputs, 'driver_sha256': sha(Path(__file__)),
          'native_source_sha256': sha(source_path), 'fixture_sha256': sha(fixture),
          'reports': {phase: sha(output / phase / 'report.json') for phase in ['cold', 'restart']},
          'cold_pool_requests': 3, 'restart_http_requests': 0, 'battles': 16, 'previews': 32,
          'launcher_handoff': True, 'corruption_repaired': True, 'partial_failure_rejected': True})
    print('V16_RUNTIME_QUALIFICATION_COMPLETE', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--configuration', type=Path, required=True)
    args = parser.parse_args()
    check(args.output.resolve(), args.configuration.resolve())
