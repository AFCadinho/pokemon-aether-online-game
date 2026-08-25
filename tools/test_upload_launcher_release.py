#!/usr/bin/env python3

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import call, patch

import upload_launcher_release as uploader


class FakeResponse:
    def __init__(self, status: int, reason: str, body: str = "") -> None:
        self.status = status
        self.reason = reason
        self._body = body.encode("utf-8")

    def read(self) -> bytes:
        return self._body


class FakeConnection:
    def __init__(self, outcome: FakeResponse | OSError) -> None:
        self.outcome = outcome
        self.closed = False
        self.requests = 0

    def request(self, _method: str, _uri: str, *, body: object, headers: dict[str, str]) -> None:
        self.requests += 1
        if isinstance(self.outcome, OSError):
            raise self.outcome
        if body is None or not headers.get("Authorization"):
            raise AssertionError("Signed upload request was not prepared")

    def getresponse(self) -> FakeResponse:
        if isinstance(self.outcome, OSError):
            raise AssertionError("getresponse must not run after a request error")
        return self.outcome

    def close(self) -> None:
        self.closed = True


class ConnectionFactory:
    def __init__(self, outcomes: list[FakeResponse | OSError]) -> None:
        self.outcomes = outcomes.copy()
        self.connections: list[FakeConnection] = []

    def __call__(self, _host: str, *, timeout: int) -> FakeConnection:
        if timeout != 600:
            raise AssertionError("Unexpected upload timeout")
        connection = FakeConnection(self.outcomes.pop(0))
        self.connections.append(connection)
        return connection


class R2UploadRetryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.file_path = Path(self.temp_dir.name) / "release.zip"
        self.file_path.write_bytes(b"release payload")
        self.config = uploader.R2Config(
            "account",
            "bucket",
            "access",
            "secret",
            "https://example.com",
        )

    def test_retries_r2_internal_error_then_succeeds(self) -> None:
        factory = ConnectionFactory(
            [
                FakeResponse(500, "Internal Server Error", "InternalError"),
                FakeResponse(200, "OK"),
            ]
        )
        with (
            patch.object(uploader.http.client, "HTTPSConnection", side_effect=factory),
            patch.object(uploader.time, "sleep") as sleep,
        ):
            uploader._upload_file(self.config, self.file_path, "game/latest/release.zip")

        self.assertEqual(len(factory.connections), 2)
        self.assertTrue(all(connection.closed for connection in factory.connections))
        sleep.assert_called_once_with(2.0)

    def test_retries_network_error_with_a_fresh_connection(self) -> None:
        factory = ConnectionFactory([OSError("connection reset"), FakeResponse(204, "No Content")])
        with (
            patch.object(uploader.http.client, "HTTPSConnection", side_effect=factory),
            patch.object(uploader.time, "sleep") as sleep,
        ):
            uploader._upload_file(self.config, self.file_path, "game/release.zip")

        self.assertEqual(len(factory.connections), 2)
        sleep.assert_called_once_with(2.0)

    def test_does_not_retry_permanent_http_error(self) -> None:
        factory = ConnectionFactory([FakeResponse(403, "Forbidden", "AccessDenied")])
        with (
            patch.object(uploader.http.client, "HTTPSConnection", side_effect=factory),
            patch.object(uploader.time, "sleep") as sleep,
            self.assertRaisesRegex(SystemExit, "403 Forbidden"),
        ):
            uploader._upload_file(self.config, self.file_path, "game/release.zip")

        self.assertEqual(len(factory.connections), 1)
        sleep.assert_not_called()

    def test_stops_after_bounded_exponential_backoff(self) -> None:
        factory = ConnectionFactory(
            [
                FakeResponse(503, "Service Unavailable"),
                FakeResponse(503, "Service Unavailable"),
                FakeResponse(503, "Service Unavailable"),
            ]
        )
        with (
            patch.object(uploader, "MAX_UPLOAD_ATTEMPTS", 3),
            patch.object(uploader.http.client, "HTTPSConnection", side_effect=factory),
            patch.object(uploader.time, "sleep") as sleep,
            self.assertRaisesRegex(SystemExit, "503 Service Unavailable"),
        ):
            uploader._upload_file(self.config, self.file_path, "game/release.zip")

        self.assertEqual(len(factory.connections), 3)
        self.assertEqual(sleep.call_args_list, [call(2.0), call(4.0)])

    def test_retryable_status_contract(self) -> None:
        for status in (408, 429, 500, 502, 503, 504, 599):
            self.assertTrue(uploader._is_retryable_http_status(status))
        for status in (400, 401, 403, 404, 409):
            self.assertFalse(uploader._is_retryable_http_status(status))

    def test_mutable_news_objects_are_not_cached_as_immutable(self) -> None:
        self.assertEqual(
            uploader._get_cache_control_for_key("data/news.json"),
            "no-cache, max-age=0",
        )
        self.assertEqual(
            uploader._get_cache_control_for_key("data/news.previous.json"),
            "no-cache, max-age=0",
        )
        self.assertEqual(
            uploader._get_cache_control_for_key("assets/pokemon-front-v1.zip"),
            "public, max-age=31536000, immutable",
        )


if __name__ == "__main__":
    unittest.main()
