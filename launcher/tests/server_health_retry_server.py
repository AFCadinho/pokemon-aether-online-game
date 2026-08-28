#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Handler(BaseHTTPRequestHandler):
    retry_requests = 0

    def do_GET(self) -> None:
        if self.path == "/retry":
            Handler.retry_requests += 1
            if Handler.retry_requests < 3:
                self._send(503, {"detail": "temporary failure"})
            else:
                self._send(200, {"available": True, "mode": "open", "message": "", "disconnectAt": None})
            return
        if self.path == "/fail":
            self._send(503, {"detail": "temporary failure"})
            return
        self._send(404, {"detail": "not found"})

    def log_message(self, _format: str, *_args: object) -> None:
        return

    def _send(self, status: int, payload: dict[str, object]) -> None:
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port-file", type=Path, required=True)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    args.port_file.write_text(str(server.server_port))
    server.serve_forever()


if __name__ == "__main__":
    main()
