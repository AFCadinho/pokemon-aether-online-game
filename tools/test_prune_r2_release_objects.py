from __future__ import annotations

import datetime as dt
import unittest
from unittest.mock import patch

from prune_r2_release_objects import (
    R2Config,
    R2Object,
    _build_prune_plan,
    _delete_object,
    _key_from_public_url,
    _list_release_objects,
    _object_family,
    _protected_keys_from_manifests,
)


NOW = dt.datetime(2026, 8, 16, 12, 0, tzinfo=dt.UTC)


def item(key: str, days_old: int, size: int = 10) -> R2Object:
    return R2Object(key=key, size=size, last_modified=NOW - dt.timedelta(days=days_old))


def recent_item(key: str, hours_old: int, size: int = 10) -> R2Object:
    return R2Object(key=key, size=size, last_modified=NOW - dt.timedelta(hours=hours_old))


class R2ReleasePrunerTests(unittest.TestCase):
    def test_manifest_urls_protect_only_the_configured_public_origin(self) -> None:
        manifests = [
            {
                "game": {"url": "https://updates.pokeaether.com/game/game-current-windows.zip"},
                "assetPacks": [
                    {"url": "https://updates.pokeaether.com/assets/music-current.zip"},
                    {"url": "https://example.com/assets/music-foreign.zip"},
                ],
            }
        ]

        protected = _protected_keys_from_manifests(manifests, "https://updates.pokeaether.com")

        self.assertEqual(
            protected,
            {"game/game-current-windows.zip", "assets/music-current.zip"},
        )

    def test_url_key_rejects_path_traversal_and_other_origins(self) -> None:
        base = "https://updates.pokeaether.com"
        self.assertIsNone(_key_from_public_url("https://example.com/assets/music-old.zip", base))
        self.assertIsNone(_key_from_public_url("https://updates.pokeaether.com/assets/../secret", base))

    def test_allowlist_ignores_latest_aliases_and_unknown_assets(self) -> None:
        self.assertIsNone(_object_family("game/latest/PokeAether-windows.zip"))
        self.assertIsNone(_object_family("assets/custom-textures-v1.zip"))
        self.assertEqual(
            _object_family("assets/pokemon-back-scale1-128-version.zip"),
            "assets:pokemon-back",
        )
        self.assertEqual(
            _object_family("game/game-0.4-build-linux.zip"),
            "game:linux",
        )

    def test_plan_keeps_current_previous_and_recent_then_deletes_older(self) -> None:
        objects = [
            item("assets/pokemon-back-scale1-128-current.zip", 1),
            item("assets/pokemon-back-scale1-128-previous.zip", 3),
            item("assets/pokemon-back-scale1-128-recent.zip", 0),
            item("assets/pokemon-back-scale1-128-old.zip", 10),
            item("assets/unmanaged.zip", 30),
        ]

        plan = _build_prune_plan(
            objects,
            {"assets/pokemon-back-scale1-128-current.zip"},
            retain_previous=1,
            minimum_age=dt.timedelta(hours=24),
            now=NOW,
        )

        self.assertEqual(
            [value.key for value in plan.retained_for_rollback],
            ["assets/pokemon-back-scale1-128-recent.zip"],
        )
        self.assertEqual(
            [value.key for value in plan.delete],
            [
                "assets/pokemon-back-scale1-128-old.zip",
                "assets/pokemon-back-scale1-128-previous.zip",
            ],
        )
        self.assertEqual([value.key for value in plan.ignored], ["assets/unmanaged.zip"])

    def test_recent_object_beyond_the_rollback_slot_is_not_deleted(self) -> None:
        objects = [
            item("game/game-current-windows.zip", 1),
            item("game/game-previous-windows.zip", 2),
            recent_item("game/game-uploading-windows.zip", 3),
            recent_item("game/game-unreferenced-windows.zip", 12),
            item("game/game-old-windows.zip", 10),
        ]

        plan = _build_prune_plan(
            objects,
            {"game/game-current-windows.zip"},
            retain_previous=1,
            minimum_age=dt.timedelta(hours=24),
            now=NOW,
        )

        self.assertEqual(
            [value.key for value in plan.retained_for_rollback],
            ["game/game-uploading-windows.zip"],
        )
        self.assertEqual(
            [value.key for value in plan.retained_recent],
            ["game/game-unreferenced-windows.zip"],
        )
        self.assertEqual(
            [value.key for value in plan.delete],
            ["game/game-old-windows.zip", "game/game-previous-windows.zip"],
        )

    @patch("prune_r2_release_objects._signed_request")
    def test_r2_listing_reads_only_asset_and_game_prefixes(self, signed_request) -> None:
        signed_request.side_effect = [
            (
                200,
                "OK",
                b"""<?xml version="1.0" encoding="UTF-8"?>
                <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                  <IsTruncated>false</IsTruncated>
                  <Contents>
                    <Key>assets/music-current.zip</Key>
                    <LastModified>2026-08-15T12:00:00.000Z</LastModified>
                    <Size>123</Size>
                  </Contents>
                </ListBucketResult>""",
            ),
            (
                200,
                "OK",
                b"""<?xml version="1.0" encoding="UTF-8"?>
                <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                  <IsTruncated>false</IsTruncated>
                  <Contents>
                    <Key>game/game-current-linux.zip</Key>
                    <LastModified>2026-08-15T13:00:00.000Z</LastModified>
                    <Size>456</Size>
                  </Contents>
                </ListBucketResult>""",
            ),
        ]
        config = R2Config("account", "bucket", "access", "secret", "https://example.com")

        objects = _list_release_objects(config)

        self.assertEqual([value.key for value in objects], [
            "assets/music-current.zip",
            "game/game-current-linux.zip",
        ])
        self.assertEqual(objects[0].size, 123)
        self.assertEqual(signed_request.call_args_list[0].kwargs["query"], [
            ("list-type", "2"),
            ("prefix", "assets/"),
        ])
        self.assertEqual(signed_request.call_args_list[1].kwargs["query"], [
            ("list-type", "2"),
            ("prefix", "game/"),
        ])

    @patch("prune_r2_release_objects._signed_request")
    def test_delete_rechecks_the_allowlist(self, signed_request) -> None:
        config = R2Config("account", "bucket", "access", "secret", "https://example.com")
        signed_request.return_value = (204, "No Content", b"")

        _delete_object(config, "assets/music-old.zip")
        with self.assertRaises(SystemExit):
            _delete_object(config, "manifest.json")

        signed_request.assert_called_once_with(config, "DELETE", "assets/music-old.zip")


if __name__ == "__main__":
    unittest.main()
