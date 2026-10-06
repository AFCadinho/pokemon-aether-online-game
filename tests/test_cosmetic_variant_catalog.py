"""Exercise authoring a future item using the generic catalog contract."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("cosmetic_generator", Path(__file__).resolve().parents[1] / "tools/generate_cosmetic_variants.py")
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class CosmeticVariantCatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.items_dir = Path(self.temp.name)
        self.items = {
            "future-uniform": {
                "category": "cosmetics", "genders": ["male", "female"],
                "data": {"use_action": "unlock_appearance", "appearance_unlocks": [{
                    "slot": "top", "appearance_id": "Future_Uniform", "genders": ["male", "female"],
                    "render_variants": {"male": "TeamRocket_Shirt", "female": "TeamRocketFemale_Shirt"},
                }]},
            },
            "future-outfit": {
                "category": "cosmetics", "genders": ["male", "female"],
                "data": {"use_action": "open_item_bundle", "bundle_contents": [{"item_id": "future-uniform", "quantity": 1}]},
            },
        }

    def tearDown(self):
        self.temp.cleanup()

    def generate(self):
        (self.items_dir / "future.json").write_text(json.dumps(self.items))
        return generator.build_catalog(self.items_dir)

    def test_future_names_get_component_and_bundle_icons_without_client_cases(self):
        catalog = self.generate()
        part = catalog["parts"]["top"]["Future_Uniform"]
        self.assertEqual(part["item_id"], "future-uniform")
        self.assertEqual(part["render_variants"]["female"], "TeamRocketFemale_Shirt")
        self.assertTrue(catalog["items"]["future-outfit"]["bundle"])
        self.assertEqual(catalog["items"]["future-uniform"]["layers"][0]["id"], "Future_Uniform")

    def test_missing_gender_variant_fails_before_publishing_a_catalog(self):
        del self.items["future-uniform"]["data"]["appearance_unlocks"][0]["render_variants"]["female"]
        with self.assertRaisesRegex(ValueError, "cover exactly"):
            self.generate()

    def test_missing_authored_art_is_rejected(self):
        self.items["future-uniform"]["data"]["appearance_unlocks"][0]["render_variants"]["female"] = "Missing_Uniform"
        with self.assertRaisesRegex(ValueError, "missing female overworld art"):
            self.generate()

    def test_overworld_only_collection_requires_explicit_battle_fallback(self):
        unlock = self.items["future-uniform"]["data"]["appearance_unlocks"][0]
        unlock["render_variants"] = {"male": "Future_Shirt", "female": "Future_Shirt"}
        # Isolated authoring fixture: adding real battle art must not invalidate this test.
        root = self.items_dir / "art"
        for gender in ["male", "female"]:
            target = root / f"assets/player/{gender}/top/Future_Shirt.png"
            target.parent.mkdir(parents=True)
            target.touch()
        manifest = root / "assets/battles/trainers/player/manifest.json"
        manifest.parent.mkdir(parents=True)
        manifest.write_text(json.dumps({"genders": {gender: {"categories": {}} for gender in ["male", "female"]}}))
        with patch.object(generator, "ROOT", root):
            with self.assertRaisesRegex(ValueError, "missing male battle art"):
                self.generate()
            unlock["battle_rendering"] = "fallback"
            self.assertIn("Future_Uniform", self.generate()["parts"]["top"])
            unlock["render_variants"]["female"] = "Missing_Uniform"
            with self.assertRaisesRegex(ValueError, "missing female overworld art"):
                self.generate()

    def test_invalid_battle_policy_is_rejected(self):
        self.items["future-uniform"]["data"]["appearance_unlocks"][0]["battle_rendering"] = "ignore"
        with self.assertRaisesRegex(ValueError, "invalid battle_rendering"):
            self.generate()

    def test_ambiguous_sprite_cannot_represent_two_different_owned_items(self):
        self.items["duplicate-uniform"] = json.loads(json.dumps(self.items["future-uniform"]))
        self.items["duplicate-uniform"]["data"]["appearance_unlocks"][0]["appearance_id"] = "Other_Uniform"
        with self.assertRaisesRegex(ValueError, "Ambiguous sprite"):
            self.generate()


if __name__ == "__main__":
    unittest.main()
