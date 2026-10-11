#!/usr/bin/env python3
"""Focused limits on which objects the geometry staging cleanup may retire."""
import copy
import json
from pathlib import Path
import unittest

from retire_previous_shared_model_staging import ROOT, candidates


class RetirementSelectionTest(unittest.TestCase):
    def setUp(self):
        self.old = json.loads((ROOT / 'release/shared_model_collection_r2_receipt.json').read_bytes())
        wire = json.loads((ROOT / 'data/model_pair_geometry.json').read_bytes())
        selected = {a['asset_id']: a for a in
                    json.loads((ROOT / 'data/model_pair_geometry_catalog.json').read_bytes())['assets']}
        former = {a['asset_id']: a for a in self.old['bundles']}
        self.new = {'bundles': [selected[a['asset_id']] if a['asset_id'] in selected
                                else former[a['asset_id']] for a in wire['assets']],
                    'content_index': {'object_key': 'optional-assets/pokemon_3d/index/pilot-'
                                      + wire['geometry_build_sha256'] + '.json'}}

    def test_exact_old_staging_subset(self):
        doomed = candidates(self.old, self.new)
        self.assertEqual(len(doomed), 969)
        self.assertEqual(sum(a['size_bytes'] for a in doomed if a['object_key'].endswith('.pck')),
                         8_781_276_000)
        self.assertEqual({a['object_key'] for a in doomed}
                         & {a['object_key'] for a in self.new['bundles']}, set())
        self.assertEqual(sum(a['object_key'].endswith('.pck') for a in doomed), 968)
        self.assertEqual(sum(a['object_key'].endswith('.json') for a in doomed), 1)

    def test_unowned_or_same_index_refused(self):
        bad = copy.deepcopy(self.old)
        old_keys = {a['object_key'] for a in self.new['bundles']}
        next(a for a in bad['bundles'] if a['object_key'] not in old_keys)['uploaded'] = False
        with self.assertRaises(AssertionError):
            candidates(bad, self.new)
        bad = copy.deepcopy(self.new)
        bad['content_index']['object_key'] = self.old['content_index']['object_key']
        with self.assertRaises(AssertionError):
            candidates(self.old, bad)


if __name__ == '__main__':
    unittest.main()
