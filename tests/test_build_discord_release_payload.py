from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "build_discord_release_payload.py"


class DiscordReleasePayloadTests(unittest.TestCase):
    def _run(self, changelog: str, version: str = "0.3.74") -> dict:
        with tempfile.TemporaryDirectory() as directory:
            changelog_path = Path(directory) / "CHANGELOG.md"
            changelog_path.write_text(changelog, encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--version", version, "--changelog", str(changelog_path)],
                check=True,
                capture_output=True,
                text=True,
            )
        return json.loads(result.stdout)

    def test_direct_release_bullets_are_included(self) -> None:
        payload = self._run("## 0.3.74 - 2026-09-07\n\n- New AI5\n- Better predictions\n")

        fields = payload["embeds"][0]["fields"]
        self.assertEqual(fields[0]["name"], "Release notes")
        self.assertEqual(fields[0]["value"], "- New AI5\n- Better predictions")

    def test_named_sections_still_work(self) -> None:
        payload = self._run("## 0.3.74\n\n**Added**\n- New AI5\n\n**Fixed**\n- Fewer fallbacks\n")

        self.assertEqual([field["name"] for field in payload["embeds"][0]["fields"]], ["Added", "Fixed"])

    def test_missing_release_fails_instead_of_posting_generic_text(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            changelog_path = Path(directory) / "CHANGELOG.md"
            changelog_path.write_text("## 0.3.73\n\n- Older release\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--version", "0.3.74", "--changelog", str(changelog_path)],
                capture_output=True,
                text=True,
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No release notes found", result.stderr)


if __name__ == "__main__":
    unittest.main()
