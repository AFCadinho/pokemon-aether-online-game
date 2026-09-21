import unittest
from phase5_review_actions import candidates
from source_review_rigs import choose_variant, image_identity
from material_profiles import classify, LAYERED


class BatchHardeningTests(unittest.TestCase):
    def test_bank_is_coherent_and_opt_in(self):
        names = ['pm0999_00_00_00001_battlewait01_loop.gfbanm',
                 'pm0999_00_00_10001_battlewait01_loop.gfbanm',
                 'pm0999_00_00_10400_attack01.gfbanm']
        self.assertEqual(len(candidates(names)['idle']), 2)
        self.assertEqual(candidates(names, 0)['idle'], names[:1])
        self.assertEqual(candidates(names, 0)['physical_attack'], [])
        self.assertEqual(candidates(names, 1)['physical_attack'], names[2:])
        self.assertEqual(len(candidates(names + [names[0] + '.001'], 0)['idle']), 2)
        for invalid in [-1, 10, True, '0']:
            with self.assertRaises(ValueError): candidates(names, invalid)

    def test_unknown_legacy_clips_do_not_become_sleep_or_faint(self):
        names = ['pm0999_00_ba41_down01.gfbanm', 'pm0999_00_loop01.gfbanm',
                 'HASH[FullHash=1234].gfbanm', 'pm0999_00_kw20_drowseA01.gfbanm']
        self.assertEqual(candidates(names, 0)['sleep'], [])
        self.assertEqual(candidates(names, 0)['faint_loop'], [])

    def test_variant_requires_exclusive_positive_evidence(self):
        self.assertEqual(choose_variant({'a': ['pm0999_00'], 'b': ['pm0999_00','pm0999_01']}, 'pm0999_00'), 'a')
        for evidence in [{'a': [], 'b': []}, {'a': ['pm0999_00'], 'b': ['pm0999_00']},
                         {'a': ['pm0999_01']}]:
            with self.assertRaises(ValueError): choose_variant(evidence, 'pm0999_00')
        self.assertEqual(image_identity('pm0999_00_BodyC.png.001'), 'pm0999_00')
        self.assertIsNone(image_identity('unrelated.png'))

    def test_material_profile_uses_signature_not_species_or_name(self):
        m = {'name': 'anything', 'shaders': [{'name': 'NonDirectional', 'values': {
             'EnableBaseColorMap':'True','EnableDisplacementMap':'True',
             'NumMaterialLayer':'5','NumRequiredUV':'2','EnableAlphaTest':'False'}}],
             'textures':dict.fromkeys(['BaseColorMap','LayerMaskMap','DisplacementMap'],'any.bntx')}
        p=classify(m)
        self.assertEqual(p['profile'],LAYERED)
        self.assertTrue(p['export_supported'])
        self.assertTrue(p['requires_effect_payload'])
        m['name']='other';m['shaders'][0]['values']['EnableAlphaTest']='True'
        self.assertTrue(classify(m)['alpha_test'])
        del m['textures']['LayerMaskMap']
        self.assertEqual(classify(m)['profile'],'unreviewed_source_shader')
        self.assertFalse(classify(m)['export_supported'])

    def test_drowse_requires_complete_enter_loop_exit_family(self):
        names=['pm0999_00_kw20_drowse'+phase+'01.gfbanm' for phase in 'ABC']
        self.assertEqual(candidates(names)['sleep'],[names[1]])
        self.assertEqual(candidates(names[1:])['sleep'],[])
        self.assertEqual(candidates(names[:2])['sleep'],[])
        self.assertEqual(candidates([names[1]])['sleep'],[])


if __name__ == '__main__': unittest.main()
