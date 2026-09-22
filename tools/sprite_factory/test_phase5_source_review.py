import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from types import SimpleNamespace

from phase5_review_gallery import build
from phase5_source_review import run_entry
from phase5_review_actions import candidates


class SourceReviewTests(unittest.TestCase):
    def test_action_tokens_do_not_confuse_attack_jumpdown_or_loop_phases(self):
        names = ['pm0143_00_00_00400_attack01.gfbanm',
                 'pm0143_00_00_00450_rangeattack01.gfbanm',
                 'pm0143_00_00_00152_jumpdown01_start.gfbanm',
                 'pm0143_00_00_00520_down01_start.gfbanm',
                 'pm0143_00_00_00280_sleep01_start.gfbanm',
                 'pm0143_00_00_00281_sleep01_loop.gfbanm',
                 'pm0143_00_00_00282_sleep01_end.gfbanm']
        result = candidates(names)
        self.assertEqual(result['physical_attack'], [names[0]])
        self.assertEqual(result['special_attack'], [names[1]])
        self.assertEqual(result['faint_start'], [names[3]])
        self.assertEqual(result['sleep'], [names[5]])
        self.assertEqual(result['faint_loop'], [])

    def test_legacy_primary_actions_and_ambiguity_remain_explicit(self):
        names = ['pm0063_00_ba10_waitA01.gfbanm', 'pm0063_00_ba21_tokusyu01.gfbanm',
                 'pm0063_00_ba41_down01.gfbanm']
        result = candidates(names)
        self.assertEqual(result['idle'], [names[0]])
        self.assertEqual(result['special_attack'], [names[1]])
        self.assertEqual(result['faint_start'], [names[2]])
        self.assertEqual(result['sleep'], [])
        self.assertEqual(len(candidates(names + [names[0] + '.001'])['idle']), 2)

    def test_root_member_crc_change_is_rejected_before_extraction(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / 'Gen1.zip'
            with zipfile.ZipFile(archive, 'w') as zipped:
                zipped.writestr('pm0063_00.blend', b'fixture')
            entry = {'species': 'abra', 'pm': 63, 'review_route': 'legacy_blend_inspection_required',
                     'legacy_candidate': {'archive': str(archive), 'member': 'pm0063_00.blend',
                                          'bytes': 7, 'crc32': '00000000'}}
            result = run_entry(entry, SimpleNamespace(output=root))
            self.assertEqual(result['status'], 'blocked')
            self.assertIn('CRC changed', result['error'])
            self.assertFalse((root / 'review/abra/pm0063_00.blend').exists())

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
