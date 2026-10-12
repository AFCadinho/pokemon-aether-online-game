"""Focused lossless-material and admission regressions (no external source drive)."""
import hashlib
from io import BytesIO
import json
from pathlib import Path
import tempfile
import unittest
from PIL import Image
from alternate_forms_admission import checked, GAME, LAUNCHER, INDEX, RECEIPT
from alternate_forms_batch import ROOT, INTAKE
from alternate_forms_static_effects import colour
from alternate_forms_palettes import colours, validate_bindings
from scvi_form_material import sample


class SourceSafety(unittest.TestCase):
    def test_material_edit_cannot_leak_into_an_unbound_mesh(self):
        document={'nodes':[{'name':'body','mesh':0},{'name':'eyelid','mesh':0}],
            'meshes':[{'primitives':[{'material':0}]}],'materials':[{'name':'shared'}]}
        bindings=[['body_shape','shared','BaseColorLayer1',[1,1,1,1]]]
        with self.assertRaisesRegex(ValueError,'unbound mesh'):
            validate_bindings(document,bindings)
        validate_bindings(document,bindings+[['eyelid_shape','shared','BaseColorLayer1',[1,1,1,1]]])

    def test_changed_evidence_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'evidence.json';p.write_text('{"complete":true}')
            pin=hashlib.sha256(p.read_bytes()).hexdigest()
            self.assertTrue(checked(p,pin)['complete'])
            p.write_text('{"complete":false}')
            with self.assertRaisesRegex(ValueError,'Evidence changed'):checked(p,pin)

    def test_invalid_selector_is_rejected_before_opening_source(self):
        for variant,index in [('shiny',1),('normal',True),('rare',-1),('normal',18)]:
            with self.assertRaises(ValueError):colours(Path('/nonexistent'),variant,index)

    def test_sparse_source_palette_holds_previous_key(self):
        keys=[(0,0.1),(4,0.6),(9,0.9)]
        self.assertEqual(sample(keys,3),.1)
        self.assertEqual(sample(keys,4),.6)
        self.assertEqual(sample(keys,8),.6)
        self.assertEqual(sample(keys,9),.9)
        with self.assertRaises(ValueError):sample(keys,17)

    def render(self,base,mask):
        with tempfile.TemporaryDirectory() as d:
            directory=Path(d);base.save(directory/'base.png');mask.save(directory/'mask.png')
            material={'textures':{'BaseColorMap':'base.bntx','LayerMaskMap':'mask.bntx'},
                'colors':{f'BaseColorLayer{i}':[1,1,1,1] for i in range(1,5)},
                'floats':{f'LayerMaskScale{i}':.5 for i in range(1,5)}}
            return Image.open(BytesIO(colour(material,directory)))

    def test_uniform_mask_preserves_every_detailed_base_texel(self):
        base=Image.new('RGBA',(4,2));base.putdata([(i*31,255-i*29,17+i,255-i) for i in range(8)])
        result=self.render(base,Image.new('RGBA',(1,1),(255,0,0,0)))
        self.assertEqual(result.size,base.size)
        self.assertEqual(result.tobytes(),base.tobytes())

    def test_uniform_base_expands_without_discarding_mask_resolution(self):
        mask=Image.new('RGBA',(4,2));mask.putdata([(i*31,0,0,0) for i in range(8)])
        result=self.render(Image.new('RGBA',(1,1),(128,64,32,211)),mask)
        self.assertEqual(result.size,mask.size)
        self.assertEqual(set(result.getdata()),{(128,64,32,211)})

    def test_differing_detailed_domains_are_never_resampled(self):
        base=Image.new('RGBA',(2,1));base.putdata([(0,0,0,255),(255,255,255,255)])
        mask=Image.new('RGBA',(3,1));mask.putdata([(0,0,0,0),(128,0,0,0),(255,0,0,0)])
        with self.assertRaisesRegex(ValueError,'native shader sampling'):self.render(base,mask)


class AdmittedCatalog(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.receipt=json.loads(RECEIPT.read_bytes())
        cls.index=json.loads(INDEX.read_bytes())
        cls.registry=json.loads(GAME.read_bytes())

    def test_complete_pairs_and_matching_registries(self):
        self.assertEqual(GAME.read_bytes(),LAUNCHER.read_bytes())
        names=self.receipt['forms']
        self.assertEqual(len(names),len(set(names)))
        self.assertEqual(self.receipt['models'],2*len(names))
        self.assertEqual(set(names),{a['species_id'] for a in self.index['assets']})
        for asset in self.index['assets']:
            name=asset['species_id']
            self.assertEqual({a['variant'] for a in asset['appearances']},{'normal','shiny'})
            for appearance in asset['appearances']:
                model=self.registry['models'][appearance['runtime_identity']]
                self.assertEqual(model['sha256'],appearance['source_sha256'])
                self.assertEqual(model['profile'],name)
            self.assertNotIn('sha256',self.registry['profiles'][name]['motion'])

    def test_receipt_and_code_pins(self):
        r=self.receipt
        self.assertTrue(r['runtime_approved'] and r['admitted_registry_check_passed'])
        self.assertFalse(r['published'] or r['release_approved'])
        self.assertEqual(r['bundle_index_sha256'],hashlib.sha256(INDEX.read_bytes()).hexdigest())
        self.assertEqual(r['source_intake_sha256'],hashlib.sha256(INTAKE.read_bytes()).hexdigest())
        self.assertEqual(self.registry['alternate_forms_qualification_sha256'],hashlib.sha256(RECEIPT.read_bytes()).hexdigest())
        for relative,pin in r['code_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT/relative).read_bytes()).hexdigest(),pin,relative)
        self.assertEqual(r['pixel_exact_frames'],sum(e['pixel_exact_frames'] for e in r['entries']))
        for row in r['entries']:
            self.assertGreaterEqual(row['pixel_exact_frames'],20)
            self.assertGreaterEqual(row['transition_switches'],72)
            self.assertGreaterEqual(row['battle_views'],40)
            self.assertEqual(len(row['admitted_check_sha256']),64)

    def test_batch_accounts_for_every_audited_gap(self):
        result=json.loads((ROOT/'tools/sprite_factory/alternate_forms_batch_result.json').read_bytes())
        names={r['species'] for r in json.loads(INTAKE.read_bytes())['entries']}
        self.assertEqual(len(names),229)
        self.assertEqual(names,{r['species'] for r in result['entries']})
        self.assertEqual({r['species'] for r in result['entries'] if r['status']=='prepared_not_selected'},set(self.receipt['forms']))
        self.assertTrue(all(r.get('reason') for r in result['entries'] if r['status']=='held'))


if __name__=='__main__':unittest.main()
