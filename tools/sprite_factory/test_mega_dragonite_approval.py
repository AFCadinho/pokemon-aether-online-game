import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from tools.package_mega_dragonite_bundle import combined_index, read_base_index


ROOT = Path(__file__).resolve().parents[2]


class MegaDragoniteApprovalTests(unittest.TestCase):
    def test_bundle_index_combines_with_required_base(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            base_path = root / "base.json"
            base_path.write_text(json.dumps({
                "schema": 1, "kind": "pokeaether-optional-asset-index",
                "runtime_contract": {"pokemon_3d": 1, "godot": "4.6"},
                "catalog_revision": "base", "assets": [{"asset_id": "pokemon_3d:dragonite:base"}],
            }))
            base = read_base_index(base_path)
            mega = {"catalog_revision": "mega-v1", "assets": [{"asset_id": "pokemon_3d:dragonite:mega"}]}
            result = json.loads(combined_index(base, mega, root).read_text())
            self.assertEqual(result["catalog_revision"], "mega-v1")
            self.assertEqual([item["asset_id"] for item in result["assets"]],
                             ["pokemon_3d:dragonite:base", "pokemon_3d:dragonite:mega"])

    def test_pinned_variants_and_motion_are_shared_with_launcher(self):
        game_path = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
        launcher_path = ROOT / "launcher/data/reviewed_model_catalog.json"
        receipt_path = ROOT / "tools/sprite_factory/mega_dragonite_approval.json"
        self.assertEqual(game_path.read_bytes(), launcher_path.read_bytes())
        registry = json.loads(game_path.read_text())
        receipt = json.loads(receipt_path.read_text())
        self.assertEqual(
            registry["mega_dragonite_approval_sha256"],
            hashlib.sha256(receipt_path.read_bytes()).hexdigest(),
        )
        self.assertTrue(receipt["visual_approved_by_player"])
        self.assertTrue(receipt["normal_and_shiny_battle_event_passed"])
        self.assertTrue(receipt["sleep_eye_check_passed"])
        self.assertTrue(receipt["local_installed_battle_normal_and_shiny_passed"])
        self.assertFalse(receipt["release_selected"] or receipt["uploaded"])
        self.assertEqual(receipt["bundle_v1_bytes"], 67184462)
        self.assertEqual(receipt["bundle_dependencies"], ["pokemon_3d:dragonite:base"])
        for variant in ("normal", "shiny"):
            identity = "dragonite-mega" + ("@shiny" if variant == "shiny" else "")
            model = registry["models"][identity]
            self.assertEqual(model["profile"], "dragonite-mega")
            self.assertEqual(model["sha256"], receipt["variants"][variant]["runtime_sha256"])
            self.assertEqual(model["glb_sha256"], receipt["variants"][variant]["glb_sha256"])
        profile = registry["profiles"]["dragonite-mega"]
        self.assertEqual(profile["action_timing"]["mega_appeal"]["frames"], 181)
        self.assertEqual(len(profile["motion"]["clips"]["mega_appeal"]["offsets"]), 182)
        self.assertGreater(profile["motion"]["clips"]["mega_appeal"]["offsets"][0], 1.45)
        self.assertEqual(profile["motion"]["sha256"], receipt["variants"]["normal"]["runtime_sha256"])
        self.assertEqual(profile["grounding"]["sha256"], receipt["variants"]["normal"]["runtime_sha256"])


if __name__ == "__main__":
    unittest.main()
