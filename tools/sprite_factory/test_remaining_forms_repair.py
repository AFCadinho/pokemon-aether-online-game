"""Focused admission and compatibility regressions for the selected 18 forms."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from remaining_forms_pin_checks import code_pin_valid

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).parent


def read(path): return json.loads(path.read_bytes())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def canonical(value): return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()


class RemainingForms(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.receipt=read(HERE/'remaining_forms_repair_qualification.json')
        cls.result=read(HERE/'remaining_forms_repair_result.json')
        cls.registry=read(ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json')

    def test_exact_scope_and_honest_remaining_total(self):
        selected=read(HERE/'remaining_forms_repair_intake.json')['entries']
        self.assertEqual(len({r['species'] for r in selected}),18)
        rows=self.result['entries']
        previous=read(HERE/'remaining_forms_investigation.json')['entries']
        self.assertEqual({r['species'] for r in rows},{r['species'] for r in previous})
        self.assertEqual(len(rows),53)
        self.assertEqual(sum(r['runtime_approved'] for r in rows),17)
        self.assertEqual(sum(not r['runtime_approved'] for r in rows),36)
        self.assertEqual({r['species'] for r in rows if r['status']=='renderer_held'},{'zygarde-10'})

    def test_pair_admission_and_catalog_parity(self):
        r=self.receipt
        self.assertEqual(set(r['forms']),{'poltchageist-artisan','sinistcha-masterpiece','rotom-fan','xerneas-neutral'})
        self.assertTrue(r['runtime_approved'] and r['admitted_registry_check_passed'])
        self.assertFalse(r['published'] or r['release_approved'])
        self.assertEqual((ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json').read_bytes(),(ROOT/'launcher/data/reviewed_model_catalog.json').read_bytes())
        p=ROOT/'release/approved_3d_remaining_forms_index.json'
        self.assertEqual(sha(p),r['bundle_index_sha256'])
        self.assertEqual(self.registry['remaining_forms_repair_qualification_sha256'],sha(HERE/'remaining_forms_repair_qualification.json'))
        for asset in read(p)['assets']:
            self.assertEqual({a['variant'] for a in asset['appearances']},{'normal','shiny'})
            for a in asset['appearances']:
                self.assertEqual(self.registry['models'][a['runtime_identity']]['sha256'],a['source_sha256'])
        self.assertEqual(r['pixel_exact_frames'],sum(x['pixel_exact_frames'] for x in r['entries']))
        for row in r['entries']:
            self.assertGreaterEqual(row['pixel_exact_frames'],20)
            self.assertGreaterEqual(row['transition_switches'],72)
            self.assertGreaterEqual(row['battle_views'],40)
            self.assertEqual(len(row['admitted_check_sha256']),64)
        self.assertEqual(r['shared_forms']['additional_model_bytes'],0)
        self.assertEqual(len(r['shared_forms']['forms']),13)

    def test_existing_models_and_profiles_are_unchanged(self):
        # The later Zygarde admission has its own exact baseline regression.
        names=set(self.receipt['forms']) | {'zygarde-10'} | set(read(HERE/'remaining_fourteen_qualification.json')['entries'])
        for key in ('models','profiles'):
            previous={n:v for n,v in self.registry[key].items() if n.removesuffix('@shiny') not in names}
            self.assertEqual(canonical(previous),self.result['previous_registry'][key+'_sha256'])
        for path,pin in self.result['previous_approvals'].items(): self.assertEqual(sha(ROOT/path),pin)

    def test_current_source_and_code_pins(self):
        r=self.receipt
        self.assertEqual(sha(HERE/'remaining_forms_repair_intake.json'),r['source_intake_sha256'])
        for path,pin in r['code_sha256'].items(): self.assertEqual(sha(ROOT/path),pin,path)
        self.assertEqual(self.result['qualification_sha256'],sha(HERE/'remaining_forms_repair_qualification.json'))

    def test_historical_pin_does_not_accept_unqualified_changes(self):
        name='scripts/battle/battle_ui/reviewed_model_catalog.gd'
        old=self.receipt['historical_code_sha256'][name]
        self.assertTrue(code_pin_valid(ROOT,name,old))
        self.assertFalse(code_pin_valid(ROOT,name,'0'*64))
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder); path=root/name;path.parent.mkdir(parents=True);path.write_text('unapproved')
            receipt=copy.deepcopy(self.receipt)
            p=root/'tools/sprite_factory/remaining_forms_repair_qualification.json';p.parent.mkdir(parents=True);p.write_text(json.dumps(receipt))
            self.assertFalse(code_pin_valid(root,name,old))
            receipt['code_sha256'][name]=sha(path);receipt['admitted_registry_check_passed']=False;p.write_text(json.dumps(receipt))
            self.assertFalse(code_pin_valid(root,name,old))


if __name__=='__main__': unittest.main()
