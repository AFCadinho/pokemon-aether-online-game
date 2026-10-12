"""Therian identities must stay distinct from Incarnate and carry both palettes."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
FORMS = {'tornadus-therian': 641, 'thundurus-therian': 642, 'landorus-therian': 645}


def read(path):
    return json.loads((ROOT / path).read_bytes())


class TherianModelsTests(unittest.TestCase):
    def test_distinct_form_and_palette_bindings(self):
        registry = read('scripts/battle/battle_ui/reviewed_model_catalog.json')
        assets = read('release/approved_3d_therian_index.json')['assets']
        self.assertEqual({a['species_id'] for a in assets}, set(FORMS))
        self.assertEqual(len(assets), 3)
        for asset in assets:
            species = asset['species_id']
            self.assertEqual(asset['national_dex'], FORMS[species])
            self.assertEqual(asset['asset_id'], 'pokemon_3d:' + species + ':base')
            self.assertEqual(asset['appearances'], asset['pair_manifest']['appearances'])
            self.assertEqual({a['runtime_identity'] for a in asset['appearances']}, {species, species + '@shiny'})
            self.assertEqual(len({a['runtime_sha256'] for a in asset['appearances']}), 2)
            for appearance in asset['appearances']:
                model = registry['models'][appearance['runtime_identity']]
                self.assertEqual(model['sha256'], appearance['source_sha256'])
                self.assertEqual(model['profile'], species)
                base = species.removesuffix('-therian') + ('@shiny' if appearance['variant'] == 'shiny' else '')
                self.assertNotEqual(model['sha256'], registry['models'][base]['sha256'])
            profile = registry['profiles'][species]
            self.assertEqual(set(profile['action_timing']), {'idle', 'physical_attack', 'physical_attack_2',
                             'special_attack', 'damage', 'sleep', 'faint_start', 'faint_loop'})
            self.assertEqual(profile['placement']['hover_height'], 0 if species == 'landorus-therian' else .45)
            self.assertEqual(profile['attack_family_actions']['body_charge'], 'physical_attack_2')

    def test_qualification_pin_and_release_boundary(self):
        receipt_path = ROOT / 'tools/sprite_factory/catalog_therian_qualification.json'
        registry = read('scripts/battle/battle_ui/reviewed_model_catalog.json')
        self.assertEqual(registry['therian_qualification_sha256'], hashlib.sha256(receipt_path.read_bytes()).hexdigest())
        receipt = json.loads(receipt_path.read_bytes())
        self.assertTrue(receipt['runtime_approved'])
        self.assertTrue(receipt['admitted_registry_check_passed'])
        self.assertFalse(receipt['published'])
        self.assertFalse(receipt['release_approved'])
        self.assertEqual(receipt['pixel_exact_frames'], 72)
        self.assertEqual(receipt['bundle_index_sha256'], hashlib.sha256(
            (ROOT / 'release/approved_3d_therian_index.json').read_bytes()).hexdigest())
        active = read('release/approved_3d_bundles_v13_index.json')
        self.assertFalse(any(a.get('species_id') in FORMS for a in active['assets']))
        intake_path = ROOT / 'tools/sprite_factory/catalog_therian_source_intake.json'
        self.assertEqual(receipt['source_intake_sha256'], hashlib.sha256(intake_path.read_bytes()).hexdigest())
        intake = json.loads(intake_path.read_bytes())
        for entry in intake['entries']:
            self.assertEqual(entry['resource'], 'pm%04d_12_00' % FORMS[entry['species']])
            self.assertTrue(all(action.startswith(entry['resource']) for action in entry['actions'].values()))


if __name__ == '__main__':
    unittest.main()
