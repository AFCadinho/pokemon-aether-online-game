"""Regression guards for complete, additive, locally qualified form admission."""
import hashlib,json,tempfile,unittest
from pathlib import Path
from final_twenty_one_admission import ROOT,HERE,RECEIPT,INDEX,GAME,LAUNCHER,NAMES,read,sha,canonical,clean_log
import sys
sys.path.insert(0,str(ROOT/"tools"))
from package_approved_3d_release_v14 import historical_registry

class FinalFormsQualification(unittest.TestCase):
    def test_complete_batch_and_evidence_identity(self):
        r=read(RECEIPT)
        self.assertTrue(r['runtime_approved'] and r['admitted_registry_check_passed'])
        self.assertFalse(r['published'] or r['release_approved'])
        self.assertEqual((r['forms_admitted'],r['remaining_forms'],r['restored_forms_across_original_229']),(21,0,229))
        self.assertEqual(r['remaining_species'],[])
        self.assertEqual(set(r['entries']),set(NAMES))
        self.assertEqual(r['previous_qualification_sha256'],sha(HERE/'remaining_fourteen_qualification.json'))
        self.assertEqual(r['preview_receipt_sha256'],sha(HERE/'remaining_twenty_one_result.json'))
        for p,h in r['code_sha256'].items():self.assertEqual(sha(ROOT/p),h,p)
        for name,e in r['entries'].items():
            self.assertTrue(e['runtime_approved'] and e['authored_reconstruction'])
            self.assertEqual(set(e['variants']),{'normal','shiny'})
            self.assertGreaterEqual(e['pixel_exact_frames'],20)
            self.assertGreaterEqual(e['battle_views'],40)
            self.assertGreaterEqual(e['minimum_idle_height_pixels'],60)
            self.assertGreaterEqual(e['battle_appearance_samples'],252)
            self.assertIn('admitted-check-'+name+'.log',r['evidence_sha256'])

    def test_only_these_twenty_one_pairs_are_added(self):
        r=read(RECEIPT);registry=historical_registry(read(GAME))
        self.assertEqual(GAME.read_bytes(),LAUNCHER.read_bytes())
        self.assertEqual(registry['final_twenty_one_qualification_sha256'],sha(RECEIPT))
        previous={**registry}
        for key in ['models','profiles']:
            previous[key]={n:v for n,v in registry[key].items() if n.removesuffix('@shiny') not in NAMES}
            self.assertEqual(canonical(previous[key]),r['previous_registry'][key+'_sha256'])
        previous.pop('final_twenty_one_qualification_sha256')
        self.assertEqual(hashlib.sha256((json.dumps(previous,indent='\t',allow_nan=False)+'\n').encode()).hexdigest(),r['previous_registry_sha256'])
        assets=read(INDEX)['assets'];self.assertEqual(sha(INDEX),r['bundle_index_sha256'])
        self.assertEqual({a['species_id'] for a in assets},set(NAMES));self.assertEqual(len(assets),21)
        self.assertEqual(sum(a['size_bytes'] for a in assets),r['bundle_size_bytes'])
        for asset in assets:
            name=asset['species_id'];self.assertEqual({a['runtime_identity'] for a in asset['appearances']},{name,name+'@shiny'})
            for appearance in asset['appearances']:
                row=registry['models'][appearance['runtime_identity']]
                self.assertEqual(row['sha256'],appearance['source_sha256']);self.assertEqual(row['profile'],name)

    def test_engine_errors_are_not_masked_by_success_marker(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'run.log';path.write_text('FORM_BATCH_RUNTIME_OK\n')
            clean_log(path,'FORM_BATCH_RUNTIME_OK')
            path.write_text('SCRIPT ERROR: Assertion failed\nFORM_BATCH_RUNTIME_OK\n')
            with self.assertRaises(AssertionError):clean_log(path,'FORM_BATCH_RUNTIME_OK')

if __name__=='__main__':unittest.main()
