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
    def _run(
        self, changelog: str, version: str = "0.3.74", release_notes: str = ""
    ) -> list[dict]:
        with tempfile.TemporaryDirectory() as directory:
            changelog_path = Path(directory) / "CHANGELOG.md"
            changelog_path.write_text(changelog, encoding="utf-8")
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--version",
                    version,
                    "--release-notes",
                    release_notes,
                    "--changelog",
                    str(changelog_path),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
        return json.loads(result.stdout)["payloads"]

    def test_direct_release_bullets_are_included(self) -> None:
        payloads = self._run("## 0.3.74 - 2026-09-07\n\n- New AI5\n- Better predictions\n")

        fields = payloads[0]["embeds"][0]["fields"]
        self.assertEqual(fields[0]["name"], "Release notes")
        self.assertEqual(fields[0]["value"], "- New AI5\n- Better predictions")

    def test_named_sections_still_work(self) -> None:
        payloads = self._run("## 0.3.74\n\n**Added**\n- New AI5\n\n**Fixed**\n- Fewer fallbacks\n")

        self.assertEqual(
            [field["name"] for field in payloads[0]["embeds"][0]["fields"]],
            ["Added", "Fixed"],
        )

    def test_markdown_headings_are_preserved(self) -> None:
        payloads = self._run(
            "## 0.3.74\n\n### Battles and calculator\n\n- Better predictions\n"
            "\n### World and interface\n\n- Smoother travel\n"
        )

        fields = payloads[0]["embeds"][0]["fields"]
        self.assertEqual(
            [field["name"] for field in fields],
            ["Battles and calculator", "World and interface"],
        )

    def test_large_release_is_split_without_losing_notes(self) -> None:
        notes = [f"- Release note {index}: " + ("x" * 180) for index in range(40)]
        payloads = self._run("## 0.3.74\n\n### Changes\n\n" + "\n".join(notes) + "\n")

        self.assertGreater(len(payloads), 1)
        posted_text = "\n".join(
            field["value"]
            for payload in payloads
            for field in payload["embeds"][0]["fields"]
        )
        for note in notes:
            self.assertIn(note, posted_text)

        for payload in payloads:
            embed = payload["embeds"][0]
            embed_size = len(embed.get("title", "")) + len(embed.get("description", ""))
            embed_size += sum(len(field["name"]) + len(field["value"]) for field in embed["fields"])
            self.assertLessEqual(embed_size, 6000)
            self.assertLessEqual(len(embed["fields"]), 25)

    def test_single_long_note_is_split_without_truncation(self) -> None:
        long_note = "- " + ("x" * 2400)
        payloads = self._run(f"## 0.3.74\n\n{long_note}\n")

        values = [
            field["value"]
            for payload in payloads
            for field in payload["embeds"][0]["fields"]
        ]
        self.assertEqual("".join(values), long_note)
        self.assertTrue(all(len(value) <= 1024 for value in values))

    def test_maximum_description_still_produces_valid_messages(self) -> None:
        notes = [f"- Note {index}: " + ("x" * 900) for index in range(8)]
        payloads = self._run(
            "## 0.3.74\n\n" + "\n".join(notes) + "\n",
            release_notes="d" * 4096,
        )

        self.assertGreater(len(payloads), 1)
        for payload in payloads:
            embed = payload["embeds"][0]
            embed_size = len(embed.get("title", "")) + len(embed.get("description", ""))
            embed_size += sum(len(field["name"]) + len(field["value"]) for field in embed["fields"])
            self.assertLessEqual(embed_size, 6000)

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
