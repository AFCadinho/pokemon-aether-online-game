import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest

from probe_v13_compression import (CONFIGS, Zstd, catalog, checked_bytes, decode, digest,
                                   encode, encoded, pack_pck, select, unpack_pck, zip_manifest)


class CompressionProbeTests(unittest.TestCase):
    def fixture(self):
        data = encode(b'native fixture' * 1000, 262144, 9, Zstd())
        name = 'models/normal.scn'
        manifest = {'resource_root': 'res://pokemon-pairs/' + 'a'*64,
                    'files': [{'path':name, 'bytes':len(data), 'sha256':digest(data)}]}
        members = {name:data, 'bundle.json':encoded(manifest)}
        return members, {'pair_manifest':manifest}

    def test_exact_six_configuration_roundtrips(self):
        codec = Zstd()
        raw = bytes(range(256))*4096  # Exact 1 MiB block with trailing empty block.
        for block,level in CONFIGS:
            self.assertEqual(decode(encode(raw,block,level,codec),codec),raw)

    def test_pack_rewrite_preserves_all_member_bytes(self):
        members,asset = self.fixture()
        packed = pack_pck(members,asset['pair_manifest']['resource_root'])
        self.assertEqual(unpack_pck(packed,asset),(members,2))

    def test_pack_corruption_and_truncation_fail(self):
        members,asset = self.fixture()
        packed=pack_pck(members,asset['pair_manifest']['resource_root'])
        changed=bytearray(packed);changed[130]^=255
        for candidate in (packed[:-1],packed+b'extra',bytes(changed)):
            with self.assertRaises(ValueError):unpack_pck(candidate,asset)

    def test_untrusted_namespace_manifest_and_offsets_fail(self):
        members,asset=self.fixture()
        packed=pack_pck(members,asset['pair_manifest']['resource_root'])
        bad=copy.deepcopy(asset);bad['pair_manifest']['resource_root']='res://different'
        with self.assertRaises(ValueError):unpack_pck(packed,bad)
        bad=copy.deepcopy(asset);bad['pair_manifest']['files'][0]['sha256']='b'*64
        with self.assertRaises(ValueError):unpack_pck(packed,bad)
        data=bytearray(packed);struct.pack_into('<Q',data,32,len(data)+1)
        with self.assertRaises(ValueError):unpack_pck(bytes(data),asset)

    def test_source_pin_required(self):
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'pack';p.write_bytes(b'approved')
            pin={'size_bytes':8,'sha256':digest(b'approved')}
            self.assertEqual(checked_bytes(p,pin),b'approved')
            p.write_bytes(b'changed!')
            with self.assertRaises(ValueError):checked_bytes(p,pin)

    def test_zip_metadata_changes_only_byte_bindings(self):
        old={'schema':1,'appearances':[{'runtime_path':'models/normal.scn','variant':'normal',
            'bytes':3,'runtime_sha256':'old','runtime_identity':'example'}]}
        new=zip_manifest(old,{'models/normal.scn':b'new payload'})
        self.assertEqual(old['appearances'][0]['runtime_sha256'],'old')
        self.assertEqual(new['appearances'][0]['bytes'],11)
        self.assertEqual(new['appearances'][0]['runtime_identity'],'example')

    def test_current_sample_covers_all_three_formats_reproducibly(self):
        assets=catalog(); first=select(assets)
        self.assertEqual(first,select(list(reversed(assets))))
        self.assertEqual(len(first),20)
        self.assertEqual(sum(a['size_bytes'] for a in first),201852282)
        self.assertEqual(sum(a.get('pair_manifest',{}).get('schema')==2 for a in first),17)
        self.assertEqual(sum(a.get('pair_manifest',{}).get('schema')==1 for a in first),2)
        self.assertEqual(sum(a['object_key'].endswith('.zip') for a in first),1)


if __name__=='__main__':unittest.main()
