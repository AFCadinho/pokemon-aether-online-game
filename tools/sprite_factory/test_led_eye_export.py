import copy
import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from led_eye_export import prepare

class LedEyeExportTests(unittest.TestCase):
    def test_source_bound_scalar_atlas_clock_and_conflicting_track_rejection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ['material.trmtr', 'idle.tracm', 'eye.png', 'iris.png']:
                (root/name).write_bytes(name.encode())
            digest = lambda name: hashlib.sha256((root/name).read_bytes()).hexdigest()
            job = {'material_source': str(root/'material.trmtr'), 'material_source_sha256': digest('material.trmtr'),
                   'identity_intake': {'motion_channels': {'idle': str(root/'idle.tracm')},
                                      'identity_evidence': {'source_sha256': {str(root/'idle.tracm'): digest('idle.tracm')}}}}
            material = {'name': 'l_eye', 'alpha_type': 'Blend',
                        'shaders': [{'name': 'Unlit', 'values': {'EnableOpacityMap': 'True', 'EnableOpacityMap1': 'True',
                                   'EnableBaseColorMap': 'False', 'LayerMaskSource': 'Const'}}],
                        'colors': {'BaseColor': [1,.1,0,1], 'UVScaleOffset': [1,1,0,0], 'UVScaleOffset1': [2,4,0,0]},
                        'floats': {'FlipBookWidth': 2, 'FlipBookHeight': 4, 'FlipBookFrame': 0,
                                   'EmissionIntensity': 1, 'LayerMaskScale1': 1},
                        'textures': {'OpacityMap': 'eye.bntx', 'OpacityMap1': 'iris.bntx'}}
            track = {'material': 'l_eye', 'parameter': 'FlipBookFrame',
                     'keys': [{'time':t, 'value':v, 'config':[0,0,0]} for t,v in [(0,0),(2,4)]]}
            data = {'fps':2, 'frames':3, 'config_flag':1, 'nested_timing':[[1,3,2]], 'tracks':[], 'scalar_tracks':[track]}
            timing = {'idle': {'duration':1, 'loop':True}}
            with patch('led_eye_export.inspect_materials', return_value=[material]), patch('led_eye_export.read_uv_tracks', return_value=data):
                result = prepare(job, timing, 'bound-glb')
                self.assertEqual(result['glb_sha256'], 'bound-glb')
                self.assertEqual(result['materials'][0]['clips']['idle']['parameters']['FlipBookFrame'], [[0,0],[.5,2],[1,4]])
                data['scalar_tracks'].append(copy.deepcopy(track))
                self.assertEqual(prepare(job,timing,'bound-glb'),result)
                data['scalar_tracks'][1]['keys'][-1]['value'] = 3
                with self.assertRaisesRegex(ValueError,'Conflicting'):prepare(job,timing,'bound-glb')
                data['scalar_tracks'] = [track]
                data['nested_timing'] = [[1,4,2]]
                with self.assertRaisesRegex(ValueError,'clock'):prepare(job,timing,'bound-glb')
                data['nested_timing'] = [[1,3,2]]
                track['keys'][-1]['value'] = 8
                with self.assertRaisesRegex(ValueError,'Invalid LED parameter'):prepare(job,timing,'bound-glb')
                (root/'material.trmtr').write_bytes(b'changed')
                with self.assertRaisesRegex(ValueError,'source changed'):prepare(job,timing,'bound-glb')

if __name__ == '__main__': unittest.main()
