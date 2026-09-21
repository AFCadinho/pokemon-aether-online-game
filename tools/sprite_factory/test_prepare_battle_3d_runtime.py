"""Integration test; run via slot-env with POKEAETHER_3D_STAGE_REPORT.

Uses actual approved GLBs, without modifying them or the selected catalog.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


@unittest.skipUnless(os.environ.get("POKEAETHER_3D_STAGE_REPORT"), "requires source GLB report")
class RuntimeConversionTests(unittest.TestCase):
    def test_conversion_and_publication_boundaries(self):
        source = Path(os.environ["POKEAETHER_3D_STAGE_REPORT"])
        original = source.read_bytes()
        entries = json.loads(original)
        project = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory(prefix="runtime-converter-") as temporary:
            base = Path(temporary)

            def run(data, target):
                report = base / "source.json"
                report.write_text(json.dumps(data))
                env = dict(os.environ, POKEAETHER_3D_STAGE_REPORT=str(report),
                           POKEAETHER_3D_RUNTIME_OUTPUT=str(target))
                return subprocess.run(["godot", "--headless", "--path", str(project),
                    "--script", "res://tools/sprite_factory/prepare_battle_3d_runtime.gd"],
                    env=env, capture_output=True, text=True, timeout=90)

            valid = json.loads(original)
            # Renaming is ONLY a fixture proving no species filter, not new art.
            valid[0]["species"] = "fixture-third-species"
            target = base / "valid"
            result = run(valid, target)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            manifest = target / "report.json"
            records = json.loads(manifest.read_text())
            self.assertEqual(len(records), len(valid))
            for record, entry in zip(records, valid):
                self.assertEqual(record["source_sha256"], entry["source_sha256"])
                self.assertEqual(record["glb_sha256"], hashlib.sha256(Path(entry["path"]).read_bytes()).hexdigest())
                self.assertEqual(record["runtime_sha256"], hashlib.sha256(Path(record["runtime_path"]).read_bytes()).hexdigest())
                self.assertEqual(record["action_timing"], entry["action_timing"])
                self.assertEqual(record["runtime_schema"], 1)
            before = manifest.read_bytes()
            result = run(valid, target)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(manifest.read_bytes(), before)
            invalid = json.loads(original)
            invalid[0]["action_timing"]["nonexistent_clip"] = dict(frames=60, speed=1, loop=False)
            failed_target = base / "missing-clip"
            result = run(invalid, failed_target)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("missing animation clip nonexistent_clip", result.stderr)
            self.assertFalse((failed_target / "report.json").exists())
            self.assertTrue((failed_target / "conversion-errors.json").exists())
            invalid[0]["species"] = "../unsafe"
            preflight_target = base / "preflight-rejected"
            self.assertNotEqual(run(invalid, preflight_target).returncode, 0)
            self.assertFalse(preflight_target.exists())
            self.assertEqual(source.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
