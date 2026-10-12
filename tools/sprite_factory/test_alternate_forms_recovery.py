"""Recovery admission keeps old approvals and exact normal/shiny pairs intact."""
import hashlib
import json
from pathlib import Path
import unittest
from alternate_forms_recovery import ROOT, INTAKE
from alternate_forms_recovery_selectors import parameters


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class RecoverySafety(unittest.TestCase):
    def test_invalid_scalar_selector_is_rejected_without_reading_source(self):
        for variant,index in [('shiny',1),('normal',True),('rare',-1),('normal',18),('normal',1.5)]:
            with self.subTest(variant=variant,index=index),self.assertRaises(ValueError):
                parameters(Path('/no/source'),variant,index)

    def test_intake_is_unique_and_only_reconsiders_original_holds(self):
        original=json.loads((ROOT/'tools/sprite_factory/alternate_forms_batch_result.json').read_bytes())
        held={r['species'] for r in original['entries'] if r['status']=='held'}
        intake=json.loads(INTAKE.read_bytes())['entries']
        names=[r['species'] for r in intake]
        self.assertEqual(len(names),len(set(names)))
        self.assertTrue(set(names)<=held)
        self.assertEqual(len(held),109)

    def test_previous_approval_code_and_release_are_unchanged(self):
        old=json.loads((ROOT/'tools/sprite_factory/alternate_forms_qualification.json').read_bytes())
        for name,pin in old['code_sha256'].items():
            self.assertEqual(digest(ROOT/name),pin,name)
        self.assertEqual(digest(ROOT/'release/approved_3d_alternate_forms_index.json'),old['bundle_index_sha256'])


class RecoveryCatalog(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.receipt_path=ROOT/'tools/sprite_factory/alternate_forms_recovery_qualification.json'
        cls.receipt=json.loads(cls.receipt_path.read_bytes())
        cls.index_path=ROOT/'release/approved_3d_alternate_forms_recovery_index.json'
        cls.index=json.loads(cls.index_path.read_bytes())
        cls.game=ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json'
        cls.registry=json.loads(cls.game.read_bytes())

    def test_complete_distinct_pairs_and_matching_catalogs(self):
        self.assertEqual(self.game.read_bytes(),(ROOT/'launcher/data/reviewed_model_catalog.json').read_bytes())
        r=self.receipt
        self.assertEqual(set(r['forms']),{a['species_id'] for a in self.index['assets']})
        self.assertEqual(r['models'],2*len(r['forms']))
        old=json.loads((ROOT/'tools/sprite_factory/alternate_forms_qualification.json').read_bytes())
        self.assertFalse(set(old['forms'])&set(r['forms']))
        for asset in self.index['assets']:
            self.assertEqual({a['variant'] for a in asset['appearances']},{'normal','shiny'})
            for a in asset['appearances']:
                model=self.registry['models'][a['runtime_identity']]
                self.assertEqual(model['sha256'],a['source_sha256'])
                self.assertEqual(model['profile'],asset['species_id'])

    def test_receipt_pins_all_evidence_and_does_not_publish(self):
        r=self.receipt
        self.assertTrue(r['runtime_approved'] and r['admitted_registry_check_passed'])
        self.assertFalse(r['release_approved'] or r['published'])
        self.assertEqual(r['source_intake_sha256'],digest(INTAKE))
        self.assertEqual(r['bundle_index_sha256'],digest(self.index_path))
        self.assertEqual(self.registry['alternate_forms_recovery_qualification_sha256'],digest(self.receipt_path))
        self.assertEqual(r['previous_qualification_sha256'],digest(ROOT/'tools/sprite_factory/alternate_forms_qualification.json'))
        for name,pin in r['code_sha256'].items():self.assertEqual(digest(ROOT/name),pin,name)
        self.assertEqual(r['pixel_exact_frames'],sum(e['pixel_exact_frames'] for e in r['entries']))
        for entry in r['entries']:
            self.assertGreaterEqual(entry['pixel_exact_frames'],20)
            self.assertGreaterEqual(entry['transition_switches'],72)
            self.assertGreaterEqual(entry['battle_views'],40)
            self.assertEqual(len(entry['admitted_check_sha256']),64)

    def test_size_forms_retain_source_ratios_in_battle(self):
        for family in ('pumpkaboo', 'gourgeist'):
            profiles=[self.registry['profiles'][family+'-'+size]
                      for size in ('small','large','super')]
            heights=[p['placement']['scale']*p['bounds']['idle']['size'][1]
                     for p in profiles]
            self.assertLess(heights[0],heights[1])
            self.assertLess(heights[1],heights[2])
            # Super has its own idle duration and poses; its animated envelope
            # is not exactly twice Small's. Preserve the native configuration
            # ratios and verify the resulting visible heights remain ordered.
            scales=[p['placement']['scale'] for p in profiles]
            self.assertAlmostEqual(scales[1]/scales[0],1.4/.8,places=6)
            self.assertAlmostEqual(scales[2]/scales[0],1.0/.8,places=6)
            self.assertAlmostEqual(heights[1]/heights[0],1.4/.8,places=4)

    def test_every_one_of_the_109_is_accounted_for(self):
        report=json.loads((ROOT/'tools/sprite_factory/alternate_forms_recovery_result.json').read_bytes())
        original=json.loads((ROOT/'tools/sprite_factory/alternate_forms_batch_result.json').read_bytes())
        held={r['species'] for r in original['entries'] if r['status']=='held'}
        self.assertEqual(held,{r['species'] for r in report['entries']})
        self.assertEqual(set(self.receipt['forms']),{r['species'] for r in report['entries'] if r['status']=='prepared_not_selected'})
        self.assertTrue(all(r.get('reason') for r in report['entries']))
        self.assertEqual(report['summary']['prepared_not_selected']+report['summary']['held'],109)


if __name__=='__main__':unittest.main()
