import tempfile
import unittest
from unittest.mock import patch
import resume_full_texture_audit as resume
import test_strict_webp_texture_storage as fixtures


class ContentCacheProofTest(unittest.TestCase):
    def setUp(self):
        resume.cache.clear()
        resume.hits = 0

    def test_identical_png_reuses_only_the_encoder_not_the_source_proof(self):
        with tempfile.TemporaryDirectory() as directory:
            row,path = fixtures.StrictWebPTests().fixture(directory)
            first = resume.cached_encode(row,path)
            with patch.object(resume, 'original_encode', side_effect=AssertionError('Cache was not used')):
                second = resume.cached_encode(row,path)
            self.assertEqual(first, second)
            self.assertEqual(resume.hits, 1)
            self.assertIsNot(first[1], second[1])

    def test_cached_result_cannot_override_current_pixel_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            row,path = fixtures.StrictWebPTests().fixture(directory)
            resume.cached_encode(row,path)
            row['codecs']['png']['mips'][1]['source_sha256'] = '0'*64
            with self.assertRaisesRegex(ValueError, 'Cached pixels differ'):
                resume.cached_encode(row,path)

    def test_cached_result_cannot_override_current_mip_dimensions(self):
        with tempfile.TemporaryDirectory() as directory:
            row,path = fixtures.StrictWebPTests().fixture(directory)
            resume.cached_encode(row,path)
            row['codecs']['png']['mips'][1]['width'] = 3
            with self.assertRaisesRegex(ValueError, 'Changed cached mip dimensions'):
                resume.cached_encode(row,path)


if __name__ == '__main__': unittest.main()
