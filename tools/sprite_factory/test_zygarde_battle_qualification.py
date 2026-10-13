"""Exact additive admission and immutable historical evidence for Zygarde 10%."""
import json
import unittest
from zygarde_battle_admission import ROOT,HERE,RECEIPT,INDEX,GAME,LAUNCHER,canonical,sha,read


class ZygardeQualification(unittest.TestCase):
    def test_accepted_local_scope_and_evidence(self):
        r=read(RECEIPT)
        self.assertTrue(r['runtime_approved'] and r['admitted_registry_check_passed'])
        self.assertFalse(r['published'] or r['release_approved'])
        self.assertEqual(r['species'],'zygarde-10')
        self.assertEqual(r['remaining_forms'],35)
        self.assertEqual(r['restored_forms_across_original_229'],194)
        self.assertEqual(r['previous_result_sha256'],sha(HERE/'remaining_forms_repair_result.json'))
        self.assertEqual(r['preview_receipt_sha256'],sha(HERE/'zygarde_preview_result.json'))
        self.assertEqual(r['pixel_exact_frames'],20)
        self.assertEqual(r['independent_material_samples'],322)
        self.assertEqual(r['battle_views'],48)
        self.assertTrue(all(len(v)==64 for v in r['evidence_sha256'].values()))
        for path,digest in r['code_sha256'].items(): self.assertEqual(sha(ROOT/path),digest,path)

    def test_exact_pair_and_previous_registry_unchanged(self):
        r=read(RECEIPT);registry=read(GAME)
        self.assertEqual(GAME.read_bytes(),LAUNCHER.read_bytes())
        self.assertEqual(registry['zygarde_ten_qualification_sha256'],sha(RECEIPT))
        self.assertEqual(sha(INDEX),r['bundle_index_sha256'])
        asset,=read(INDEX)['assets']
        self.assertEqual(asset['species_id'],'zygarde-10')
        self.assertEqual({a['runtime_identity'] for a in asset['appearances']},{'zygarde-10','zygarde-10@shiny'})
        for a in asset['appearances']:
            self.assertEqual(registry['models'][a['runtime_identity']]['sha256'],a['source_sha256'])
            self.assertEqual(registry['models'][a['runtime_identity']]['profile'],'zygarde-10')
        for kind in ('models','profiles'):
            later=set(read(HERE/'remaining_fourteen_qualification.json')['entries'])
            before={k:v for k,v in registry[kind].items() if k.removesuffix('@shiny') not in later | {'zygarde-10'}}
            self.assertEqual(canonical(before),r['previous_registry'][kind+'_sha256'])


if __name__=='__main__':unittest.main()
