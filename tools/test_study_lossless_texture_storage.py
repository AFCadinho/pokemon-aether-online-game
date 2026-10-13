"""Guard the actual frozen sample and persisted complete-container accounting."""
import tempfile
import unittest
from pathlib import Path

from study_lossless_texture_storage import catalog, select
from probe_v13_compression import checked_bytes


class LosslessTextureStudyTests(unittest.TestCase):
    def test_sample_covers_both_pck_formats_and_fixed_controls(self):
        _, assets = catalog()
        sample = select(assets)
        self.assertEqual(sample, select(list(reversed(assets))))
        self.assertEqual(len(sample), 20)
        self.assertEqual(sum(a['pair_manifest']['schema'] == 2 for a in sample), 16)
        self.assertEqual(sum(a['pair_manifest']['schema'] == 1 for a in sample), 4)
        ids = {a['asset_id'] for a in sample}
        self.assertTrue({'pokemon_3d:hydreigon:base', 'pokemon_3d:tyranitar:base',
                         'pokemon_3d:urshifu-rapid-strike:base', 'pokemon_3d:landorus-therian:base'} <= ids)

    def test_missing_fixed_control_fails(self):
        _, assets = catalog()
        with self.assertRaisesRegex(ValueError, 'Missing fixed controls'):
            select([a for a in assets if a['asset_id'] != 'pokemon_3d:hydreigon:base'])

    def test_reject_corrupted_persisted_pack(self):
        # This known fixture is an actual complete model, never a toy container.
        root = Path(__file__).resolve().parents[1]
        checkpoint = root / '.tmp/lossless-texture-storage-pilot-v4/pair-0000/checkpoint.json'
        if not checkpoint.exists():
            self.skipTest('Retained local complete-pack fixture is unavailable in CI')
        import json
        record = json.loads(checkpoint.read_text())
        candidate = next(c for c in record['candidates'] if c['codec'] == 'best')
        asset = json.loads((Path(candidate['path']).parent / 'asset.json').read_text())
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'candidate.pck'
            data = bytearray(Path(candidate['path']).read_bytes())
            data[200] ^= 1
            path.write_bytes(data)
            with self.assertRaisesRegex(ValueError, 'Source pin mismatch'):
                checked_bytes(path, asset)


if __name__ == '__main__':
    unittest.main()
