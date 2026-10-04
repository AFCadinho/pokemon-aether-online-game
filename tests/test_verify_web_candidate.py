import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from tools.verify_web_candidate import verify_active_build, verify_artifact, verify_source_run


class WebCandidateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.repo = Path(self.directory.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Release test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("commit", "--allow-empty", "-qm", "approved game")
        self.source = self.git("rev-parse", "HEAD")
        self.run = {"id": 42, "head_sha": self.source, "head_branch": "main",
                    "event": "workflow_dispatch", "status": "completed", "conclusion": "success",
                    "path": ".github/workflows/deploy-web-cloudflare.yml"}
        self.build_id = f"{self.source}-42-1"

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo, text=True, stderr=subprocess.DEVNULL).strip()

    def artifact(self, schema=2):
        root = self.repo / "candidate"
        pages, r2 = root / "pages-production", root / "r2"
        pages.mkdir(parents=True)
        r2.mkdir()
        config = {"buildId": self.build_id, "clientBuildId": self.build_id,
                  "releaseVersion": "0.4.0", "assetBaseUrl": "https://web-assets.pokeaether.com"}
        (pages / "web-release-config.json").write_text(json.dumps(config))
        (pages / "index.html").write_text(json.dumps(config, separators=(",", ":")))
        (pages / "index.js").write_text("tested loader")
        candidate = {"runId": "42", "sourceSha": self.source, "buildId": self.build_id,
                     "releaseVersion": "0.4.0", "previewClientBuildId": "previous-build"}
        if schema == 2:
            candidate.update(schemaVersion=2, pageFiles={path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                                                        for path in pages.iterdir()})
        (root / "candidate.json").write_text(json.dumps(candidate))
        (r2 / "web-release.json").write_text(json.dumps({"buildId": self.build_id, "releaseVersion": "0.4.0"}))
        (r2 / "manifest-web.json").write_text(json.dumps({"gameBuildId": self.build_id, "gameVersion": "0.4.0",
            "game": {"buildId": self.build_id, "version": "0.4.0", "url": "https://play.pokeaether.com"}}))
        return root

    def test_frozen_candidate_survives_new_publication_tooling_commit(self):
        self.git("commit", "--allow-empty", "-qm", "repair publisher")
        self.assertNotEqual(self.source, self.git("rev-parse", "HEAD"))
        self.assertEqual(verify_source_run(self.run, "42", self.repo), self.source)
        self.assertEqual(verify_artifact(self.artifact(), self.run, "42")["buildId"], self.build_id)

    def test_unapproved_side_branch_candidate_is_rejected(self):
        self.git("checkout", "-qb", "side")
        self.git("commit", "--allow-empty", "-qm", "side candidate")
        run = dict(self.run, head_sha=self.git("rev-parse", "HEAD"))
        self.git("checkout", "--detach", self.source)
        with self.assertRaisesRegex(ValueError, "not contained"):
            verify_source_run(run, "42", self.repo)

    def test_failed_wrong_branch_wrong_workflow_or_wrong_run_is_rejected(self):
        for key, value in (("conclusion", "failure"), ("status", "in_progress"), ("id", 43),
                           ("head_branch", "development"), ("event", "pull_request"),
                           ("path", ".github/workflows/publish-browser-candidate.yml")):
            with self.subTest(key=key), self.assertRaises(ValueError):
                verify_source_run(dict(self.run, **{key: value}), "42", self.repo)

    def test_artifact_from_different_successful_run_is_rejected(self):
        root = self.artifact()
        with self.assertRaisesRegex(ValueError, "verified source run"):
            verify_artifact(root, self.run, "43")

    def test_old_successful_candidate_artifacts_remain_supported(self):
        self.assertEqual(verify_artifact(self.artifact(schema=1), self.run, "42")["buildId"], self.build_id)

    def test_changed_missing_or_added_page_files_are_rejected(self):
        root = self.artifact()
        path = root / "pages-production/index.js"
        for change in ("changed", "missing", "added"):
            with self.subTest(change=change):
                path.write_text("tested loader")
                if change == "changed":
                    path.write_text("untested loader")
                elif change == "missing":
                    path.unlink()
                else:
                    (path.parent / "extra.js").write_text("extra")
                with self.assertRaisesRegex(ValueError, "page files changed"):
                    verify_artifact(root, self.run, "42")

    def test_false_source_in_artifact_is_rejected(self):
        root = self.artifact()
        path = root / "candidate.json"
        candidate = json.loads(path.read_text())
        candidate["sourceSha"] = "a" * 40
        path.write_text(json.dumps(candidate))
        with self.assertRaisesRegex(ValueError, "verified run"):
            verify_artifact(root, self.run, "42")

    def test_retry_after_manifest_publication_is_allowed(self):
        candidate = {"buildId": self.build_id, "previewClientBuildId": "previous-build"}
        verify_active_build(candidate, "previous-build", "previous-build")
        verify_active_build(candidate, self.build_id, self.build_id)

    def test_other_active_release_or_disagreement_still_blocks_publication(self):
        candidate = {"buildId": self.build_id, "previewClientBuildId": "previous-build"}
        for manifest, api in (("unrelated", "unrelated"), (self.build_id, "previous-build"), ("", "")):
            with self.subTest(manifest=manifest, api=api), self.assertRaises(ValueError):
                verify_active_build(candidate, manifest, api)


if __name__ == "__main__":
    unittest.main()
