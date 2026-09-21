import hashlib
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import model_pack as pack


class ModelPackTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.scene = self.root / 'source.scn'
        self.scene.write_bytes(b'reviewed scene fixture')
        self.digest = hashlib.sha256(self.scene.read_bytes()).hexdigest()
        self.registry = self.root / 'registry.json'
        self.registry.write_bytes(pack.encode(dict(qualification_sha256='a' * 64,
            models={'pikachu': {'sha256': self.digest}})))
        self.catalog = self.root / 'source.json'
        self.catalog.write_bytes(pack.encode([dict(species='pikachu', variant='normal',
            runtime_path=str(self.scene), runtime_sha256=self.digest)]))
        self.archive = self.root / 'pack.zip'
        self.destination = self.root / 'installed'
        pack.build(self.catalog, self.archive, self.registry)

    def rewrite(self, change_manifest=None, extra=None, change_scene=None):
        with zipfile.ZipFile(self.archive) as archive:
            entries = {info.filename: archive.read(info) for info in archive.infolist()}
        if change_manifest:
            manifest = json.loads(entries['catalog.json'])
            change_manifest(manifest)
            entries['catalog.json'] = pack.encode(manifest)
        with zipfile.ZipFile(self.archive, 'w') as archive:
            for name, data in entries.items():
                info = pack.zip_info(name)
                if name.endswith('.scn') and change_scene:
                    info, data = change_scene(info, data)
                archive.writestr(info, data)
            if extra:
                archive.writestr(*extra)

    def rejected(self):
        with self.assertRaises((ValueError, zipfile.BadZipFile)):
            pack.install(self.archive, self.destination, self.registry)
        self.assertFalse(self.destination.exists())
        self.assertFalse(list(self.root.glob('.model-install-*')))

    def test_deterministic_build_relocation_and_verify(self):
        second = self.root / 'second.zip'
        pack.build(self.catalog, second, self.registry)
        self.assertEqual(self.archive.read_bytes(), second.read_bytes())
        path = pack.install(self.archive, self.destination, self.registry)
        manifest = json.loads(path.read_text())
        self.assertNotIn(str(self.root), path.read_text())
        self.assertEqual(manifest['entries'][0]['runtime_path'], 'models/' + self.digest + '.scn')
        self.scene.unlink() # The installed artifact cannot depend on its original source.
        relocated = self.root / 'moved to another folder'
        self.destination.rename(relocated)
        self.assertEqual(pack.verify(relocated, self.registry), relocated / 'catalog.json')

    def test_no_overwrite(self):
        with self.assertRaises(ValueError):
            pack.build(self.catalog, self.archive, self.registry)
        self.destination.mkdir()
        marker = self.destination / 'keep.txt'
        marker.write_text('keep')
        with self.assertRaises(ValueError):
            pack.install(self.archive, self.destination, self.registry)
        self.assertEqual(marker.read_text(), 'keep')

    def test_explicit_previous_revision_remains_installable(self):
        registry = pack.read_json(self.registry)
        registry['models']['pikachu'] = dict(sha256='b' * 64, previous_sha256=[self.digest])
        self.registry.write_bytes(pack.encode(registry))
        pack.install(self.archive, self.destination, self.registry)
        pack.verify(self.destination, self.registry)
        pack.build(self.catalog, self.root / 'old-revision.zip', self.registry)
        self.assertFalse(pack.approved_digest(registry['models']['pikachu'], 'c' * 64))

    def test_changed_source(self):
        self.scene.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            pack.build(self.catalog, self.root / 'new.zip', self.registry)
        self.assertFalse((self.root / 'new.zip').exists())

    def test_traversal_absolute_and_drive_paths(self):
        original = self.archive.read_bytes()
        for bad in ('../outside.scn', '/outside.scn', 'C:/outside.scn', 'models\\outside.scn'):
            self.archive.write_bytes(original)
            self.rewrite(lambda m: m['entries'][0].update(runtime_path=bad))
            self.rejected()

    def test_unknown_species_hash_engine_and_qualification(self):
        original = self.archive.read_bytes()
        for change in (lambda m: m['entries'][0].update(species='gastly'),
                       lambda m: m['entries'][0].update(runtime_sha256='b' * 64),
                       lambda m: m.update(godot='5.0'),
                       lambda m: m.update(qualification_sha256='b' * 64)):
            self.archive.write_bytes(original)
            self.rewrite(change)
            self.rejected()

    def test_undeclared_script(self):
        self.rewrite(extra=('extra.gd', 'extends Node'))
        self.rejected()

    def test_duplicate_member(self):
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            self.rewrite(extra=('catalog.json', '{}'))
        self.rejected()

    def test_duplicate_identity(self):
        self.rewrite(lambda m: m['entries'].append(m['entries'][0].copy()))
        self.rejected()

    def test_linked_archive_member(self):
        def link(info, data):
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            return info, data
        self.rewrite(change_scene=link)
        self.rejected()

    def test_corrupt_payload_cleans_staging(self):
        self.rewrite(change_scene=lambda info, data: (info, b'x' * len(data)))
        self.rejected()

    def test_failed_final_verification_leaves_no_partial_install(self):
        with patch.object(pack, 'verify', side_effect=ValueError('interrupted verification')):
            self.rejected()

    def test_deflated_scene(self):
        def deflate(info, data):
            info.compress_type = zipfile.ZIP_DEFLATED
            return info, data
        self.rewrite(change_scene=deflate)
        self.assertEqual(pack.install(self.archive, self.destination, self.registry),
                         self.destination / 'catalog.json')

    def test_existing_destination_link_not_followed(self):
        untouched = self.root / 'untouched'
        untouched.mkdir()
        self.destination.symlink_to(untouched, target_is_directory=True)
        with self.assertRaises(ValueError):
            pack.install(self.archive, self.destination, self.registry)
        self.assertEqual(list(untouched.iterdir()), [])

    def test_invalid_size(self):
        original = self.archive.read_bytes()
        for size in (0, -1, 1.5, True, pack.MAX_FILE + 1, 1):
            self.archive.write_bytes(original)
            self.rewrite(lambda m: m['entries'][0].update(bytes=size))
            self.rejected()

    def test_verify_detects_installed_changes_and_links(self):
        pack.install(self.archive, self.destination, self.registry)
        model = self.destination / 'models' / (self.digest + '.scn')
        model.write_bytes(b'changed')
        with self.assertRaises(ValueError):
            pack.verify(self.destination, self.registry)
        model.unlink()
        model.symlink_to(self.scene)
        with self.assertRaises(ValueError):
            pack.verify(self.destination, self.registry)
