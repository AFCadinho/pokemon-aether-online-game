#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path
from unittest import mock


TOOLS_DIR = Path(__file__).resolve().parent


def _load_module(name: str, file_name: str):
    spec = importlib.util.spec_from_file_location(name, TOOLS_DIR / file_name)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load {file_name}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


package_release = _load_module("package_launcher_release_test", "package_launcher_release.py")
verify_urls = _load_module("verify_launcher_release_urls_test", "verify_launcher_release_urls.py")


class FakeResponse:
    def __init__(self, status: int, headers: dict[str, str], body: bytes = b"") -> None:
        self.status = status
        self.headers = headers
        self.body = body

    def __enter__(self):
        return self

    def __exit__(self, *_args) -> None:
        return None

    def read(self, amount: int = -1) -> bytes:
        return self.body if amount < 0 else self.body[:amount]


class ExternalAssetMetadataTests(unittest.TestCase):
    def test_external_pack_requires_and_preserves_sha256(self) -> None:
        digest = "ab" * 32
        pack = package_release._build_external_asset_pack(
            f"sprites:v1:sprites-v1.zip:1234:{digest}:true",
            "https://updates.example",
            "assets",
        )
        self.assertEqual(pack["sha256"], digest)
        self.assertEqual(pack["sizeBytes"], 1234)
        self.assertTrue(pack["optional"])

    def test_external_pack_rejects_missing_checksum(self) -> None:
        with self.assertRaises(SystemExit):
            package_release._build_external_asset_pack(
                "sprites:v1:sprites-v1.zip:1234:",
                "https://updates.example",
                "assets",
            )


class PublicArtifactVerificationTests(unittest.TestCase):
    def test_verifier_requires_exact_size_checksum_and_range_support(self) -> None:
        responses = [
            FakeResponse(200, {"Content-Length": "10"}),
            FakeResponse(206, {"Content-Range": "bytes 0-0/10"}, b"x"),
        ]
        with mock.patch.object(verify_urls.urllib.request, "urlopen", side_effect=responses):
            verified: set[str] = set()
            verify_urls._verify_entry(
                Path("manifest.json"),
                "asset pack sprites",
                {
                    "url": "https://updates.example/assets/sprites.zip",
                    "sizeBytes": 10,
                    "sha256": "cd" * 32,
                },
                1.0,
                verified,
            )
        self.assertEqual(verified, {"https://updates.example/assets/sprites.zip"})

    def test_verifier_rejects_empty_checksum_before_network_access(self) -> None:
        with mock.patch.object(verify_urls.urllib.request, "urlopen") as urlopen:
            with self.assertRaises(SystemExit):
                verify_urls._verify_entry(
                    Path("manifest.json"),
                    "asset pack sprites",
                    {
                        "url": "https://updates.example/assets/sprites.zip",
                        "sizeBytes": 10,
                        "sha256": "",
                    },
                    1.0,
                    set(),
                )
            urlopen.assert_not_called()

    def test_verifier_rejects_server_that_ignores_range(self) -> None:
        responses = [
            FakeResponse(200, {"Content-Length": "10"}),
            FakeResponse(200, {"Content-Length": "10"}, b"xx"),
        ]
        with mock.patch.object(verify_urls.urllib.request, "urlopen", side_effect=responses):
            with self.assertRaises(SystemExit):
                verify_urls._verify_entry(
                    Path("manifest.json"),
                    "game",
                    {
                        "url": "https://updates.example/game.zip",
                        "sizeBytes": 10,
                        "sha256": "ef" * 32,
                    },
                    1.0,
                    set(),
                )


if __name__ == "__main__":
    unittest.main()
