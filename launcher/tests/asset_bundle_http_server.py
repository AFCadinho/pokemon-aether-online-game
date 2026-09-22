#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    root: Path
    files: dict[str, Path]

    def do_HEAD(self) -> None:
        self._serve(False)

    def do_GET(self) -> None:
        self._serve(True)

    def _serve(self, body: bool) -> None:
        path = self.path.split("?", 1)[0]
        source = self.files.get(path)
        if source is None:
            self.send_error(404)
            return
        payload = source.read_bytes()
        start, end = 0, len(payload) - 1
        requested = self.headers.get("Range", "")
        if requested.startswith("bytes=") and "," not in requested:
            bounds = requested[6:].split("-", 1)
            if len(bounds) == 2 and bounds[0].isdigit():
                start = int(bounds[0])
                end = min(int(bounds[1]), end) if bounds[1].isdigit() else end
                if start > end:
                    self.send_error(416)
                    return
                self.send_response(206)
                self.send_header("Content-Range", f"bytes {start}-{end}/{len(payload)}")
            else:
                self.send_error(416)
                return
        else:
            self.send_response(200)
        chunk = payload[start:end + 1]
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(len(chunk)))
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("ETag", f'"{source.name}"')
        self.end_headers()
        if body:
            self.wfile.write(chunk)

    def log_message(self, _format: str, *_args: object) -> None:
        return


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    parser.add_argument("--port-file", type=Path, required=True)
    args = parser.parse_args()
    root = args.directory.resolve()
    index = json.loads((root / "asset-index.json").read_text(encoding="utf-8"))
    Handler.root = root
    Handler.files = {f"/{asset['object_key']}": root / Path(asset["object_key"]).name for asset in index["assets"]}
    Handler.files["/optional-assets/pokemon_3d/index/test.json"] = root / "asset-index.json"
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    args.port_file.write_text(str(server.server_port), encoding="utf-8")
    server.serve_forever()


if __name__ == "__main__":
    main()
