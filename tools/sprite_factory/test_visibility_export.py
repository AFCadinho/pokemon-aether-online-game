import unittest
from unittest.mock import patch
from pathlib import Path
import hashlib
import tempfile

from visibility_export import keys, prepare


def track(kind='fixed_bool', **extra):
    return dict(target='body_mesh_shape', encoding=kind, time_raw=0, value_raw=0,
                fixed_value=True, frames=extra.get('frames', []),
                packed_bytes=extra.get('packed_bytes', []))


class VisibilityExportTests(unittest.TestCase):
    def test_fixed(self):
        self.assertEqual(keys(track(), 61, 60), [[0, True]])

    def test_lsb_first_at_source_frames(self):
        for kind in ['framed8_bool', 'framed16_bool']:
            self.assertEqual(keys(track(kind, frames=[0,28,125], packed_bytes=[5]),139,60),
                             [[0,True],[28/60,False],[125/60,True]])

    def test_multiple_bytes(self):
        result = keys(track('framed16_bool', frames=list(range(0,900,100)),
                            packed_bytes=[0b10101010,1]), 901, 60)
        self.assertEqual([v for _,v in result], [False,True]*4+[True])

    def test_dynamic_is_not_guessed(self):
        with self.assertRaisesRegex(ValueError,'dynamic visibility clock'):
            keys(track('dynamic_bool',packed_bytes=[255,0]),121,60)

    def test_invalid_framed_payloads(self):
        for frames, data in [([1],[1]),([0,2,1],[5]),([0,61],[1]),([0],[1,0]),([0,1],[255])]:
            with self.assertRaises(ValueError):
                keys(track('framed8_bool',frames=frames,packed_bytes=data),61,60)

    def test_unknown_clock_metadata(self):
        t=track();t['time_raw']=1
        with self.assertRaisesRegex(ValueError,'metadata'):keys(t,61,60)

    def test_manifest_binding_and_failures(self):
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'native.tracm';p.write_bytes(b'fixture')
            intake={'motion_channels':{'idle':str(p)},'identity_evidence':{
                'source_sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest()}}}
            animations={'idle':{'source_action':'native','duration':1.,'loop':True}}
            gltf={'nodes':[{'name':'body_mesh','mesh':0}]}
            with patch('visibility_export.binding',return_value={'excluded_targets':{},'source_sha256':{}}), patch('visibility_export.inspect_tracm',return_value={'frames':61,'fps':60,'loop':True}), patch('visibility_export.inspect_visibility',return_value=[track()]):
                result=prepare(intake,animations,gltf,'a'*64)
                self.assertEqual(result['clips']['idle']['tracks'][0]['mesh'],'body_mesh')
                other=dict(track('dynamic_bool'),target='other_mesh_shape')
                with patch('visibility_export.binding',return_value={'excluded_targets':{'other_mesh_shape':{'resource_id':'other'}},'source_sha256':{}}), patch('visibility_export.inspect_visibility',return_value=[track(),other]):
                    filtered=prepare(intake,animations,gltf,'a'*64)
                    self.assertEqual(filtered['clips']['idle']['excluded_variant_targets'],['other_mesh_shape'])
                    self.assertEqual(len(filtered['clips']['idle']['tracks']),1)
                with patch('visibility_export.inspect_visibility',return_value=[track(),track()]):
                    with self.assertRaisesRegex(ValueError,'Duplicate visibility source'):
                        prepare(intake,animations,gltf,'a'*64)
                for bad in [{'nodes':[{'name':'different','mesh':0}]},
                            {'nodes':gltf['nodes']*2},
                            {'nodes':gltf['nodes']+[{'name':'extra','mesh':1}]}]:
                    with self.assertRaises(ValueError):prepare(intake,animations,bad,'a'*64)
                with self.assertRaisesRegex(ValueError,'coverage'):
                    prepare(intake,dict(animations,sleep=animations['idle']),gltf,'a'*64)
                animations['idle']['duration']=2
                with self.assertRaisesRegex(ValueError,'clocks'):prepare(intake,animations,gltf,'a'*64)
                animations['idle']['duration']=1
                animations['idle']['source_action']='wrong'
                with self.assertRaisesRegex(ValueError,'source actions'):prepare(intake,animations,gltf,'a'*64)
                p.write_bytes(b'changed')
                with self.assertRaisesRegex(ValueError,'hash'):prepare(intake,animations,gltf,'a'*64)


if __name__=='__main__':unittest.main()
