import copy
from pathlib import Path
import tempfile
import unittest

import audit_cross_form_resources as audit


class CrossFormAuditTests(unittest.TestCase):
    def row(self, identity, path="textures/" + "a" * 64 + ".res", size=100, sha="b" * 64):
        return {"asset_id": identity, "resources": [{"path": path, "category": path.split("/")[0],
                "signature": Path(path).stem, "bytes": size, "sha256": sha}]}

    def test_different_bytes_are_only_semantic_candidates(self):
        rows = [self.row("one", sha="a" * 64), self.row("two", size=110)]
        self.assertEqual(audit.groups(rows, lambda r: (r["sha256"], r["bytes"])), [])
        group, = audit.groups(rows, lambda r: r["path"])
        self.assertEqual(group["member_byte_opportunity"], 110)

    def test_three_pairs_retain_one_complete_copy(self):
        rows = [self.row("one", size=100), self.row("two", size=90), self.row("three", size=120)]
        group, = audit.groups(rows, lambda r: r["path"])
        self.assertEqual(group["member_byte_opportunity"], 220)

    def test_within_pair_duplicates_do_not_count_as_cross_pair(self):
        row = self.row("one")
        row["resources"] *= 2
        self.assertEqual(audit.groups([row], lambda r: r["path"]), [])
        with self.assertRaisesRegex(ValueError, "inside a pair"):
            audit.groups([row, self.row("two")], lambda r: r["path"])

    def test_changed_approved_archive_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "model.pck"
            source.write_bytes(b"wrong")
            with self.assertRaisesRegex(ValueError, "Source pin mismatch"):
                audit.inventory({"size_bytes": 5, "sha256": "a" * 64}, source)

    def fixture(self, output):
        job = {"jobs": []}
        audit.write(output / "engine-job.json", job)
        group, = audit.groups([self.row("pokemon_3d:one:base"), self.row("pokemon_3d:two:base", size=110)], lambda r: r["path"])
        report = {"engine_job_sha256": audit.sha(output / "engine-job.json"),
                  "implementation_sha256": audit.sha(audit.__file__),
                  "engine_script_sha256": audit.sha(audit.ROOT / "tools/sprite_factory/cross_form_resource_check.gd"),
                  "nominated_groups": [group], "inventory": [self.row("pokemon_3d:one:base"), self.row("pokemon_3d:two:base", size=110)]}
        proofs = [{"asset_id": r["asset_id"], "path": r["path"], "signature": r["signature"], "sha256": r["sha256"],
                   "local_to_scene": False, "dependencies": 0, "sensitive_tracks": 0} for r in group["occurrences"]]
        engine = {"complete": True, "errors": [], "job_sha256": report["engine_job_sha256"],
                  "script_sha256": report["engine_script_sha256"], "resources": proofs,
                  "godot": "test", "embedded_pairs": 0, "embedded_resources": []}
        audit.write(output / "inventory.json", report)
        audit.write(output / "engine-report.json", engine)
        return engine

    def test_partial_or_unsafe_engine_proof_cannot_finalize(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            original = self.fixture(output)
            cases = [("missing", lambda e: e["resources"].pop()),
                     ("signature", lambda e: e["resources"][0].update(signature="f" * 64)),
                     ("dependency", lambda e: e["resources"][0].update(dependencies=1)),
                     ("local", lambda e: e["resources"][0].update(local_to_scene=True)),
                     ("animation", lambda e: e["resources"][0].update(sensitive_tracks=1)),
                     ("error", lambda e: e.update(errors=["load failed"])),
                     ("duplicate", lambda e: e["resources"].__setitem__(1, copy.deepcopy(e["resources"][0])))]
            for name, mutate in cases:
                with self.subTest(name=name):
                    engine = copy.deepcopy(original)
                    mutate(engine)
                    audit.write(output / "engine-report.json", engine)
                    with self.assertRaises(ValueError):
                        audit.finalize(output)
                    self.assertFalse((output / "report.json").exists())

    def test_embedded_matches_are_separate_from_compressed_saving(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            engine = self.fixture(output)
            engine["embedded_resources"] = [{"asset_id": "pokemon_3d:three:base", "category": "textures",
                                              "signature": "a" * 64, "eligible": True, "image_bytes": 1000000}]
            audit.write(output / "engine-report.json", engine)
            audit.finalize(output)
            report = audit.read(output / "report.json")
            self.assertEqual(report["candidate_member_bytes"], 110)
            self.assertEqual(len(report["embedded_cross_pair_matches"]), 1)
            self.assertEqual(len(report["embedded_cross_pair_matches"][0]["asset_ids"]), 3)


if __name__ == "__main__":
    unittest.main()
