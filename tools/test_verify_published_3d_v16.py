import copy
import unittest
from unittest.mock import patch

import verify_published_3d_v16 as verifier


class PublishedCollectionTests(unittest.TestCase):
    def test_retained_publication_matches_both_clients(self):
        self.assertEqual(len(verifier.verified_metadata()['bundles']), 1421)

    def reject_mutation(self, filename, mutate):
        original = verifier.load

        def altered(path):
            value = original(path)
            if path.name == filename:
                value = copy.deepcopy(value)
                mutate(value)
            return value

        with patch.object(verifier, 'load', altered), self.assertRaises(ValueError):
            verifier.verified_metadata()

    def test_rejects_unverified_model(self):
        self.reject_mutation('approved_3d_bundles_v16_r2_receipt.json',
                             lambda d: d['bundles'][0].update(public_get_sha256_verified=False))

    def test_rejects_changed_model_pin(self):
        self.reject_mutation('approved_3d_bundles_v16.json',
                             lambda d: d['bundles'][0].update(sha256='0' * 64))

    def test_rejects_changed_qualification(self):
        self.reject_mutation('approved_3d_v16_binding.json',
                             lambda d: d.update(runtime_qualification_sha256='0' * 64))

    def test_rejects_changed_client_descriptor(self):
        self.reject_mutation('approved_3d_release_v16.json',
                             lambda d: d['requiredAssetIds'].pop())

    def test_rejects_wrong_index(self):
        self.reject_mutation('approved_3d_bundles_v16_r2_receipt.json',
                             lambda d: d['content_index'].update(sha256='0' * 64))

    def test_rejects_changed_historical_binding(self):
        self.reject_mutation('approved_3d_bundles_v16_r2_receipt.json',
                             lambda d: d.update(binding_sha256='0' * 64))


if __name__ == '__main__':
    unittest.main()
