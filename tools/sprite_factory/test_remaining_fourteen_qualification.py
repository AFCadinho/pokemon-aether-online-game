"""Guard additive admission, approved scene identity and untouched earlier models."""
import unittest
from remaining_fourteen_admission import ROOT,HERE,RECEIPT,INDEX,GAME,LAUNCHER,NAMES,canonical,read,sha


class FourteenQualification(unittest.TestCase):
    def test_scope_and_source_pins(self):
        receipt=read(RECEIPT)
        self.assertTrue(receipt['runtime_approved'] and receipt['admitted_registry_check_passed'])
        self.assertFalse(receipt['published'] or receipt['release_approved'])
        self.assertEqual(receipt['forms_admitted'],14)
        self.assertEqual(receipt['remaining_forms'],21)
        self.assertEqual(receipt['restored_forms_across_original_229'],208)
        self.assertEqual(set(receipt['entries']),set(NAMES))
        self.assertEqual(len(set(receipt['remaining_species'])),21)
        self.assertFalse(set(receipt['remaining_species']) & set(NAMES))
        for field,file in [('previous_result_sha256','zygarde_battle_qualification.json'),
                           ('preview_receipt_sha256','remaining_forms_preview_result.json'),
                           ('sleep_receipt_sha256','remaining_forms_sleep_result.json')]:
            self.assertEqual(receipt[field],sha(HERE/file))
        for path,digest in receipt['code_sha256'].items():self.assertEqual(sha(ROOT/path),digest,path)
        for name,row in receipt['entries'].items():
            self.assertTrue(row['runtime_approved'])
            self.assertGreaterEqual(row['pixel_exact_frames'],20)
            self.assertGreaterEqual(row['battle_views'],40)
            self.assertGreaterEqual(row['battle_appearance_samples'],252)
            self.assertEqual(set(row['variants']),{'normal','shiny'})
            self.assertIn('admitted-check-'+name+'.log',receipt['evidence_sha256'])
            if name.startswith('cramorant-'):self.assertEqual(row['approved_preview_pixel_exact_frames'],20)

    def test_exact_additive_catalog_and_pair_contract(self):
        receipt=read(RECEIPT);registry=read(GAME)
        self.assertEqual(GAME.read_bytes(),LAUNCHER.read_bytes())
        self.assertEqual(registry['remaining_fourteen_qualification_sha256'],sha(RECEIPT))
        self.assertEqual(sha(INDEX),receipt['bundle_index_sha256'])
        assets=read(INDEX)['assets']
        self.assertEqual({a['species_id'] for a in assets},set(NAMES))
        self.assertEqual(len(assets),14)
        self.assertEqual(sum(a['size_bytes'] for a in assets),receipt['bundle_size_bytes'])
        for asset in assets:
            name=asset['species_id']
            self.assertEqual({a['runtime_identity'] for a in asset['appearances']},{name,name+'@shiny'})
            for appearance in asset['appearances']:
                row=registry['models'][appearance['runtime_identity']]
                self.assertEqual(row['sha256'],appearance['source_sha256'])
                self.assertEqual(row['profile'],name)
        for key in ('models','profiles'):
            before={n:v for n,v in registry[key].items() if n.removesuffix('@shiny') not in NAMES}
            self.assertEqual(canonical(before),receipt['previous_registry'][key+'_sha256'])


if __name__=='__main__':unittest.main()
