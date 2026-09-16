import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from verify_latest_download_redirects import verify


class Response:
    def __init__(self, status, location):
        self.status, self.headers = status, {"Location": location}
    def __enter__(self):
        return self
    def __exit__(self, *args):
        pass


class RedirectVerificationTests(unittest.TestCase):
    @patch("verify_latest_download_redirects.build_opener")
    def test_requires_manifest_targets_and_all_required_platforms(self, build_opener):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            targets = []
            for platform in ("windows", "linux"):
                manifest = {}
                for kind in ("game", "launcher"):
                    url = f"https://updates.pokeaether.com/{kind}/current-{platform}.zip"
                    manifest[kind] = {"url": url}
                    targets.append(Response(302, url))
                (root / f"manifest-{platform}.json").write_text(json.dumps(manifest))
            build_opener.return_value.open.side_effect = targets
            verify(root, "https://updates.pokeaether.com")
            self.assertEqual(build_opener.return_value.open.call_count, 4)
            build_opener.return_value.open.side_effect = [Response(200, targets[0].headers["Location"])]
            with self.assertRaises(SystemExit):
                verify(root, "https://updates.pokeaether.com")
            build_opener.return_value.open.side_effect = [Response(302, "https://evil.example/archive.zip")]
            with self.assertRaises(SystemExit):
                verify(root, "https://updates.pokeaether.com")
            (root / "manifest-windows.json").unlink()
            with self.assertRaises(SystemExit):
                verify(root, "https://updates.pokeaether.com")


if __name__ == "__main__":
    unittest.main()
