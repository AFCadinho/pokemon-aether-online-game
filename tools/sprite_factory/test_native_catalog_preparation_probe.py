import copy
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from native_resource_compression_probe import Zstd, decode, encode, sha
from native_bundle_validation_fixture import write_zip
from prepare_native_compressed_catalog import prepare_asset, transform


class CatalogPreparationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.codec = Zstd()

    def fixture(self, root):
        raw = (bytes(range(251)) * 500) + b'RSRC'
        scene = encode(raw, 4096, 3, self.codec)
        plain = b'RSRC' + b'uncompressed-fixture' * 200 + b'RSRC'
        payloads = {'models/normal.scn': scene, 'models/shiny.scn': plain, 'author-note.txt': b'unchanged extra member'}
        appearances = [{'variant': v, 'runtime_identity': 'fixture' + ('@shiny' if v == 'shiny' else ''),
            'runtime_sha256': sha(payloads['models/' + v + '.scn']), 'bytes': len(payloads['models/' + v + '.scn'])} for v in ['normal', 'shiny']]
        manifest = {'species_id': 'fixture', 'form_id': 'base', 'version': 7, 'appearances': appearances}
        source = root / 'source.zip'
        write_zip(source, manifest, payloads)
        asset = {'asset_id': 'pokemon_3d:fixture:base', 'species_id': 'fixture', 'form_id': 'base', 'version': 7,
            'sha256': sha(source.read_bytes()), 'size_bytes': source.stat().st_size, 'object_key': 'source.zip',
            'appearances': copy.deepcopy(appearances)}
        registry = {'models': {a['runtime_identity']: {'sha256': a['runtime_sha256'], 'profile': 'original'} for a in appearances}}
        return source, asset, registry, raw, payloads

    def test_pair_preserves_raw_approval_metadata_and_auxiliary_members(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, asset, registry, raw, payloads = self.fixture(root)
            before = source.read_bytes()
            original_asset, original_registry = copy.deepcopy(asset), copy.deepcopy(registry)
            out = root / 'prepared'
            out.mkdir()
            new, models, receipt = prepare_asset(asset, source, out, registry, self.codec)
            self.assertTrue(receipt['changed'])
            self.assertEqual(new['version'], 8)
            self.assertLess(new['size_bytes'], asset['size_bytes'])
            with zipfile.ZipFile(receipt['candidate_archive']) as archive:
                self.assertEqual(decode(archive.read('models/normal.scn'), self.codec), raw)
                self.assertEqual(archive.read('models/shiny.scn'), payloads['models/shiny.scn'])
                self.assertEqual(archive.read('author-note.txt'), payloads['author-note.txt'])
                self.assertEqual(json.loads(archive.read('bundle.json'))['version'], 8)
            self.assertIn(registry['models']['fixture']['sha256'], models['fixture']['previous_sha256'])
            self.assertEqual(source.read_bytes(), before)
            self.assertEqual(asset, original_asset)
            self.assertEqual(registry, original_registry)

    def test_corrupted_source_and_unapproved_revision_rejected_without_outputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, asset, registry, _, _ = self.fixture(root)
            out = root / 'prepared'
            out.mkdir()
            invalid = copy.deepcopy(asset)
            invalid['sha256'] = 'f' * 64
            with self.assertRaisesRegex(ValueError, 'archive hash/size'):
                prepare_asset(invalid, source, out, registry, self.codec)
            registry['models']['fixture']['sha256'] = 'f' * 64
            with self.assertRaisesRegex(ValueError, 'not approved'):
                prepare_asset(asset, source, out, registry, self.codec)
            self.assertEqual(list(out.iterdir()), [])

    def test_larger_or_uncompressed_resource_is_retained(self):
        already = encode(bytes(range(251)) * 800, 262144, 9, self.codec)
        candidate, receipt = transform(already, self.codec)
        self.assertEqual(candidate, already)
        self.assertIn('would not save', receipt['reason'])
        plain = b'RSRCunchangedRSRC'
        candidate, receipt = transform(plain, self.codec)
        self.assertEqual(candidate, plain)
        self.assertIn('RSRC', receipt['reason'])


if __name__ == '__main__':
    unittest.main()
