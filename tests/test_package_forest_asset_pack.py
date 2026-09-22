import json
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock
from zipfile import ZipFile

from tools.package_forest_asset_pack import archive_bytes, upload_archive
from tools.package_launcher_release import _build_external_asset_pack

ROOT = Path(__file__).resolve().parents[1]


class ForestAssetPackTests(unittest.TestCase):
    def test_archive_has_fixed_required_layout_and_relative_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "forest.pck"
            source.write_bytes(b"fixture-pck")
            version, target, size, digest = archive_bytes(source, Path(directory) / "output")
            self.assertTrue(version.startswith("battle-environment-forest-"))
            self.assertEqual(size, target.stat().st_size)
            self.assertEqual(len(digest), 64)
            with ZipFile(target) as archive:
                self.assertEqual(sorted(archive.namelist()), [
                    "forest-runtime/forest.json", "forest-runtime/forest.pck"])
                manifest = json.loads(archive.read("forest-runtime/forest.json"))
                self.assertEqual(manifest, {"schema": 1, "pack": "forest.pck"})
                self.assertEqual(archive.read("forest-runtime/forest.pck"), b"fixture-pck")

    def test_desktop_release_registers_exact_pack_as_required(self):
        workflow = (ROOT / ".github/workflows/deploy-desktop-r2.yml").read_text()
        values = {}
        for name in ("FOREST_ASSET_VERSION", "FOREST_ASSET_SIZE", "FOREST_ASSET_SHA256"):
            match = re.search(rf"^  {name}: (.+)$", workflow, re.MULTILINE)
            self.assertIsNotNone(match)
            values[name] = match.group(1).strip()
        pack = _build_external_asset_pack(
            "battle-environment-forest:{FOREST_ASSET_VERSION}:{FOREST_ASSET_VERSION}.zip:"
            "{FOREST_ASSET_SIZE}:{FOREST_ASSET_SHA256}".format(**values),
            "https://updates.pokeaether.com", "assets")
        self.assertEqual(pack["id"], "battle-environment-forest")
        self.assertNotIn("optional", pack)
        self.assertEqual(pack["sha256"], values["FOREST_ASSET_SHA256"])

    def test_upload_uses_the_immutable_assets_key(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "battle-environment-forest-hash.zip"
            target.write_bytes(b"archive")
            load_config = Mock(return_value="config")
            upload_file = Mock()
            upload_archive(target, load_config, upload_file)
            load_config.assert_called_once_with()
            upload_file.assert_called_once_with(
                "config", target, "assets/battle-environment-forest-hash.zip")


if __name__ == "__main__":
    unittest.main()
