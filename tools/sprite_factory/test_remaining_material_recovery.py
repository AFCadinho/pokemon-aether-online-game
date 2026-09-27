import copy
import unittest
from material_profiles import classify, LIT, TRANSPARENT_PROBE

class RecoveryProfiles(unittest.TestCase):
    def test_lit_displacement_requires_review_and_known_surface(self):
        material = {'name': 'body', 'alpha_type': 'Opaque',
                    'shaders': [{'name':'Standard','values': {'EnableDisplacementMap':'True',
                        'EnableParallaxMap':'False','NumRequiredUV':'2','NumMaterialLayer':'5'}}],
                    'textures': dict.fromkeys(['BaseColorMap','LayerMaskMap','DisplacementMap'])}
        self.assertFalse(classify(material)['export_supported'])
        result = classify(material, displacement_review=True)
        self.assertEqual(result['profile'], LIT)
        self.assertTrue(result['use_uv2'])
        for key, value in [('EnableParallaxMap', 'True'), ('NumRequiredUV', '3')]:
            invalid = copy.deepcopy(material)
            invalid['shaders'][0]['values'][key] = value
            self.assertFalse(classify(invalid, displacement_review=True)['export_supported'])

    def test_reversed_fresnel_endpoints_remain_bounded_not_reordered(self):
        material = {'name':'shell','alpha_type':'BlendPreMultiAlpha',
                    'shaders':[{'name':'Transparent','values':{'RefractionMode':'Thin'}}],
                    'floats':{'FresnelAlphaMin':1.,'FresnelAlphaMax':.999877}}
        result = classify(material, transparent_review=True)
        self.assertEqual(result['profile'], TRANSPARENT_PROBE)
        self.assertEqual(result['source_fresnel_alpha_min'], 1.)
        self.assertEqual(result['source_fresnel_alpha_max'], .999877)
        for invalid in [-.01,1.01,float('nan')]:
            material['floats']['FresnelAlphaMax'] = invalid
            self.assertFalse(classify(material, transparent_review=True)['export_supported'])

if __name__ == '__main__': unittest.main()
