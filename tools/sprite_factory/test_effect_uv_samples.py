import copy
import unittest
from effect_uv_samples import channel_samples, sample_tracks
from test_scvi_uv_probe import fixture
from material_profiles import classify, UNLIT_UV2


class EffectUVSamplesTests(unittest.TestCase):
    def test_nonaffine_preserves_all_keys_and_loop_endpoint(self):
        keys = [{'time':t, 'value':v, 'config':[0,0,1]} for t,v in [(0,0),(2,.8),(3,0),(4,1)]]
        self.assertEqual(channel_samples(keys,4), [0,.4,.8,0,1])

    def test_invalid_keys_fail(self):
        keys = [{'time':t, 'value':v, 'config':[0,0,1]} for t,v in [(0,0),(2,1)]]
        for changed in ['tangent','fraction','nonfinite','unordered']:
            data=copy.deepcopy(keys)
            if changed=='tangent':data[1]['config']=[1,0,1]
            if changed=='fraction':data[1]['time']=1.5
            if changed=='nonfinite':data[1]['value']=float('nan')
            if changed=='unordered':data[1]['time']=0
            with self.assertRaises(ValueError):channel_samples(data,2)

    def test_tracks_retain_source_rate_samples(self):
        data=fixture()
        second=copy.deepcopy(data['tracks'][0]);second['parameter']='UVScaleOffset3'
        data['tracks'].append(second)
        self.assertEqual(len(sample_tracks(data)['UVScaleOffset']),121)
        data['tracks'][1]['channels'][2][-1]['value']=.3
        with self.assertRaisesRegex(ValueError,'Nonperiodic'):sample_tracks(data)

    def test_unlit_uv2_is_distinct_from_standard_displacement(self):
        material={'name':'any','shaders':[{'name':'Unlit','values':{'EnableBaseColorMap':'True','EnableDisplacementMap':'True','NumMaterialLayer':'5','NumRequiredUV':'2'}}],
                  'textures':dict.fromkeys(['BaseColorMap','LayerMaskMap','DisplacementMap'])}
        self.assertEqual(classify(material)['profile'],UNLIT_UV2)
        material['shaders'][0]['name']='Standard'
        self.assertFalse(classify(material)['export_supported'])
