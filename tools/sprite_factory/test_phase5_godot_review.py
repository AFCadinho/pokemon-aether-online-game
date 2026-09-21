import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from phase5_godot_review import prepare_entries, build_gallery


class GodotReviewTests(unittest.TestCase):
    def fixture(self, root):
        cohort = json.loads(Path(__file__).with_name('phase5_review_batch.json').read_text())
        entries = []
        for model in cohort['entries']:
            species = model['species']
            directory = root / species
            directory.mkdir()
            source = directory / 'source.blend'
            source.write_bytes(b'test-source')
            metadata = {'species': species, 'source': str(source),
                        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest()}
            (directory / 'job.json').write_text(json.dumps(metadata))
            report = directory / 'review.json'
            report.write_text(json.dumps({**metadata, 'review_mapping': {'idle': 'source-idle'}}))
            entries.append({'species': species, 'status': 'source_review_only', 'report': str(report)})
        return {'entries': entries}

    def test_names_do_not_decide_material_support_and_clips_not_invented(self):
        with TemporaryDirectory() as tmp:
            entries = prepare_entries(self.fixture(Path(tmp)))
            self.assertEqual(sum(e['status'] == 'pending' for e in entries), 10)
            self.assertEqual(next(e for e in entries if e['species'] == 'gastly')['status'], 'pending')
            self.assertIn('faint_loop', entries[0]['missing_actions'])

    def test_unsupported_profile_holds_any_species(self):
        with TemporaryDirectory() as tmp:
            catalog = self.fixture(Path(tmp))
            path = Path(tmp) / 'pikachu/job.json'
            job = json.loads(path.read_text())
            job.update(material_source='fixture.trmtr', material_source_sha256='fixture')
            path.write_text(json.dumps(job))
            with patch('material_profiles.read_profiles', return_value=[{'export_supported':False}]) as reader:
                entries = prepare_entries(catalog)
            reader.assert_called_once_with('fixture.trmtr','fixture')
            self.assertEqual(next(e for e in entries if e['species']=='pikachu')['status'],'held')

    def test_import_without_material_provenance_rejected(self):
        with TemporaryDirectory() as tmp:
            catalog = self.fixture(Path(tmp))
            (Path(tmp)/'pikachu/import.json').write_text('{}')
            with self.assertRaisesRegex(ValueError, 'material provenance'):
                prepare_entries(catalog)

    def test_duplicate_cohort_and_stale_source_rejected(self):
        with TemporaryDirectory() as tmp:
            catalog = self.fixture(Path(tmp))
            with self.assertRaises(ValueError):
                prepare_entries({'entries': catalog['entries'] + [catalog['entries'][0]]})
            (Path(tmp) / 'pikachu/source.blend').write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError, 'Stale'):
                prepare_entries(catalog)

    def test_experimental_material_source_rejected(self):
        with TemporaryDirectory() as tmp:
            catalog = self.fixture(Path(tmp))
            path = Path(tmp) / 'pikachu/job.json'
            data = json.loads(path.read_text())
            data['material_probe_policy'] = 'experimental'
            path.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, 'Experimental'):
                prepare_entries(catalog)

    def test_gallery_keeps_held_rows_and_disclaims_approval(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'godot-review.json').write_text(json.dumps({'entries': [
                {'species': 'gastly', 'status': 'held'},
                {'species': 'abra', 'errors': ['<missing>'], 'poses': [{'action': 'sleep', 'view': 'front', 'status': 'missing'}]}]}))
            build_gallery(root)
            page = (root / 'index.html').read_text()
            for text in ['NOT battle approved', 'gastly', 'held', 'MISSING', '&lt;missing&gt;']:
                self.assertIn(text, page)


if __name__ == '__main__':
    unittest.main()
