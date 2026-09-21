import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from phase5_review_gallery import build
from phase5_source_review import run_entry


class SourceReviewTests(unittest.TestCase):
    def test_bad_archive_is_reported_without_creating_fake_blend(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / 'broken.zip'
            archive.write_bytes(b'broken')
            entry = {'species': 'abra', 'pm': 63, 'review_route': 'legacy_blend_inspection_required',
                     'legacy_candidate': {'archive': str(archive), 'member': 'Gen1/pm0063_00.blend', 'bytes': 12}}
            result = run_entry(entry, SimpleNamespace(output=root))
            self.assertEqual(result['status'], 'blocked')
            self.assertFalse((root / 'review/abra/pm0063_00.blend').exists())

    def test_wrong_archive_member_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            entry = {'species': 'abra', 'pm': 63, 'review_route': 'legacy_blend_inspection_required',
                     'legacy_candidate': {'member': '../unrelated.blend'}}
            result = run_entry(entry, SimpleNamespace(output=root))
            self.assertEqual(result['status'], 'blocked')
            self.assertIn('Unexpected legacy archive member', result['error'])

    def test_gallery_keeps_blocked_cases_and_no_approval(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'catalog.json').write_text(json.dumps({'approval': False, 'entries': [
                {'species': 'abra', 'status': 'blocked', 'error': '<unreadable archive>'}]}))
            build(root)
            page = (root / 'index.html').read_text()
            self.assertIn('abra', page)
            self.assertIn('&lt;unreadable archive&gt;', page)
            self.assertIn('No model is approved', page)
            self.assertTrue((root / 'contact-1.png').is_file())


if __name__ == '__main__':
    unittest.main()
