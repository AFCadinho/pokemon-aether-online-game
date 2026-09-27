import copy
import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from scvi_eye_motion import prepare

class EyeMotionTests(unittest.TestCase):
    def test_defaults_fill_missing_tracks_and_clock_or_source_changes_are_rejected(self):
        import hashlib
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'idle.tracm'; path.write_bytes(b'fixture')
            job={'material_source':str(Path(temp)/'normal.trmtr'), 'identity_intake':{
                'source_eye_material_diagnostic':'unreferenced_white_highlight',
                'motion_channels':{'idle':str(path)},'identity_evidence':{'source_sha256':{str(path):hashlib.sha256(b'fixture').hexdigest()}}}}
            material={'name':'eye','shaders':[{'name':'Eye'}],'colors':{'UVScaleOffset':[1,1,0,0]}}
            data={'tracks':[],'frames':61,'fps':60,'config_flag':1,'nested_timing':[]}
            timing={'idle':{'duration':1.0,'loop':True}}
            with patch('scvi_eye_motion.inspect_materials',return_value=[material]), patch('scvi_eye_motion.read_uv_tracks',return_value=data):
                result=prepare(job,timing,'a'*64)
                self.assertEqual(result['materials'][0]['clips']['idle']['parameters']['UVScaleOffset'],[[0.0,[1,1,0,0]]])
                data['tracks']=[{'material':'eye','parameter':'UVScaleOffset','channels':[[{'time':0,'value':v,'config':[0,0,0]},{'time':60,'value':v,'config':[0,0,0]}] for v in (1,1,0,0)]}]
                self.assertEqual(len(prepare(job,timing,'a'*64)['materials'][0]['clips']['idle']['parameters']['UVScaleOffset']),2)
                with self.assertRaisesRegex(ValueError,'clock'):
                    prepare(job,{'idle':{'duration':2.0,'loop':True}},'a'*64)
                path.write_bytes(b'changed')
                with self.assertRaisesRegex(ValueError,'source changed'): prepare(job,timing,'a'*64)

class DuplicateEyeTracksTest(unittest.TestCase):
    def test_exact_duplicate_is_safe_but_conflicting_keys_remain_held(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'idle.tracm'; path.write_bytes(b'bound motion')
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            job = {'material_source': str(Path(tmp) / 'material.trmtr'),
                   'identity_intake': {'source_eye_material_diagnostic': 'eye_source_uv',
                    'motion_channels': {'idle': str(path)},
                    'identity_evidence': {'source_sha256': {str(path): digest}}}}
            material = {'name': 'l_eye', 'shaders': [{'name': 'Eye'}],
                        'colors': {'UVScaleOffset': [1, 1, 0, 0]}}
            track = {'material': 'l_eye', 'parameter': 'UVScaleOffset',
                     'channels': [[{'time': t, 'value': value, 'config': [0,0,0]}
                                   for t in [0, 2]] for value in [1,1,0,0]]}
            data = {'fps': 2, 'frames': 3, 'config_flag': 1, 'nested_timing': [],
                    'tracks': [track, copy.deepcopy(track)]}
            timing = {'idle': {'duration': 1.0, 'loop': True}}
            with patch('scvi_eye_motion.inspect_materials', return_value=[material]), patch('scvi_eye_motion.read_uv_tracks', return_value=data):
                result = prepare(job, timing, 'glb')
                keys = result['materials'][0]['clips']['idle']['parameters']['UVScaleOffset']
                self.assertEqual(keys, [[0.0,[1,1,0,0]], [1.0,[1,1,0,0]]])
                data['tracks'][1]['channels'][2][-1]['value'] = 0.5
                with self.assertRaisesRegex(ValueError, 'Conflicting duplicate'):
                    prepare(job, timing, 'glb')


if __name__=='__main__': unittest.main()
