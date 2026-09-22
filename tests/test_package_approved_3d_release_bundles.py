from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.package_optional_3d_bundle_prototype import build
from tools.package_approved_3d_release_bundles import DEX, SPECIES


class Approved3DBundleReleaseTests(unittest.TestCase):
    def test_exact_seven_species_and_paired_appearances(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            entries, models = [], {}
            for species in SPECIES:
                for variant in ("normal", "shiny"):
                    identity = species if variant == "normal" else f"{species}@shiny"
                    path = root / f"{identity}.scn"
                    path.write_bytes(f"scene:{identity}".encode())
                    digest = hashlib.sha256(path.read_bytes()).hexdigest()
                    entries.append({
                        "species": species,
                        "variant": variant,
                        "runtime_path": str(path),
                        "runtime_sha256": digest,
                    })
                    models[identity] = {"sha256": digest}
            catalog = root / "catalog.json"
            registry = root / "registry.json"
            catalog.write_text(json.dumps(entries), encoding="utf-8")
            registry.write_text(json.dumps({"models": models}), encoding="utf-8")
            output = root / "release"
            index = build(
                catalog,
                output,
                registry_path=registry,
                species_set=SPECIES,
                dex=DEX,
                revision="approved-test",
            )
            self.assertEqual(len(index["assets"]), 7)
            self.assertEqual(
                {asset["asset_id"] for asset in index["assets"]},
                {f"pokemon_3d:{species}:base" for species in SPECIES},
            )
            self.assertTrue(all(len(asset["appearances"]) == 2 for asset in index["assets"]))
            self.assertEqual(len(list(output.glob("*.zip"))), 7)

    def test_unapproved_hash_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            catalog = root / "catalog.json"
            registry = root / "registry.json"
            catalog.write_text("[]", encoding="utf-8")
            registry.write_text(json.dumps({"models": {}}), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "missing approved"):
                build(
                    catalog,
                    root / "release",
                    registry_path=registry,
                    species_set=SPECIES,
                    dex=DEX,
                )


if __name__ == "__main__":
    unittest.main()
