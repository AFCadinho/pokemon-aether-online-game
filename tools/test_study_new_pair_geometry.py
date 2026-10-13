import unittest

from study_new_pair_geometry import FIELDS, hold_reasons


class NewPairGeometryGuards(unittest.TestCase):
    def candidate(self):
        return {**{field: True for field in FIELDS},
                'variants': [{'sensitive_tracks': []}, {'sensitive_tracks': []}],
                'components': {'meshes': {'mesh': {'shareable': True}},
                               'skins': {'skin': {'shareable': True}},
                               'libraries': {'animation': {'shareable': True}}}}

    def test_exact_components_are_eligible(self):
        self.assertEqual(hold_reasons(self.candidate()), [])

    def test_each_structural_mismatch_retains_the_pair(self):
        for field in FIELDS:
            with self.subTest(field=field):
                row = self.candidate()
                row[field] = False
                self.assertEqual(hold_reasons(row), [field])

    def test_sensitive_tracks_in_either_variant_retain_the_pair(self):
        for variant in (0, 1):
            with self.subTest(variant=variant):
                row = self.candidate()
                row['variants'][variant]['sensitive_tracks'] = ['special_attack:body:material_override']
                self.assertIn('material_mesh_or_method_animation_tracks', hold_reasons(row))

    def test_one_scene_local_or_dependent_component_retains_whole_pair(self):
        row = self.candidate()
        row['components']['meshes']['mesh']['shareable'] = False
        self.assertEqual(hold_reasons(row), ['scene_local_or_dependent_resource'])


if __name__ == '__main__':
    unittest.main()
