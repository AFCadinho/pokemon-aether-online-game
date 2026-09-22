import copy
import json
import struct
import tempfile
import unittest
from pathlib import Path

from scvi_material_probe import eligible, inspect_materials
from phase5_review_gallery import build
from material_profiles import classify, unsupported, REFRACTION_UNSUPPORTED


class MaterialProbeTests(unittest.TestCase):
    def test_native_refraction_is_blocked_before_opaque_baking(self):
        for shaders in ([{'name': 'Transparent', 'values': {}}],
                        [{'name': 'TransparentInner', 'values': {}}],
                        [{'name': 'renamed_shader', 'values': {'RefractionMode': 'Thin'}}],
                        [{'name': 'Transparent', 'values': {'RefractionMode': 'Thin'}},
                         {'name': 'TransparentInner', 'values': {'RefractionMode': 'Thin'}}]):
            for name in ('arbitrary_surface', 'renamed_surface'):
                with self.subTest(shaders=shaders, name=name):
                    result = classify({'name': name, 'shaders': shaders, 'alpha_type': 'Opaque'})
                    self.assertEqual(result['profile'], REFRACTION_UNSUPPORTED)
                    self.assertEqual(unsupported([result]), [result])

    def test_refraction_gate_does_not_reject_eye_clearcoat_by_alpha_label(self):
        for name in ('Eye', 'EyeClearCoat', 'Standard'):
            result = classify({'name': 'surface', 'alpha_type': 'BlendPreMultiAlpha',
                               'shaders': [{'name': name, 'values': {}}]})
            self.assertTrue(result['export_supported'])
            self.assertEqual(result['profile'], 'existing_graph_validation_required')

    def test_refraction_takes_precedence_over_effect_signature(self):
        material = self.profile()
        self.assertTrue(classify(material)['export_supported'])
        material['shaders'][0]['values']['RefractionMode'] = 'Thin'
        self.assertFalse(classify(material)['export_supported'])

    def profile(self):
        return {'name': 'any_material', 'shaders': [{'name': 'NonDirectional', 'values': {
            'EnableBaseColorMap': 'True', 'EnableDisplacementMap': 'True',
            'NumMaterialLayer': '5', 'NumRequiredUV': '2'}}],
            'textures': dict.fromkeys(['BaseColorMap', 'LayerMaskMap', 'DisplacementMap'], 'texture.bntx')}

    def test_profile_is_semantic_not_species_or_material_name(self):
        profile = self.profile()
        self.assertTrue(eligible(profile))
        profile['name'] = 'unrelated_name'
        self.assertTrue(eligible(profile))

    def test_unsupported_signatures_are_not_silently_changed(self):
        for key in self.profile()['shaders'][0]['values']:
            profile = self.profile()
            profile['shaders'][0]['values'][key] = 'unsupported'
            self.assertFalse(eligible(profile))
        for key in self.profile()['textures']:
            profile = self.profile()
            del profile['textures'][key]
            self.assertFalse(eligible(profile))
        profile = self.profile()
        profile['shaders'][0]['name'] = 'Standard'
        self.assertFalse(eligible(profile))
        profile['shaders'].append(copy.deepcopy(profile['shaders'][0]))
        self.assertFalse(eligible(profile))

    def test_truncated_source_does_not_produce_valid_profile(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'bad.trmtr'
            path.write_bytes(b'bad')
            with self.assertRaises(struct.error):
                inspect_materials(path)

    def test_gallery_marks_probe_as_experimental(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'catalog.json').write_text(json.dumps({'approval': False,
                'material_probe': True, 'entries': []}))
            build(root)
            page = (root / 'index.html').read_text()
            self.assertIn('EXPERIMENTAL MATERIAL PROBE', page)
            self.assertIn('No model is approved', page)


if __name__ == '__main__':
    unittest.main()
