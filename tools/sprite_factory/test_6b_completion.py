import copy,hashlib,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from material_profiles import classify,UNLIT
from material_effect_export import prepare
from source_repairs import decision

class CompletionTests(unittest.TestCase):
    def effect_fixture(self, root):
        material={'name':'any','shaders':[{'name':'Unlit','values':{'EnableBaseColorMap':'True','EnableDisplacementMap':'True','NumMaterialLayer':'5','NumRequiredUV':'1'}}],
                  'textures':dict.fromkeys(['BaseColorMap','LayerMaskMap','DisplacementMap'],'any.bntx'),
                  'floats':{'DisplacementHeight':0.05,'EmissionIntensity':1.0}}
        source=root/'material.trmtr';source.write_bytes(b'fixture')
        (root/'any.png').write_bytes(b'texture')
        (root/'first_loop01_loop.tracm').write_bytes(b'motion')
        def channel(a,b):return [{'time':0,'value':a,'config':[0,0,0]}, {'time':120,'value':b,'config':[0,0,1]}]
        motion={'frames':121,'fps':60,'multiplier':1,'config_flag':1,'tracks':[
            {'material':'any','parameter':p,'channels':[channel(1,1),channel(1,1),channel(0,1),channel(0,0)]}
            for p in ('UVScaleOffset','UVScaleOffset3')]}
        job={'material_source':str(source),'material_source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'effect_motion_dir':str(root)}
        return material,motion,job

    def test_effect_uses_source_loop_and_collapses_only_identical_banks(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);material,motion,job=self.effect_fixture(root)
            (root/'second_loop01_loop.tracm').write_bytes(b'second-bank')
            with patch('material_effect_export.inspect_materials',return_value=[material]), patch('material_effect_export.read_uv_tracks',side_effect=lambda _:copy.deepcopy(motion)):
                records=prepare(job)
            self.assertEqual(records[0]['loop_seconds'],2.0)
            self.assertEqual(records[0]['height'],0.05)
            self.assertEqual(len(records[0]['motion_sources']),2)
            self.assertFalse(records[0]['use_uv2'])

    def test_effect_rejects_incomplete_nonperiodic_and_conflicting_tracks(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);material,motion,job=self.effect_fixture(root)
            with patch('material_effect_export.inspect_materials',return_value=[material]):
                bad=copy.deepcopy(motion);bad['tracks'].pop()
                with patch('material_effect_export.read_uv_tracks',return_value=bad), self.assertRaisesRegex(ValueError,'both reviewed'):prepare(job)
                bad=copy.deepcopy(motion);bad['tracks'][0]['channels'][2][1]['value']=0.5
                with patch('material_effect_export.read_uv_tracks',return_value=bad), self.assertRaisesRegex(ValueError,'Nonperiodic'):prepare(job)
                (root/'second_loop01_loop.tracm').write_bytes(b'conflicting-bank')
                bad=copy.deepcopy(motion);bad['fps']=30
                with patch('material_effect_export.read_uv_tracks',side_effect=[copy.deepcopy(motion),bad]), self.assertRaisesRegex(ValueError,'ambiguous'):prepare(job)

    def test_explicit_repair_is_hash_and_action_bound(self):
        data=json.loads(Path(__file__).with_name('reviewed_source_repairs.json').read_text())['repairs'][0]
        self.assertIsNone(decision('unrelated',data['allowed_actions']))
        self.assertEqual(decision(data['source_sha256'],data['allowed_actions'])['id'],data['id'])
        for actions in [[], {}.values(), ['unreviewed_vine_attack']]:
            with self.assertRaises(ValueError):decision(data['source_sha256'],actions)

    def test_unlit_one_uv_is_not_forced_into_two_uv_smoke(self):
        source={'name':'any','shaders':[{'name':'Unlit','values':{'EnableBaseColorMap':'True','EnableDisplacementMap':'True','NumMaterialLayer':'5','NumRequiredUV':'1'}}],
                'textures':dict.fromkeys(['BaseColorMap','LayerMaskMap','DisplacementMap'],'texture.bntx')}
        self.assertEqual(classify(source)['profile'],UNLIT)
        source['shaders'][0]['values']['NumRequiredUV']='2'
        self.assertFalse(classify(source)['export_supported'])

    def test_effect_rejects_changed_material_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'material.trmtr';p.write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError,'provenance'):
                prepare({'material_source':str(p),'material_source_sha256':'0'*64})

    def test_effect_cannot_pass_without_source_motion(self):
        m={'name':'any','shaders':[{'name':'Unlit','values':{'EnableBaseColorMap':'True','EnableDisplacementMap':'True','NumMaterialLayer':'5','NumRequiredUV':'1'}}],
           'textures':dict.fromkeys(['BaseColorMap','LayerMaskMap','DisplacementMap'],'any.bntx')}
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'material.trmtr';p.write_bytes(b'fixture')
            job={'material_source':str(p),'material_source_sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
            with patch('material_effect_export.inspect_materials',return_value=[m]):
                with self.assertRaisesRegex(ValueError,'motion directory'):prepare(job)

if __name__=='__main__':unittest.main()
