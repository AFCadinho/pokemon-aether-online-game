import hashlib
import io
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
import urllib.error
import zipfile

from native_qualification_fixture import safe_member, unpack, fetch, MAX_JSON, DOWNLOAD_USER_AGENT


class FixtureTransportChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def make_archive(self, extra=None, manifest_change=None, fixture_change=None):
        fixture = {'prototype_only': True, 'production_approved': False,
                   'routes': {'/test-index/original.json': 'indexes/original.json'},
                   'stages': [{'index_path': 'indexes/original.json'}]}
        if fixture_change:
            fixture_change(fixture)
        files = {'fixture.json': json.dumps(fixture).encode(), 'indexes/original.json': b'{}'}
        if extra:
            files.update(extra)
        manifest = {'schema': 1, 'kind': 'pokeaether-native-qualification-input', 'production_approved': False,
                    'decoded_model_sha256': {}, 'files': {n: {'bytes': len(v), 'sha256': hashlib.sha256(v).hexdigest()} for n, v in files.items()}}
        if manifest_change:
            manifest_change(manifest)
        path = self.root / 'input.zip'
        with zipfile.ZipFile(path, 'w') as archive:
            for name, payload in files.items():
                archive.writestr(name, payload)
            archive.writestr('manifest.json', json.dumps(manifest))
        return path, hashlib.sha256(path.read_bytes()).hexdigest()

    def test_relocates_only_declared_paths_and_keeps_receipt(self):
        path, digest = self.make_archive()
        output = unpack(path, digest, self.root / 'fresh')
        value = json.loads(output.read_text())
        self.assertEqual(value['stages'][0]['index_path'], str(output.parent / 'indexes/original.json'))
        self.assertEqual(value['routes']['/test-index/original.json'], value['stages'][0]['index_path'])
        self.assertEqual(json.loads((output.parent / 'input-receipt.json').read_text())['input_sha256'], digest)

    def test_wrong_outer_checksum_does_not_create_destination(self):
        path, _ = self.make_archive()
        with self.assertRaises(ValueError):
            unpack(path, '0' * 64, self.root / 'fresh')
        self.assertFalse((self.root / 'fresh').exists())

    def test_traversal_code_cache_and_machine_paths_rejected(self):
        for name in ['../outside', '/outside', 'C:/outside', 'archives\\outside.zip', 'scripts/a.gd', '.godot/cache', '.env', 'indexes/../fixture.json']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                safe_member(name)

    def test_extra_source_code_rejected(self):
        path, digest = self.make_archive(extra={'scripts/unsafe.gd': b'code'})
        with self.assertRaises(ValueError):
            unpack(path, digest, self.root / 'fresh')

    def test_inner_member_checksum_is_not_trusted(self):
        path, digest = self.make_archive(manifest_change=lambda m: m['files']['fixture.json'].update(sha256='0' * 64))
        with self.assertRaises(ValueError):
            unpack(path, digest, self.root / 'fresh')

    def test_duplicate_member_rejected(self):
        path, _ = self.make_archive()
        with zipfile.ZipFile(path, 'a') as archive:
            import warnings
            with warnings.catch_warnings():
                warnings.simplefilter('ignore', UserWarning)
                archive.writestr('fixture.json', '{}')
        with self.assertRaises(ValueError):
            unpack(path, hashlib.sha256(path.read_bytes()).hexdigest(), self.root / 'fresh')

    def test_symlink_rejected(self):
        path, _ = self.make_archive()
        with zipfile.ZipFile(path, 'a') as archive:
            info = zipfile.ZipInfo('archives/' + '1' * 64 + '.zip')
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(info, '../../outside')
        with self.assertRaises(ValueError):
            unpack(path, hashlib.sha256(path.read_bytes()).hexdigest(), self.root / 'fresh')

    def test_oversized_metadata_rejected(self):
        path, digest = self.make_archive(extra={'indexes/native-256k.json': b'x' * (MAX_JSON + 1)})
        with self.assertRaises(ValueError):
            unpack(path, digest, self.root / 'fresh')

    def test_route_cannot_escape(self):
        path, digest = self.make_archive(fixture_change=lambda f: f['routes'].update({'/bad': '../outside'}))
        with self.assertRaises(ValueError):
            unpack(path, digest, self.root / 'fresh')
        self.assertFalse((self.root / 'outside').exists())

    def test_declared_member_set_must_match(self):
        path, digest = self.make_archive(manifest_change=lambda m: m['files'].pop('indexes/original.json'))
        with self.assertRaises(ValueError):
            unpack(path, digest, self.root / 'fresh')

    def test_existing_destination_is_preserved(self):
        path, digest = self.make_archive()
        destination = self.root / 'existing'
        destination.mkdir()
        (destination / 'keep').write_text('unchanged')
        with self.assertRaises(ValueError):
            unpack(path, digest, destination)
        self.assertEqual((destination / 'keep').read_text(), 'unchanged')

    def test_download_identifies_client_and_preserves_payload(self):
        response = io.BytesIO(b'exact test bytes')
        response.url = 'https://assets.example.test/input.zip'
        destination = self.root / 'download.zip'
        with patch('native_qualification_fixture.urllib.request.urlopen', return_value=response) as opener:
            fetch(response.url, destination)
        request = opener.call_args.args[0]
        self.assertEqual(request.get_header('User-agent'), DOWNLOAD_USER_AGENT)
        self.assertEqual(destination.read_bytes(), b'exact test bytes')

    def test_download_http_failure_is_not_hidden(self):
        destination = self.root / 'download.zip'
        error = urllib.error.HTTPError('https://assets.example.test/input.zip', 403, 'Forbidden', {}, None)
        with patch('native_qualification_fixture.urllib.request.urlopen', side_effect=error), self.assertRaises(urllib.error.HTTPError):
            fetch(error.url, destination)
        self.assertFalse(destination.exists())


if __name__ == '__main__':
    unittest.main()
