import hashlib
from pathlib import Path
import tempfile
import unittest

from PIL import Image
from check_new_pair_geometry_pixels import check
from probe_v13_compression import encoded, write


class ExactWholeFrameTests(unittest.TestCase):
    def fixture(self, root, candidate_mode):
        source = Image.new('RGBA', (512, 512), (1, 2, 3, 255))
        repeat = source.copy()
        repeat.putpixel((0, 0), (2, 2, 3, 255))
        repeat.putpixel((1, 0), (1, 3, 3, 255))
        candidate = source.copy() if candidate_mode == 'source' else repeat.copy()
        if candidate_mode == 'mixed':
            candidate.putpixel((1, 0), source.getpixel((1, 0)))
        input_path = root / 'input.json'
        write(input_path, {'models': [{'identity': 'model', 'source_sha256': 'source', 'candidate_sha256': 'candidate'}]})
        row = {'identity': 'model', 'source_sha256': 'source', 'candidate_sha256': 'candidate'}
        for name, image in [('source', source), ('repeat_source', repeat), ('candidate', candidate)]:
            paths = []
            frames = {}
            directory = root / name
            directory.mkdir()
            for index in range(10):
                key = f'frame-{index}'
                path = directory / (key+'.png')
                image.save(path)
                paths.append(str(path))
                frames[key] = hashlib.sha256(image.tobytes()).hexdigest()
            row[name] = {'camera_size': 5.5, 'response_schema': 1, 'frames': frames, 'paths': paths}
        report = {'complete': True, 'input_sha256': hashlib.sha256(input_path.read_bytes()).hexdigest(),
                  'records': [row], 'renderer': 'gl_compatibility', 'device': 'fixture',
                  'render_clock_implementation_sha256': 'clock'}
        write(root / 'report.json', report)
        return input_path, report

    def test_whole_first_or_repeat_frame_is_accepted(self):
        for mode in ['source', 'repeat']:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                inputs, _ = self.fixture(root, mode)
                result = check(root, inputs)
                self.assertEqual(result['candidate_frames'], 10)
                self.assertEqual(result['source_control_frames_differing'], 10)

    def test_pixelwise_mixture_of_controls_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            inputs, _ = self.fixture(root, 'mixed')
            with self.assertRaisesRegex(ValueError, 'neither complete source frame'):
                check(root, inputs)

    def test_tampered_image_hash_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            inputs, report = self.fixture(root, 'source')
            report['records'][0]['candidate']['frames']['frame-0'] = 'wrong'
            write(root / 'report.json', report)
            with self.assertRaisesRegex(ValueError, 'PNG hash mismatch'):
                check(root, inputs)

    def test_incomplete_frame_set_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            inputs, report = self.fixture(root, 'source')
            report['records'][0]['candidate']['frames'].pop('frame-0')
            write(root / 'report.json', report)
            with self.assertRaisesRegex(ValueError, 'Incomplete frame set'):
                check(root, inputs)


if __name__ == '__main__':
    unittest.main()
