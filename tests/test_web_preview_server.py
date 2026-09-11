import importlib.util
import json
from functools import partial
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer
from pathlib import Path
import tempfile
import threading
import unittest

SPEC = importlib.util.spec_from_file_location('web_preview', Path(__file__).resolve().parents[1] / 'tools/serve_web_preview.py')
preview = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preview)


class PreviewServerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        (root / 'index.html').write_text('preview')
        (root / 'index.wasm').write_bytes(b'wasm-fixture')
        (root / '.private').write_text('not served')
        (root / 'directory').mkdir()
        (root / 'escape').symlink_to(root.parent)
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), partial(preview.PreviewHandler, directory=str(root)))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.thread.join()
        self.server.server_close()
        self.temp.cleanup()

    def request(self, path, method='GET', headers=None):
        connection = HTTPConnection('127.0.0.1', self.server.server_port)
        connection.request(method, path, headers=headers or {})
        response = connection.getresponse()
        result = response.status, {key.lower(): value for key, value in response.getheaders()}, response.read()
        connection.close()
        return result

    def test_static_and_wasm(self):
        self.assertEqual(self.request('/')[2], b'preview')
        status, headers, _ = self.request('/index.wasm')
        self.assertEqual(status, 200)
        self.assertEqual(headers['content-type'], 'application/wasm')
        self.assertIn("connect-src 'self'", headers['content-security-policy'])

    def test_pokemon_assets_are_separate_and_long_lived(self):
        status, headers, body = self.request('/pokemon-assets/gen5/front/pikachu/animation.json')
        self.assertEqual(status, 200)
        self.assertTrue(json.loads(body)['frames'])
        self.assertEqual(headers['cache-control'], 'public, max-age=31536000, immutable')
        self.assertEqual(self.request('/pokemon-assets/gen5/front/pikachu/other.txt')[0], 404)
        self.assertEqual(self.request('/pokemon-assets/gen5/front/%2e%2e/animation.json')[0], 404)

    def test_online_status_is_explicitly_closed(self):
        status, _, body = self.request('/api/auth/status')
        self.assertEqual(status, 200)
        self.assertFalse(json.loads(body)['available'])
        self.assertEqual(json.loads(body)['mode'], 'closed')
        self.assertEqual(self.request('/api/auth/login', 'POST')[0], 503)
        self.assertEqual(self.request('/api/ws/chat')[0], 503)

    def test_no_private_files_or_directory_listing(self):
        for path in ['/.private', '/%2eprivate', '/directory/', '/escape/']:
            self.assertEqual(self.request(path)[0], 404, path)

    def test_nonlocal_host_is_rejected(self):
        self.assertEqual(self.request('/', headers={'Host': 'example.com'})[0], 403)


if __name__ == '__main__':
    unittest.main()
