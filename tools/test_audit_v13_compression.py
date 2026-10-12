import copy
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from audit_v13_compression import CONFIG, measure_one, validate_saved
from probe_v13_compression import Zstd, digest, encode, encoded, pack_pck, read, write


class FullCompressionAuditTests(unittest.TestCase):
    def fixture(self, directory, kind):
        members = {'models/'+v+'.scn': encode((v+' native resource').encode()*3000,
                   CONFIG[0],9,Zstd()) for v in ('normal','shiny')}
        appearances = [{'variant':v,'runtime_path':'models/'+v+'.scn',
                        'runtime_identity':'fixture:'+v,'bytes':len(members['models/'+v+'.scn']),
                        'runtime_sha256':digest(members['models/'+v+'.scn'])} for v in ('normal','shiny')]
        manifest = {'schema':1,'resource_root':'res://pokemon-pairs/'+'a'*64,
                    'appearances':appearances,
                    'files':[{'path':n,'bytes':len(b),'sha256':digest(b)} for n,b in members.items()]}
        members['bundle.json'] = encoded(manifest)
        asset = {'asset_id':'pokemon_3d:fixture:base','object_key':'fixture.'+kind,
                 'appearances':copy.deepcopy(appearances)}
        if kind == 'pck':
            asset['pair_manifest'] = manifest
            data = pack_pck(members,manifest['resource_root'])
        else:
            for a in asset['appearances']:
                del a['bytes']; del a['runtime_path']
            buffer = io.BytesIO()
            with zipfile.ZipFile(buffer,'w') as archive:
                for name,payload in members.items(): archive.writestr(name,payload)
            data = buffer.getvalue()
        asset.update(sha256=digest(data),size_bytes=len(data))
        source = directory/('source.'+kind);source.write_bytes(data)
        return asset,source

    def test_persisted_roundtrip_and_resume_for_both_containers(self):
        for kind in ('pck','zip'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as temp:
                directory = Path(temp);asset,source = self.fixture(directory,kind)
                row,proof,reused = measure_one(asset,source,directory/'result')
                self.assertFalse(reused)
                self.assertTrue(proof['persisted_streams_byte_exact'])
                self.assertEqual(proof['native_members'],2)
                self.assertEqual(proof['selected_bytes'],min(asset['size_bytes'],proof['candidate_bytes']))
                with patch('audit_v13_compression.measure_pair',side_effect=AssertionError('Unexpected recompression')):
                    self.assertEqual(measure_one(asset,source,directory/'result'),(row,proof,True))

    def test_corrupt_candidate_rejected_even_on_resume(self):
        with tempfile.TemporaryDirectory() as temp:
            directory=Path(temp);asset,source=self.fixture(directory,'pck')
            row,_,_=measure_one(asset,source,directory/'result')
            candidate=Path(row['configurations'][0]['path']);candidate.write_bytes(candidate.read_bytes()[:-1])
            with self.assertRaisesRegex(ValueError,'Source pin mismatch'):
                measure_one(asset,source,directory/'result')

    def test_changed_decoded_evidence_and_configuration_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            directory=Path(temp);asset,source=self.fixture(directory,'zip')
            row,_,_=measure_one(asset,source,directory/'result')
            bad=copy.deepcopy(row);bad['members'][0]['raw_sha256']='0'*64
            with self.assertRaisesRegex(ValueError,'Decoded evidence differs'): validate_saved(asset,source,bad)
            bad=copy.deepcopy(row);bad['configurations'][0]['level']=9
            with self.assertRaisesRegex(ValueError,'Checkpoint codec differs'): validate_saved(asset,source,bad)

    def test_changed_asset_metadata_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            directory=Path(temp);asset,source=self.fixture(directory,'pck')
            row,_,_=measure_one(asset,source,directory/'result')
            path=row['configurations'][0]['asset_path'];bad=read(path)
            bad['asset_id']='different';write(path,bad)
            with self.assertRaisesRegex(ValueError,'Candidate changed asset metadata'):
                validate_saved(asset,source,row)


if __name__ == '__main__': unittest.main()
