"""Reject false completion and engine failures hidden by a successful process exit."""
import copy
import hashlib
import json
import unittest
from remaining_twenty_one_result import RECEIPT,REGISTRIES,validate,read,sha,ROOT,HERE
import sys
sys.path.insert(0,str(ROOT/"tools"))
from package_approved_3d_release_v14 import historical_registry


class ReconstructionReview(unittest.TestCase):
    def test_receipt_is_preview_only_and_leaves_admission_unchanged(self):
        r=read(RECEIPT)
        for flag in ['runtime_approved','visual_approved','published','release_approved']:self.assertIs(r[flag],False)
        self.assertEqual((r['forms_previewed'],r['appearances_previewed'],r['forms_admitted'],r['remaining_forms']),(21,42,0,21))
        self.assertEqual(r['previous_qualification_sha256'],sha(HERE/'remaining_fourteen_qualification.json'))
        self.assertEqual(REGISTRIES[0].read_bytes(),REGISTRIES[1].read_bytes())
        for path,digest in r['registries_sha256'].items():
            registry=historical_registry(read(ROOT/path))
            if 'final_twenty_one_qualification_sha256' in registry:
                final=read(HERE/'final_twenty_one_qualification.json')
                self.assertEqual(registry.pop('final_twenty_one_qualification_sha256'),sha(HERE/'final_twenty_one_qualification.json'))
                names=set(read(HERE/'remaining_fourteen_qualification.json')['remaining_species'])
                self.assertEqual(set(final['entries']),names)
                for key in ['models','profiles']:registry[key]={n:v for n,v in registry[key].items() if n.removesuffix('@shiny') not in names}
            actual=hashlib.sha256((json.dumps(registry,indent='\t',allow_nan=False)+'\n').encode()).hexdigest()
            self.assertEqual(actual,digest)
        for path,digest in r['code_sha256'].items():self.assertEqual(sha(ROOT/path),digest)
        expected=set(read(HERE/'remaining_fourteen_qualification.json')['remaining_species'])
        self.assertEqual({e['base_species'] for e in r['entries']},expected)
        for n in expected:self.assertEqual({e['variant'] for e in r['entries'] if e['base_species']==n},{'normal','shiny'})
        for e in r['entries']:
            self.assertFalse(e['runtime_approved']);self.assertEqual(e['status'],'requires_art_review');self.assertTrue(e['limitations'])

    def test_validator_rejects_duplicate_missing_and_engine_errors(self):
        r=read(RECEIPT);directory=__import__('pathlib').Path(r['gallery']).parent
        if not directory.exists():self.skipTest('Local render evidence is retained only in its assigned slot')
        c=read(directory/'catalog.json');v=read(directory/'godot-review.json')
        validate(c,v,[])
        for bad in [c['entries'][:-1],c['entries'][:-1]+[c['entries'][0]]]:
            x=copy.deepcopy(c);x['entries']=bad
            with self.assertRaises(AssertionError):validate(x,v,[])
        with self.assertRaises(AssertionError):validate(c,v,['SCRIPT ERROR: Assertion failed'])
        x=copy.deepcopy(v);x['entries'][0]['errors']=['Pose depends on previous clip']
        with self.assertRaises(AssertionError):validate(c,x,[])
        x=copy.deepcopy(c)
        next(e for e in x['entries'] if e['base_species'].startswith('ogerpon-'))['changes']={}
        with self.assertRaises(AssertionError):validate(x,v,[])


if __name__=='__main__':unittest.main()
