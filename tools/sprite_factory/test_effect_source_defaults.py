import copy
import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from effect_source_defaults import complete


class EffectSourceDefaultsTest(unittest.TestCase):
    def test_native_default_requires_complete_provenance_and_no_animation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); source = root / 'effect.tracm'; source.write_bytes(b'bound-source')
            proof = {str(source): hashlib.sha256(source.read_bytes()).hexdigest()}
            job = {'identity_intake': {'identity_evidence': {'source_sha256': proof}}}
            track = {'material': 'effect', 'parameter': 'UVScaleOffset3', 'channels': [[0], [1], [2], [3]]}
            data = {'frames': 91, 'tracks': [track, copy.deepcopy(track), copy.deepcopy(track)]}
            material = {'name': 'effect', 'colors': {'UVScaleOffset': [1., 1., 0., 0.]}}
            with patch('effect_source_defaults.read_uv_tracks', return_value=data):
                result, audit = complete(data, material, job, root)
            self.assertEqual(audit['identical_tracks_collapsed'], 2)
            self.assertEqual(len(result['tracks']), 2)
            self.assertEqual(result['tracks'][1]['channels'][0][-1]['time'], 90)
            self.assertEqual(len(data['tracks']), 3)
            elsewhere = {'tracks': [{'material': 'effect', 'parameter': 'UVScaleOffset'}]}
            with patch('effect_source_defaults.read_uv_tracks', return_value=elsewhere):
                with self.assertRaisesRegex(ValueError, 'animated elsewhere'):
                    complete(data, material, job, root)
            changed = copy.deepcopy(data); changed['tracks'][1]['channels'][0] = [5]
            with self.assertRaisesRegex(ValueError, 'Conflicting'):
                complete(changed, material, job, root)
            source.write_bytes(b'changed-source')
            with self.assertRaisesRegex(ValueError, 'provenance'):
                complete(data, material, job, root)
