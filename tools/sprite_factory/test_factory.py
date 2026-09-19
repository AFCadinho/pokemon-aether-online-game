import argparse
import copy
import json
import tempfile
import unittest
import io
from pathlib import Path
from PIL import Image, PngImagePlugin
import factory as f


class FactoryTests(unittest.TestCase):
    def setUp(self):
        self.cfg = f.read(f.HERE / 'manifests/rattata.json')

    def test_canonical_png_removes_only_metadata_and_keeps_pixels(self):
        im = Image.new('RGBA', (512,512), (120, 80, 40, 17))
        results = []
        for stamp in ('first run', 'second run'):
            meta = PngImagePlugin.PngInfo()
            meta.add_text('Date', stamp)
            meta.add_text('RenderTime', stamp)
            data = io.BytesIO()
            im.save(data, format='PNG', pnginfo=meta)
            canonical = f.canonical_png(data.getvalue())
            results.append(canonical)
            self.assertEqual(Image.open(io.BytesIO(canonical)).tobytes(), im.tobytes())
        self.assertEqual(results[0], results[1])
        broken = bytearray(results[0]); broken[20] ^= 1
        with self.assertRaisesRegex(ValueError, 'CRC'):
            f.canonical_png(bytes(broken))

    def test_baseline_and_variant_are_enforced(self):
        f.validate(self.cfg, 'normal')
        without_qc = copy.deepcopy(self.cfg)
        without_qc.pop('qc')
        with self.assertRaisesRegex(ValueError, 'quality-check settings'):
            f.validate(without_qc, 'normal')
        with self.assertRaisesRegex(ValueError, 'unavailable'):
            f.validate(self.cfg, 'shiny')
        self.cfg['render']['fps'] = 12
        with self.assertRaisesRegex(ValueError, 'baseline'):
            f.validate(self.cfg, 'normal')

    def test_native_60_fps_timing_is_supported_without_resampling(self):
        self.cfg['render']['fps'] = 60
        self.cfg['actions'] = {'idle': dict(action='source_idle', frames=[0, 1, 2],
                                            source_fps=60, loop=True, speed=1,
                                            review='needs_review')}
        f.validate(self.cfg, 'normal')
        self.cfg['actions']['idle']['frames'] = [0, 2, 4]
        with self.assertRaisesRegex(ValueError, 'timeline'):
            f.validate(self.cfg, 'normal')

    def test_finalize_retune_allows_only_runtime_presentation_changes(self):
        updated = copy.deepcopy(self.cfg)
        updated['presentation']['front']['position_offset'][1] += 20
        f.require_presentation_only_retune(self.cfg, updated)
        updated['render']['fps'] = 60
        with self.assertRaisesRegex(ValueError, 'only change presentation'):
            f.require_presentation_only_retune(self.cfg, updated)

    def test_explicit_neutral_bones_require_existing_unique_bone_names(self):
        self.cfg['actions']['idle']['neutral_bones'] = ['left_upper_eyelid']
        f.validate(self.cfg, 'normal')
        report = dict(source_sha256=self.cfg['source']['sha256'], blender=self.cfg['source']['blender'],
                      armatures=[self.cfg['rig']], armature_bones={self.cfg['rig']: ['left_upper_eyelid']},
                      warnings=[], images=[], actions=[dict(name=a['action'], range=[0, 200], slots=['slot'])
                                                      for a in self.cfg['actions'].values() if a])
        f.check_source(self.cfg, report)
        report['armature_bones'][self.cfg['rig']] = []
        with self.assertRaisesRegex(ValueError, 'Unknown neutral_bones'):
            f.check_source(self.cfg, report)
        self.cfg['actions']['idle']['neutral_bones'] *= 2
        with self.assertRaisesRegex(ValueError, 'Invalid neutral_bones'):
            f.validate(self.cfg, 'normal')

    def test_recovery_and_ambiguous_timing_rejected(self):
        self.cfg['actions']['faint_start']['action'] = 'down01_end'
        with self.assertRaisesRegex(ValueError, 'Recovery'):
            f.validate(self.cfg, 'normal')
        self.cfg['actions']['faint_start']['action'] = 'down01_start'
        self.cfg['actions']['idle']['source_fps'] = 60
        with self.assertRaisesRegex(ValueError, 'timeline'):
            f.validate(self.cfg, 'normal')

    def test_unknown_source_and_missing_actions_block_rendering(self):
        report = dict(source_sha256=self.cfg['source']['sha256'], blender=self.cfg['source']['blender'],
                      armatures=[self.cfg['rig']], warnings=['embedded_text_blocks'], images=[],
                      actions=[dict(name=a['action'], range=[0, max(a['frames'])], slots=['only-slot'])
                               for a in self.cfg['actions'].values() if a])
        # The same down action supplies start and last-frame hold.
        for action in report['actions']:
            action['range'] = [0, 200]
        f.check_source(self.cfg, report)
        report['warnings'].append('object_drivers')
        with self.assertRaisesRegex(ValueError, 'inspection review'):
            f.check_source(self.cfg, report)
        report['warnings'] = ['missing_texture:test']
        with self.assertRaisesRegex(ValueError, 'Missing'):
            f.check_source(self.cfg, report)
        report['warnings'] = []
        report['actions'] = []
        with self.assertRaisesRegex(ValueError, 'Missing action'):
            f.check_source(self.cfg, report)
        report['source_sha256'] = 'unknown'
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            f.check_source(self.cfg, report)

    def fixture(self, root, facial_warnings=()):
        cfg = copy.deepcopy(self.cfg)
        cfg['actions'] = {'idle': dict(action='idle', frames=[0, 1], source_fps=24, loop=True, speed=1, review='needs_review')}
        geometry = {}
        for view in ('front', 'back'):
            folder = root / 'masters' / view / 'idle'
            folder.mkdir(parents=True)
            # Include nonzero RGB under zero alpha, which must survive packaging.
            frame = Image.new('RGBA', (512, 512), (20, 40, 60, 0))
            for x in range(200, 250):
                for y in range(200, 300):
                    frame.putpixel((x, y), (100, 50, 0, 255))
            frame.save(folder / '0000.png'); frame.save(folder / '0001.png')
            geometry[view] = {'idle': [dict(outside=False), dict(outside=False)]}
        f.write(root / 'provenance.json', {'build_id': 'test-build'})
        qc = f.quality(root, cfg, {'geometry': geometry, 'facial_warnings': list(facial_warnings)})
        f.write(root / 'qc.json', qc)
        f.package(root, cfg, 'normal')
        return qc

    def test_facial_pose_warning_is_advisory(self):
        with tempfile.TemporaryDirectory() as temp:
            warning = 'front/idle:persistent_eyelid_pose:left_upper_eyelid'
            qc = self.fixture(Path(temp), facial_warnings=[warning])
            self.assertEqual(qc['errors'], [])
            self.assertIn(warning, qc['warnings'])

    def test_lossless_gate_and_tamper_detection(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            qc = self.fixture(root)
            self.assertTrue(any('duplicate_loop_end' in w for w in qc['warnings']))
            self.assertIn('alpha_weighted_luminance', qc['actions']['front/idle'])
            f.verify(root)
            args = argparse.Namespace(build=[str(root)], output=str(root/'catalog.json'), preview=False)
            with self.assertRaises(OSError):
                f.catalog(args)
            args.preview = True
            f.catalog(args)
            review = argparse.Namespace(build=str(root), status='approved', reviewer='test-human', note='fixture only', accept_warnings=False, actions=None)
            with self.assertRaisesRegex(ValueError, 'acknowledgement'):
                f.review(review)
            review.accept_warnings = True
            f.review(review)
            args.preview = False
            f.catalog(args)
            review.status, review.actions = 'rejected', 'front/idle'
            f.review(review)
            meta = f.read(root/'runtime/manifest.json')
            self.assertEqual(meta['views']['front']['idle']['status'], 'rejected')
            self.assertEqual(meta['views']['back']['idle']['status'], 'approved')
            f.catalog(args)
            with (root/'masters/front/idle/0000.png').open('ab') as stream:
                stream.write(b'tamper')
            with self.assertRaisesRegex(ValueError, 'Master altered'):
                f.verify(root)

    def test_clipping_and_empty_outputs_block_approval(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.fixture(root)
            # Test the quality checks independently using a fresh preview destination.
            cfg = copy.deepcopy(self.cfg)
            cfg['actions'] = {'idle': dict(action='idle', frames=[0,1], loop=True, speed=1, review='needs_review')}
            Image.new('RGBA', (512,512), (255,0,255,255)).save(root/'masters/front/idle/0000.png')
            Image.new('RGBA', (512,512)).save(root/'masters/front/idle/0001.png')
            other = root/'second'
            other.mkdir()
            (other/'masters').symlink_to(root/'masters', target_is_directory=True)
            geometry = {v: {'idle': [dict(outside=False)]*2} for v in ('front','back')}
            qc = f.quality(other, cfg, {'geometry':geometry})
            self.assertTrue(any(':clipping:' in e for e in qc['errors']))
            self.assertTrue(any(':empty:' in e for e in qc['errors']))


if __name__ == '__main__':
    unittest.main()
