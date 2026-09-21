import copy
import json
import struct
import tempfile
import unittest
from pathlib import Path

from scvi_material_probe import eligible, inspect_materials
from phase5_review_gallery import build


class MaterialProbeTests(unittest.TestCase):
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
