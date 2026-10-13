import copy
import json
import unittest
from unittest.mock import MagicMock, patch

from tools import verify_android_3d_assets as assets


class Android3DAssetsTests(unittest.TestCase):
    def setUp(self):
        self.release = json.loads(assets.RELEASE_PATH.read_text())
        self.catalog = json.loads(assets.CATALOG_PATH.read_text())
        self.index = json.loads((assets.ROOT / "data/approved_3d_bundles_v14_index.json").read_text())
        self.descriptor = json.loads((assets.ROOT / "data/android_3d_experiment.json").read_text())

    def test_current_experiment_covers_all_shared_and_zip_pairs(self):
        self.assertEqual(self.descriptor["model_release"], self.release["revision"])
        rows = assets.model_assets(self.index, self.release, self.catalog)
        self.assertEqual(len(rows), 1420)
        self.assertEqual(sum(row["object_key"].endswith(".pck") for row in rows), 1365)
        self.assertEqual(sum(row["size_bytes"] for row in rows), 8993498070)

    def test_missing_or_changed_reference_is_rejected(self):
        for catalog in [dict(self.catalog, assets=self.catalog["assets"][1:]), copy.deepcopy(self.catalog)]:
            if len(catalog["assets"]) == len(self.catalog["assets"]):
                catalog["assets"][0]["sha256"] = "0" * 64
            with self.assertRaisesRegex(ValueError, "approved reference"):
                assets.model_assets(self.index, self.release, catalog)

    def test_missing_and_duplicate_index_assets_are_rejected(self):
        for rows in [self.index["assets"][1:], self.index["assets"] + [self.index["assets"][0]]]:
            with self.assertRaises(ValueError):
                assets.model_assets(dict(self.index, assets=rows), self.release, self.catalog)

    def test_retired_object_and_changed_size_fail_even_with_valid_index(self):
        row = assets.model_assets(self.index, self.release, self.catalog)[0]
        with patch.object(assets, "urlopen", side_effect=OSError("404 retired object")):
            with self.assertRaises(OSError):
                assets.verify_model_asset(row)
        response = MagicMock()
        response.__enter__.return_value.headers = {"Content-Length": "1"}
        with patch.object(assets, "urlopen", return_value=response):
            with self.assertRaisesRegex(ValueError, "object size differs"):
                assets.verify_model_asset(row)

    def test_wrong_revision_or_changed_public_index_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "do not match"):
            assets.verify_public(dict(self.descriptor, model_release="approved-pokemon-3d-v11"), self.release, self.catalog)
        with patch.object(assets, "read_public", return_value=b"changed"):
            with self.assertRaisesRegex(ValueError, "immutable pin"):
                assets.verify_public(self.descriptor, self.release, self.catalog)

    def test_object_key_cannot_change_origin_or_escape_path(self):
        for key in ["/foo", "../foo", "https://example.com/x", ""]:
            with self.assertRaises(ValueError):
                assets.public_request(key)


if __name__ == "__main__":
    unittest.main()
