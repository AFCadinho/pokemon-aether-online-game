#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path


LAUNCHER_ROOT = Path(__file__).resolve().parents[1]
SERVER_SCRIPT = Path(__file__).with_name("server_health_retry_server.py")


def main() -> None:
    godot = os.environ.get("GODOT_BIN", "godot")
    with tempfile.TemporaryDirectory(prefix="pokeaether-health-test-") as temp_dir:
        port_file = Path(temp_dir) / "port.txt"
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
                    raise SystemExit(f"health test server stopped: {server.stderr.read()}")
                time.sleep(0.05)
            if not port_file.exists():
                raise SystemExit("health test server did not publish its port")

            env = os.environ.copy()
            env["LAUNCHER_HEALTH_TEST_BASE_URL"] = f"http://127.0.0.1:{port_file.read_text().strip()}"
            subprocess.run(
                [godot, "--headless", "--path", str(LAUNCHER_ROOT), "--script", "res://tests/server_health_retry_check.gd"],
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
