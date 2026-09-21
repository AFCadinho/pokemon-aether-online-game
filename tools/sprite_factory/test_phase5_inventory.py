import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from phase5_inventory import inventory
from scvi_batch import load_batch


class InventoryTests(unittest.TestCase):
    def test_root_layout_and_ambiguous_layout(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            batch = root / 'batch.json'
            batch.write_text(json.dumps({'entries': [{'species': 'abra', 'pm': 63}]}))
            archive = root / 'Gen1.zip'
            with zipfile.ZipFile(archive, 'w') as zipped:
                zipped.writestr('pm0063_00.blend', b'fixture')
            report = inventory(batch, root / 'models', root / 'motions', archive)
            entry = report['entries'][0]
            self.assertEqual(entry['legacy_candidate']['member'], 'pm0063_00.blend')
            self.assertFalse(entry['review_approved'])
            with zipfile.ZipFile(archive, 'a') as zipped:
                zipped.writestr('Gen1/pm0063_00.blend', b'another-fixture')
            with self.assertRaisesRegex(ValueError, 'Ambiguous'):
                inventory(batch, root / 'models', root / 'motions', archive)

    def test_cohort_is_explicit_and_model_ids_are_not_dex_numbers(self):
        entries = load_batch(Path(__file__).with_name('phase5_review_batch.json'))
        self.assertEqual(len(entries), 10)
        self.assertEqual(sum(bool(entry.get('control')) for entry in entries), 2)
        self.assertEqual(next(e['pm'] for e in entries if e['species'] == 'roaring-moon'), 1089)
        self.assertTrue(all('presentation_override' not in entry for entry in entries))

    def test_archive_presence_does_not_approve_animation_or_shiny(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            batch = root / 'batch.json'
            batch.write_text(json.dumps({'entries': [{'species': 'abra', 'pm': 63},
                                                     {'species': 'onix', 'pm': 95}]}))
            archive = root / 'Gen1.zip'
            with zipfile.ZipFile(archive, 'w') as zipped:
                zipped.writestr('Gen1/pm0063_00.blend', b'fixture-not-a-valid-blend')
            report = inventory(batch, root / 'models', root / 'motions', archive)
            abra, onix = report['entries']
            self.assertEqual(abra['review_route'], 'legacy_blend_inspection_required')
            self.assertFalse(abra['review_approved'])
            self.assertEqual(abra['variant_status']['shiny'], 'unverified')
            self.assertTrue(all(value is None for value in abra['motions'].values()))
            self.assertEqual(onix['review_route'], 'source_missing')


if __name__ == '__main__':
    unittest.main()
