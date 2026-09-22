import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile


MODULE_PATH = Path(__file__).parents[1] / "tools/package_optional_3d_bundle_prototype.py"
SPEC = importlib.util.spec_from_file_location("bundle_prototype", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class BundlePrototypePackagingTests(unittest.TestCase):
    def test_builds_three_independent_normal_shiny_bundles(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            entries, models, registry = [], {}, {"schema": 1, "models": {}}
            for species in MODULE.SPECIES:
                for variant in ("normal", "shiny"):
                    key = species + ("@shiny" if variant == "shiny" else "")
                    path = root / f"{key}.scn"
                    path.write_text(f"[gd_scene format=3]\n[node name=\"{key}\" type=\"Node3D\"]\n")
                    digest = hashlib.sha256(path.read_bytes()).hexdigest()
                    entries.append({"species": species, "variant": variant, "runtime_path": str(path),
                                    "runtime_schema": 1, "runtime_sha256": digest})
                    registry["models"][key] = {"sha256": digest, "profile": species}
                    models[key] = digest
            catalog = root / "catalog.json"
            catalog.write_text(json.dumps(entries))
            registry_path = root / "registry.json"
            registry_path.write_text(json.dumps(registry))
            output = root / "output"
            index = MODULE.build(catalog, output, registry_path=registry_path)
            self.assertEqual(len(index["assets"]), 3)
            self.assertEqual({asset["species_id"] for asset in index["assets"]}, set(MODULE.SPECIES))
            for asset in index["assets"]:
                archive = output / Path(asset["object_key"]).name
                self.assertEqual(hashlib.sha256(archive.read_bytes()).hexdigest(), asset["sha256"])
                self.assertEqual(archive.stat().st_size, asset["size_bytes"])
                with zipfile.ZipFile(archive) as bundle:
                    self.assertEqual(set(bundle.namelist()), {"bundle.json", "models/normal.scn", "models/shiny.scn"})
                    manifest = json.loads(bundle.read("bundle.json"))
                    self.assertEqual(manifest["asset_id"], asset["asset_id"])
                    self.assertEqual({item["variant"] for item in manifest["appearances"]}, {"normal", "shiny"})
            self.assertEqual(json.loads((output / "asset-index.json").read_text()), index)
            with self.assertRaises(ValueError):
                MODULE.build(catalog, output, registry_path=registry_path)

    def test_rejects_unapproved_or_missing_appearance(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "model.scn"
            path.write_text("changed")
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            catalog = root / "catalog.json"
            catalog.write_text(json.dumps([
                {"species": "dragonite", "variant": "normal", "runtime_path": str(path), "runtime_sha256": digest}
            ]))
            registry = root / "registry.json"
            registry.write_text(json.dumps({"models": {"dragonite": {"sha256": "0" * 64}}}))
            with self.assertRaisesRegex(ValueError, "missing approved prototype appearance|unapproved"):
                MODULE.build(catalog, root / "output", registry_path=registry)


if __name__ == "__main__":
    unittest.main()
