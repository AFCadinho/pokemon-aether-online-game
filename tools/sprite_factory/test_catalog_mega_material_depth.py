import unittest

from catalog_mega_material_depth import apply
from catalog_mega_native_rest import native_rest


class NativeOpacityTests(unittest.TestCase):
    def test_opaque_body_and_eye_stop_using_blended_depth(self):
        document = {'materials': [{'name': n, 'alphaMode': 'BLEND',
                                  'alphaCutoff': 0.3} for n in ('body', 'eye')]}
        rows = [{'name': n, 'alpha_type': 'Opaque', 'floats': {},
                 'shaders': [{'values': {'EnableAlphaTest': 'False'}}]}
                for n in ('body', 'eye')]
        apply(document, rows)
        self.assertEqual([m['alphaMode'] for m in document['materials']],
                         ['OPAQUE', 'OPAQUE'])
        self.assertTrue(all('alphaCutoff' not in m for m in document['materials']))

    def test_real_transparency_and_additive_effects_are_preserved(self):
        document = {'materials': [{'name': n, 'alphaMode': 'BLEND'}
                                  for n in ('glass', 'slash')]}
        before = repr(document)
        rows = [{'name': n, 'alpha_type': kind, 'floats': {}, 'shaders': []}
                for n, kind in [('glass', 'BlendPreMultiAlpha'), ('slash', 'Add')]]
        apply(document, rows)
        self.assertEqual(repr(document), before)

    def test_native_alpha_cutout_uses_authored_threshold(self):
        document = {'materials': [{'name': 'beam', 'alphaMode': 'BLEND'}]}
        rows = [{'name': 'beam', 'alpha_type': 'Opaque',
                 'floats': {'DiscardValue': 0.5},
                 'shaders': [{'values': {'EnableAlphaTest': 'True'}}]}]
        apply(document, rows)
        self.assertEqual(document['materials'][0]['alphaMode'], 'MASK')
        self.assertEqual(document['materials'][0]['alphaCutoff'], 0.5)


class NativeRestTests(unittest.TestCase):
    def test_rest_keeps_mega_bone_bindings_and_drops_base_sleep_channels(self):
        own = {'name': 'faint_loop', 'channels': [{'target': {'node': 7}}],
               'samplers': [{'input': 1, 'output': 2}]}
        document = {'meshes': [{'name': 'body'}], 'animations': [
            {'name': 'idle', 'channels': []}, own,
            {'name': 'sleep', 'channels': [{'target': {'node': 42}}]}]}
        native_rest(document)
        sleep = document['animations'][2]
        self.assertEqual(sleep, {**own, 'name': 'sleep'})
        self.assertIsNot(sleep['channels'], own['channels'])
        self.assertEqual(document['meshes'], [{'name': 'body'}])
        self.assertEqual(document['animations'][0], {'name': 'idle', 'channels': []})

    def test_missing_own_rig_loop_is_held(self):
        with self.assertRaises(ValueError):
            native_rest({'animations': [{'name': 'sleep'}]})


if __name__ == '__main__':
    unittest.main()
