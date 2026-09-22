import hashlib
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

from visibility_variants import binding, verify


def named_tables(names):
    """Synthetic TRMDL/TRMSH subset: root slot 1 -> tables with name slot 0."""
    data = bytearray(4)
    def table(count):
        vt=len(data)
        data.extend(struct.pack('<HH',4+count*2,4+count*4))
        data.extend(struct.pack('<'+'H'*count,*[4+i*4 for i in range(count)]))
        pos=len(data);data.extend(struct.pack('<i',pos-vt)+bytes(count*4))
        return pos
    def link(pos,target):struct.pack_into('<I',data,pos,target-pos)
    root=table(2);struct.pack_into('<I',data,0,root)
    vector=len(data);data.extend(struct.pack('<I',len(names))+bytes(4*len(names)))
    link(root+8,vector)
    for i,name in enumerate(names):
        t=table(1);link(vector+4+i*4,t)
        p=len(data);raw=name.encode();data.extend(struct.pack('<I',len(raw))+raw+b'\0');link(t+4,p)
    return bytes(data)


class VariantBindingTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.files={}
        self.catalog_path=self.root/'catalog';self.catalog_path.write_bytes(b'catalog')
        self.digest=hashlib.sha256(b'catalog').hexdigest()
        self.rows=[]
        for identity,gender,form in [('selected',0,0),('alternate',1,0),('otherform',1,1)]:
            self.rows.append(dict(resource_id=identity,internal_species_id=42,
                                 gender_code=gender,form=form,model_path=identity+'/model.trmdl'))
            for base in ['models','romfs']:
                d=self.root/base/identity;d.mkdir(parents=True)
                for name,data in [('model.trmdl',named_tables(['main.trmsh'])),
                                  ('main.trmsh',named_tables([identity+'_body_mesh_shape']))]:
                    p=d/name;p.write_bytes(data);self.files[str(p)]=hashlib.sha256(data).hexdigest()
        self.intake={'identity':'selected','model_dir':str(self.root/'models/selected'),
                     'identity_evidence':{'catalog_path':str(self.catalog_path),'catalog_sha256':self.digest,
                     'identity':self.rows[0].copy(),'model_root':str(self.root/'models'),
                     'motion_root':str(self.root/'romfs'),'source_sha256':self.files}}
        self.mock=patch('visibility_variants.read_catalog',side_effect=lambda p:{
            'catalog_sha256':hashlib.sha256(Path(p).read_bytes()).hexdigest(),'entries':self.rows})
        self.mock.start();self.addCleanup(self.mock.stop)

    def resolve(self,meshes=None,targets=None):
        return binding(self.intake, meshes or ['selected_body_mesh'],
                       targets or ['selected_body_mesh_shape','alternate_body_mesh_shape'])

    def test_metadata_membership_not_name_replacement(self):
        result=self.resolve()
        self.assertEqual(result['active_targets'],['selected_body_mesh_shape'])
        self.assertEqual(result['excluded_targets']['alternate_body_mesh_shape'],
                         {'resource_id':'alternate','gender_code':1})
        verify(result)

    def test_missing_selected_mesh_is_not_ignored(self):
        with self.assertRaisesRegex(ValueError,'selected source variant'):
            self.resolve(['alternate_body_mesh'])

    def test_reverse_gender_selection_uses_same_rule(self):
        self.intake['identity']='alternate'
        self.intake['model_dir']=str(self.root/'models/alternate')
        self.intake['identity_evidence']['identity']=self.rows[1].copy()
        result=self.resolve(['alternate_body_mesh'])
        self.assertEqual(result['active_targets'],['alternate_body_mesh_shape'])
        self.assertEqual(result['excluded_targets']['selected_body_mesh_shape']['gender_code'],0)

    def test_unknown_or_other_form_target_rejected(self):
        for name in ['typo_mesh_shape','otherform_body_mesh_shape']:
            with self.assertRaisesRegex(ValueError,'Unknown or ambiguous'):
                self.resolve(targets=['selected_body_mesh_shape',name])

    def test_ambiguous_owner_rejected(self):
        self.rows.append(dict(self.rows[1],resource_id='another',gender_code=2))
        with self.assertRaisesRegex(ValueError,'ambiguous'):self.resolve()

    def test_changed_selected_hash_rejected(self):
        self.files[str(self.root/'models/selected/main.trmsh')]='0'*64
        with self.assertRaisesRegex(ValueError,'hash changed'):self.resolve()

    def test_sibling_differs_from_romfs_rejected(self):
        (self.root/'models/alternate/main.trmsh').write_bytes(named_tables(['wrong_shape']))
        with self.assertRaisesRegex(ValueError,'differs from ROMFS'):self.resolve()

    def test_catalog_and_selection_drift_rejected(self):
        self.intake['identity_evidence']['identity']['form']=1
        with self.assertRaisesRegex(ValueError,'identity differs'):self.resolve()
        self.intake['identity_evidence']['identity']['form']=0
        self.catalog_path.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError,'catalog hash changed'):self.resolve()

    def test_metadata_rechecked_after_resolution(self):
        result=self.resolve();(self.root/'romfs/alternate/main.trmsh').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError,'changed during export'):verify(result)

    def test_unused_sibling_not_required(self):
        (self.root/'models/alternate/main.trmsh').unlink()
        self.assertEqual(self.resolve(targets=['selected_body_mesh_shape'])['excluded_targets'],{})

    def test_unsafe_mesh_reference_rejected(self):
        data=named_tables(['../escape.trmsh'])
        for base in ['models','romfs']:
            p=self.root/base/'selected/model.trmdl';p.write_bytes(data)
            self.files[str(p)]=hashlib.sha256(data).hexdigest()
        with self.assertRaisesRegex(ValueError,'Unsafe visibility mesh reference'):self.resolve()


if __name__=='__main__':unittest.main()
