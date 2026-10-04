import hashlib
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import upload_web_release as uploader


class WebUploadReuseTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.payload = self.root / "index.wasm"
        self.payload.write_bytes(b"tested wasm")
        self.manifest = {"buildId": "candidate-42", "objects": [{
            "source": "index.wasm", "key": "web/releases/candidate-42/index.wasm",
            "bytes": self.payload.stat().st_size,
            "sha256": hashlib.sha256(self.payload.read_bytes()).hexdigest(),
        }]}
        (self.root / "web-release.json").write_text(json.dumps(self.manifest))
        self.config = SimpleNamespace(bucket="browser")

    def run_upload(self, remote):
        with (patch.object(uploader, "_load_config", return_value=self.config),
              patch.object(uploader, "_signed_request", return_value=remote) as read,
              patch.object(uploader, "_upload_file") as upload,
              patch.object(sys, "argv", ["upload_web_release.py", str(self.root), "--reuse-upload"])):
            uploader.main()
        return read, upload

    def test_retry_after_completed_upload_does_not_upload_runtime_again(self):
        read, upload = self.run_upload((200, "OK", json.dumps(self.manifest).encode()))
        read.assert_called_once_with(self.config, "GET", "web/releases/candidate-42/web-release.json")
        upload.assert_not_called()

    def test_missing_completion_receipt_uploads_objects_then_receipt(self):
        _, upload = self.run_upload((404, "Not Found", b""))
        self.assertEqual(upload.call_count, 2)
        self.assertEqual(upload.call_args_list[-1].args[2], "web/releases/candidate-42/web-release.json")

    def test_changed_local_payload_is_rejected_before_remote_reuse(self):
        self.payload.write_bytes(b"broken wasm")
        with (patch.object(uploader, "_load_config", return_value=self.config),
              patch.object(uploader, "_signed_request") as read,
              patch.object(sys, "argv", ["upload_web_release.py", str(self.root), "--reuse-upload"]),
              self.assertRaisesRegex(SystemExit, "mismatch|changed")):
            uploader.main()
        read.assert_not_called()

    def test_different_or_invalid_remote_receipt_is_never_overwritten(self):
        for body in (b"{}", b"not JSON"):
            with self.subTest(body=body), self.assertRaisesRegex(SystemExit, "refusing to overwrite"):
                self.run_upload((200, "OK", body))

    def test_failed_remote_check_is_not_treated_as_a_missing_upload(self):
        with self.assertRaisesRegex(SystemExit, "403"):
            self.run_upload((403, "Forbidden", b""))

    def test_transient_receipt_error_retries_without_uploading(self):
        with (patch.object(uploader, "_signed_request", side_effect=[
                  OSError("connection reset"), (503, "Unavailable", b""),
                  (200, "OK", json.dumps(self.manifest).encode())]) as read,
              patch.object(uploader, "_wait_before_retry") as retry):
            self.assertTrue(uploader.completed_upload_exists(self.config, self.manifest))
        self.assertEqual(read.call_count, 3)
        self.assertEqual(retry.call_count, 2)


if __name__ == "__main__":
    unittest.main()
