#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path


LAUNCHER_ROOT = Path(__file__).resolve().parents[1]
SERVER_SCRIPT = Path(__file__).with_name("range_test_server.py")


def main() -> None:
    godot = os.environ.get("GODOT_BIN", "godot")
    with tempfile.TemporaryDirectory(prefix="pokeaether-range-test-") as temp_dir:
        temp_path = Path(temp_dir)
        port_file = temp_path / "port.txt"
        server = subprocess.Popen(
            [sys.executable, str(SERVER_SCRIPT), "--port-file", str(port_file)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            deadline = time.monotonic() + 10
            while not port_file.exists() and time.monotonic() < deadline:
                if server.poll() is not None:
                    raise SystemExit(f"range test server stopped: {server.stderr.read()}")
                time.sleep(0.05)
            if not port_file.exists():
                raise SystemExit("range test server did not publish its port")

            env = os.environ.copy()
            env["LAUNCHER_RANGE_TEST_BASE_URL"] = f"http://127.0.0.1:{port_file.read_text().strip()}"
            subprocess.run(
                [
                    godot,
                    "--headless",
                    "--path",
                    str(LAUNCHER_ROOT),
                    "--script",
                    "res://tests/resumable_download_check.gd",
                ],
                check=True,
                env=env,
            )
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=5)


if __name__ == "__main__":
    main()
