"""Check release job dependencies and executable commands, independent of UI labels."""
from copy import deepcopy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile
import threading
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]


def commands(job):
    return "\n".join(step.get("run", "") for step in job["steps"])


class BrowserReleaseWorkflowTests(unittest.TestCase):
    def setUp(self):
        workflows = ROOT / ".github/workflows"
        self.preview = yaml.safe_load((workflows / "deploy-web-cloudflare.yml").read_text())
        self.publisher = yaml.safe_load((workflows / "publish-browser-candidate.yml").read_text())
        self.cleanup = yaml.safe_load((workflows / "cleanup-browser-r2.yml").read_text())

    def assert_retry_contract(self, preview, publisher):
        build = preview["jobs"]["build"]
        deploy = preview["jobs"]["deploy"]
        self.assertEqual(deploy["needs"], "build")
        self.assertNotIn("--export", commands(deploy))
        self.assertNotIn("--headless", commands(deploy))
        saved = next(step for step in build["steps"] if step.get("uses", "").startswith("actions/upload-artifact@"))
        restored = next(step for step in deploy["steps"] if step.get("uses", "").startswith("actions/download-artifact@"))
        self.assertEqual(saved["with"]["name"], restored["with"]["name"])
        self.assertNotIn("run_attempt", saved["with"]["name"])
        self.assertTrue(saved["with"]["overwrite"])
        self.assertIn("--reuse-upload", commands(deploy))
        self.assertNotIn("cleanup", publisher["jobs"])
        for job in publisher["jobs"].values():
            self.assertNotIn("prune_r2_release_objects.py", commands(job))
        self.assertNotIn("prune_r2_release_objects.py", commands(publisher["jobs"]["publish"]))
        self.assertNotIn("environment", publisher["jobs"]["publish-manifest"])
        self.assertEqual(preview["concurrency"]["group"], publisher["concurrency"]["group"])
        self.assertEqual(publisher["jobs"]["publish"]["needs"], "preflight")
        self.assertNotIn("environment", publisher["jobs"]["preflight"])

    def test_failed_deployment_can_reuse_build_and_cleanup_cannot_block_activation(self):
        self.assert_retry_contract(self.preview, self.publisher)

    def test_weekly_cleanup_protects_current_release_and_serializes_publication(self):
        # PyYAML uses YAML 1.1, where the Actions key "on" parses as True.
        triggers = self.cleanup.get("on", self.cleanup.get(True))
        self.assertEqual(triggers["schedule"], [{"cron": "23 3 * * 0"}])
        self.assertFalse(triggers["workflow_dispatch"]["inputs"]["apply"]["default"])
        self.assertEqual(self.cleanup["concurrency"], self.publisher["concurrency"])
        job = self.cleanup["jobs"]["cleanup"]
        self.assertEqual(job["environment"], "web-production")
        self.assertNotIn("needs", job)
        self.assertNotIn("continue-on-error", job)
        source = commands(job)
        self.assertIn("https://updates.pokeaether.com/manifest-web.json", source)
        self.assertIn("--active-web-url https://play.pokeaether.com", source)
        self.assertIn("--scope web", source)
        self.assertIn("--retain-previous 1 --minimum-age-hours 24 --max-delete 20000", source)
        self.assertNotIn("download-artifact", str(job))

    def test_manual_cleanup_preview_cannot_delete_without_explicit_apply(self):
        command = next(step["run"] for step in self.cleanup["jobs"]["cleanup"]["steps"]
                       if "python3 -u tools/prune_r2_release_objects.py" in step.get("run", ""))
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            (work / "tools").mkdir()
            (work / "builds/browser-cleanup").mkdir(parents=True)
            (work / "tools/prune_r2_release_objects.py").write_text(
                "import sys\nprint('ARGS=' + repr(sys.argv[1:]))\n")
            for apply in ("false", "true"):
                result = subprocess.run(["bash", "-eo", "pipefail", "-c", command],
                                        cwd=work, env={**os.environ, "APPLY": apply},
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual("'--apply'" in result.stdout, apply == "true")
                self.assertIn("'--scope', 'web'", result.stdout)

    def test_changing_step_labels_does_not_break_release_contract(self):
        preview, publisher = deepcopy(self.preview), deepcopy(self.publisher)
        for workflow in (preview, publisher):
            for job in workflow["jobs"].values():
                for step in job["steps"]:
                    if "name" in step:
                        step["name"] = "A translated or renamed step"
        self.assert_retry_contract(preview, publisher)

    def test_source_checks_run_before_asset_downloads_and_godot(self):
        build = commands(self.preview["jobs"]["build"])
        check = build.index("tools/build_web_preview.py --check-only")
        self.assertLess(check, build.index("curl -fsSL -o godot.zip"))
        self.assertLess(check, build.index("--import"))
        self.assertLess(build.index("tests.test_package_web_release"), build.index("--import"))
        self.assertIn("node tests/web_preview_browser_smoke.cjs", build)
        self.assertEqual(build.count("unzip -oq /tmp/"), 3)

    def test_publisher_uses_verified_source_and_candidate_sprites(self):
        publish = self.publisher["jobs"]["publish"]
        source = commands(publish)
        self.assertIn("tools/verify_web_candidate.py --run-json", source)
        self.assertIn("--candidate-dir builds/browser-candidate", source)
        self.assertIn('git restore --source="${source_sha}" -- functions wrangler.jsonc', source)
        self.assertIn("${sprite_version}/pikachu/animation.json", source)
        self.assertNotIn("pokemon-front-scale1-128-", source)
        for job in self.publisher["jobs"].values():
            for step in job["steps"]:
                if step.get("uses", "").startswith("actions/checkout@"):
                    self.assertEqual(step["with"]["ref"], "${{ github.sha }}")

    def test_restored_build_keeps_original_identity_on_a_failed_job_retry(self):
        build_steps = self.preview["jobs"]["build"]["steps"]
        assemble = next(step["run"] for step in build_steps if "candidate.json').write_text" in step.get("run", ""))
        archive = next(step["run"] for step in build_steps if "tar -I" in step.get("run", ""))
        restore = next(step["run"] for step in self.preview["jobs"]["deploy"]["steps"]
                       if "tar -xzf" in step.get("run", ""))
        source = "a" * 40
        identity = source + "-42-1"
        env = {**os.environ, "GITHUB_SHA": source, "GITHUB_RUN_ID": "42", "GITHUB_RUN_ATTEMPT": "1",
               "WEB_BUILD_ID": identity, "PREVIEW_URL": "https://rc.pokeaether-web.pages.dev",
               "PREVIEW_CLIENT_BUILD_ID": "previous-build", "RELEASE_VERSION": "0.4.0"}
        with tempfile.TemporaryDirectory() as build_dir, tempfile.TemporaryDirectory() as retry_dir:
            built, retried = Path(build_dir), Path(retry_dir)
            for directory in ("web-pages-production", "web-pages-preview", "web-r2"):
                (built / "builds" / directory).mkdir(parents=True)
            (built / "builds/web-pages-production/index.js").write_text("tested JS")
            (built / "builds/web-pages-preview/index.js").write_text("preview JS")
            for name in ("web-release.json", "manifest-web.json"):
                (built / "builds/web-r2" / name).write_text("{}")
            subprocess.run(["bash", "-e", "-c", assemble + archive], cwd=built, env=env,
                           check=True, capture_output=True, text=True)
            (retried / "builds").mkdir()
            shutil.copy2(built / "builds/browser-release-build.tar.gz", retried / "builds")
            env.update(GITHUB_RUN_ATTEMPT="2", GITHUB_ENV=str(retried / "github-env"))
            subprocess.run(["bash", "-e", "-c", restore], cwd=retried, env=env,
                           check=True, capture_output=True, text=True)
            restored = json.loads((retried / "builds/browser-candidate/candidate.json").read_text())
            self.assertEqual(restored["buildId"], identity)
            self.assertIn("WEB_BUILD_ID=" + identity, (retried / "github-env").read_text())
            self.assertEqual((retried / "builds/web-pages-preview/index.js").read_text(), "preview JS")

    def test_real_http_cors_headers_pass_and_wrong_origin_is_rejected(self):
        command = next(step["run"] for step in self.publisher["jobs"]["publish"]["steps"]
                       if "^access-control-allow-origin:" in step.get("run", ""))
        origin = "https://play.pokeaether.com"

        class Handler(BaseHTTPRequestHandler):
            def do_HEAD(self):
                self.send_response(200)
                self.send_header("Access-Control-Allow-Origin", origin)
                self.end_headers()  # Real HTTP headers end in CRLF, not just LF.

            def log_message(self, *args):
                pass

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "builds/browser-candidate/r2").mkdir(parents=True)
            (root / "builds/browser-candidate/r2/manifest-web.json").write_text('{"gameBuildId":"fixture"}')
            server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
            self.addCleanup(server.server_close)
            self.addCleanup(server.shutdown)
            threading.Thread(target=server.serve_forever, daemon=True).start()
            env = {**os.environ, "R2_ASSET_BASE_URL": f"http://127.0.0.1:{server.server_port}"}
            result = subprocess.run(["bash", "-eo", "pipefail", "-c", command], cwd=root,
                                    env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            origin = "https://wrong.example.invalid"
            result = subprocess.run(["bash", "-eo", "pipefail", "-c", command], cwd=root,
                                    env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
