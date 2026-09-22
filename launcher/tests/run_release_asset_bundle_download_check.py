#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVER = Path(__file__).with_name("asset_bundle_http_server.py")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("release_dir", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="pokeaether-3d-http-") as temporary:
        port_file = Path(temporary) / "port"
        server = subprocess.Popen(
            [sys.executable, str(SERVER), str(args.release_dir.resolve()), "--port-file", str(port_file)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            deadline = time.monotonic() + 10
            while not port_file.exists() and time.monotonic() < deadline:
                if server.poll() is not None:
                    raise SystemExit(server.stderr.read())
                time.sleep(0.05)
            if not port_file.exists():
                raise SystemExit("asset bundle test server did not start")
            env = os.environ.copy()
            env.update({
                "POKEAETHER_BUNDLE_HTTP_BASE": f"http://127.0.0.1:{port_file.read_text()}",
                "POKEAETHER_BUNDLE_HTTP_INDEX": str(args.release_dir.resolve() / "asset-index.json"),
                "POKEAETHER_BUNDLE_HTTP_OUTPUT": str(args.output.resolve()),
            })
            subprocess.run([
                os.environ.get("GODOT_BIN", "godot"), "--headless", "--path", str(ROOT),
                "--script", "res://tests/release_asset_bundle_download_check.gd",
            ], check=True, env=env, timeout=150)
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=5)


if __name__ == "__main__":
    main()
