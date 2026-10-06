import threading
import unittest
from unittest.mock import patch

from publish_approved_3d_index_v11 import publish_bundles


class PublicationTests(unittest.TestCase):
    def test_bounded_parallel_upload_preserves_verified_records(self):
        barrier = threading.Barrier(4)
        bundles = [{'asset_id': str(i)} for i in range(4)]
        paths = {str(i): 'archive-' + str(i) for i in range(4)}

        def publish(config, path, asset):
            self.assertEqual(path, paths[asset['asset_id']])
            barrier.wait(timeout=5)
            return {**asset, 'public_get_sha256_verified': True,
                    'public_head_size_verified': True}

        with patch('publish_approved_3d_index_v11.publish', side_effect=publish):
            rows = publish_bundles(None, paths, bundles)
        self.assertEqual([r['asset_id'] for r in rows], ['0', '1', '2', '3'])
        self.assertTrue(all(r['public_get_sha256_verified'] and
                            r['public_head_size_verified'] for r in rows))

    def test_failed_object_prevents_successful_collection_result(self):
        def publish(config, path, asset):
            if asset['asset_id'] == 'bad':
                raise ValueError('Public SHA-256 mismatch')
            return asset

        with patch('publish_approved_3d_index_v11.publish', side_effect=publish):
            with self.assertRaisesRegex(ValueError, 'SHA-256 mismatch'):
                publish_bundles(None, {'good': 'a', 'bad': 'b'},
                                [{'asset_id': 'good'}, {'asset_id': 'bad'}])


if __name__ == '__main__':
    unittest.main()
