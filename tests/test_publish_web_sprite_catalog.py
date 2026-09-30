"""Exercise the workflow helper against loopback HTTP and local files only."""
from collections import Counter
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import io
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import threading
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
RCLONE = os.environ.get('RCLONE_TEST_BINARY') or shutil.which('rclone')
VERSION = 'pokemon-front-test-012345abcdef'


class SpriteUploadTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.requests = Counter()
        self.status = 200
        self.reset_first = False
        self.missing_sheet = False
        self.archive_status = 200
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, 'w') as output:
            for name, body in [('animation.json', b'original'), ('sheet.png', b'pixels')]:
                output.writestr('assets/sprites/pokemon/front/pikachu/' + name, body)
        archive_bytes = archive.getvalue()
        test = self

        class Handler(BaseHTTPRequestHandler):
            def do_HEAD(self):
                test.requests[self.path] += 1
                if test.reset_first and test.requests[self.path] == 1:
                    self.connection.shutdown(socket.SHUT_RDWR)
                    self.connection.close()
                    return
                status = 404 if test.missing_sheet and self.path.endswith('sheet.png') else test.status
                self.send_response(status)
                self.send_header('Content-Length', '0')
                self.end_headers()

            def do_GET(self):
                test.requests[self.path] += 1
                self.send_response(test.archive_status)
                self.send_header('Content-Length', str(len(archive_bytes)))
                self.end_headers()
                self.wfile.write(archive_bytes)

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        self.bin = self.directory / 'bin'
        self.bin.mkdir()
        fake = self.bin / 'rclone'
        fake.write_text('''#!/usr/bin/env python3
import json, os, subprocess, sys
from pathlib import Path
Path(os.environ['UPLOAD_CALL']).write_text(json.dumps(sys.argv[1:]))
if os.environ.get('LOCAL_RCLONE'):
    args = sys.argv[1:]
    args[2] = os.environ['LOCAL_DESTINATION']
    sys.exit(subprocess.call([os.environ['LOCAL_RCLONE'], *args, '--config', '/dev/null']))
''')
        fake.chmod(0o755)
        origin = f'http://127.0.0.1:{self.server.server_port}'
        self.env = {**os.environ, 'PATH': str(self.bin) + os.pathsep + os.environ['PATH'],
                    'ASSET_BASE_URL': origin, 'SOURCE_ASSET_BASE_URL': origin,
                    'R2_BUCKET': 'fixture', 'UPLOAD_CALL': str(self.directory / 'upload.json'),
                    'TMPDIR': str(self.directory)}

    def run_helper(self):
        return subprocess.run(['bash', 'tools/publish_web_sprite_catalog.sh',
                               'animated', 'front', VERSION], cwd=ROOT, env=self.env,
                              text=True, capture_output=True, timeout=110)

    def test_present_catalog_skips_archive_and_upload(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum(self.requests.values()), 2)
        self.assertFalse(Path(self.env['UPLOAD_CALL']).exists())

    def test_connection_reset_retries_without_false_missing_upload(self):
        self.reset_first = True
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum(self.requests.values()), 4)
        self.assertFalse(Path(self.env['UPLOAD_CALL']).exists())

    def test_forbidden_response_stops_without_upload(self):
        self.status = 403
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('HTTP 403', result.stderr)
        self.assertFalse(Path(self.env['UPLOAD_CALL']).exists())

    def test_exhausted_transport_failure_stops_without_upload(self):
        fake = self.bin / 'curl'
        fake.write_text('#!/bin/sh\nprintf "000"\nexit 35\n')
        fake.chmod(0o755)
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('upload was not started', result.stderr)
        self.assertFalse(Path(self.env['UPLOAD_CALL']).exists())

    def test_server_failure_after_retries_stops_without_upload(self):
        fake = self.bin / 'curl'
        fake.write_text('#!/bin/sh\nprintf "503"\n')
        fake.chmod(0o755)
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('HTTP 503', result.stderr)
        self.assertFalse(Path(self.env['UPLOAD_CALL']).exists())

    def test_archive_download_failure_cleans_up_and_does_not_upload(self):
        fake = self.bin / 'curl'
        fake.write_text('#!/bin/sh\ncase " $* " in *" --head "*) printf "404";; *) exit 22;; esac\n')
        fake.chmod(0o755)
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(Path(self.env['UPLOAD_CALL']).exists())
        self.assertFalse(list(self.directory.glob('pokeaether-web-sprites.*')))

    def test_missing_sheet_repairs_catalog_using_immutable_content_comparison(self):
        self.missing_sheet = True
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(Path(self.env['UPLOAD_CALL']).read_text())
        self.assertIn('--immutable', args)
        self.assertIn('--checksum', args)
        self.assertNotIn('--ignore-existing', args)
        self.assertFalse(list(self.directory.glob('pokeaether-web-sprites.*')))

    @unittest.skipUnless(RCLONE, 'Set RCLONE_TEST_BINARY or install rclone for local content checks')
    def test_identical_contents_with_different_timestamps_are_retained(self):
        self.missing_sheet = True
        self.configure_local_rclone()
        destination = Path(self.env['LOCAL_DESTINATION']) / 'pikachu/animation.json'
        destination.parent.mkdir(parents=True)
        destination.write_bytes(b'original')
        os.utime(destination, (1000000000, 1000000000))
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(destination.read_bytes(), b'original')
        self.assertEqual(destination.stat().st_mtime, 1000000000)
        self.assertEqual(destination.with_name('sheet.png').read_bytes(), b'pixels')

    @unittest.skipUnless(RCLONE, 'Set RCLONE_TEST_BINARY or install rclone for local content checks')
    def test_changed_contents_of_same_size_are_rejected_without_overwrite(self):
        self.missing_sheet = True
        self.configure_local_rclone()
        destination = Path(self.env['LOCAL_DESTINATION']) / 'pikachu/animation.json'
        destination.parent.mkdir(parents=True)
        destination.write_bytes(b'corrupt!')
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(destination.read_bytes(), b'corrupt!')

    def configure_local_rclone(self):
        self.env['LOCAL_RCLONE'] = str(Path(RCLONE).resolve())
        self.env['LOCAL_DESTINATION'] = str(self.directory / 'destination')


if __name__ == '__main__':
    unittest.main()
