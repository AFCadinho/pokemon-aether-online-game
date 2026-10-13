"""Fail closed on v14 source, catalog, immutable version and admission bindings."""
import copy,json,hashlib,unittest
from package_approved_3d_release_v14 import ROOT,COHORTS,read,sha,historical_registry,REGISTRY,BINDING
from publish_approved_3d_index_v14 import validate_local

class V14Release(unittest.TestCase):
 def test_complete_parity_and_sources(self):
  meta=validate_local();b=read(BINDING)
  self.assertEqual(meta['new_pairs'],220);self.assertEqual(meta['compression_saved_bytes'],1029628070)
  self.assertEqual((b['pairs'],b['appearances']),(1420,2840));self.assertTrue(b['profiles_unchanged'])
  for side in ['data','launcher/data']:
   self.assertEqual((ROOT/side/'approved_3d_release_v14.json').read_bytes(),(ROOT/'data/approved_3d_release_v14.json').read_bytes())
  self.assertEqual(len(b['zip_model_bindings']),110)
  for path,pin in b['source_qualification_sha256'].items():self.assertEqual(sha(ROOT/path),pin)
 def test_exact_historical_admission_preserved(self):
  registry=read(REGISTRY);self.assertEqual(REGISTRY.read_bytes(),(ROOT/'launcher/data/reviewed_model_catalog.json').read_bytes())
  old=historical_registry(registry);data=(json.dumps(old,indent='\t',allow_nan=False)+'\n').encode()
  self.assertEqual(hashlib.sha256(data).hexdigest(),read(BINDING)['previous_registry_sha256'])
  self.assertEqual(old['profiles'],registry['profiles'])
  for identity,change in read(BINDING)['zip_model_bindings'].items():
   self.assertTrue(change['decoded_byte_exact']);self.assertEqual(old['models'][identity],change['previous'])
   self.assertEqual(registry['models'][identity]['sha256'],change['previous']['sha256'])
   self.assertEqual(set(registry['models'][identity]['previous_sha256'])-set(change['previous'].get('previous_sha256',[])),{change['candidate_sha256']})
  forged=copy.deepcopy(registry);forged['models'][next(iter(read(BINDING)['zip_model_bindings']))]['sha256']='0'*64
  with self.assertRaises(AssertionError):historical_registry(forged)
 def test_incremented_immutable_archive_versions(self):
  old={a['asset_id']:a for a in read(ROOT/'release/approved_3d_bundles_v13.json')['bundles']}
  catalog={a['asset_id']:a for a in read(ROOT/'data/model_pair_release_v14_catalog.json')['assets']}
  for a in read(ROOT/'release/approved_3d_bundles_v14_index.json')['assets']:
   row=catalog.get(a['asset_id'],a)
   if row['asset_id'] in old:
    previous=old[row['asset_id']];version=int(previous['object_key'].split('/')[-1].split('-')[0][1:])
    self.assertEqual(row['version'],version+1);self.assertNotEqual(row['object_key'],previous['object_key'])
   self.assertIn('/v'+str(row['version'])+'-'+row['sha256'],row['object_key'])
if __name__=='__main__':unittest.main()
