#!/usr/bin/env python3
from __future__ import annotations

import argparse
import socket
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


PAYLOAD = bytes(range(256)) * 8192


class RangeTestHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    request_counts: dict[str, int] = {}

    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]
        count = self.request_counts.get(path, 0) + 1
        self.request_counts[path] = count

        if path == "/retry.bin" and count == 1:
            self.send_response(503)
            self.send_header("Content-Length", "0")
            self.send_header("Retry-After", "0")
            self.end_headers()
            return

        if path == "/always-503.bin":
            self.send_response(503)
            self.send_header("Content-Length", "0")
            self.send_header("Retry-After", "0")
            self.end_headers()
            return

        range_header = self.headers.get("Range", "")
        start = self._range_start(range_header)
        ignore_range = path == "/ignore-range.bin" and count > 1
        if start > 0 and not ignore_range:
            body = PAYLOAD[start:]
            self.send_response(206)
            self.send_header("Content-Range", f"bytes {start}-{len(PAYLOAD) - 1}/{len(PAYLOAD)}")
        else:
            start = 0
            body = PAYLOAD
            self.send_response(200)

        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("ETag", '"range-test-v1"')
        self.send_header("CF-Ray", "test-request-AMS")
        self.end_headers()

        if path == "/stall.bin" and count == 1:
            self.wfile.write(body[: 128 * 1024])
            self.wfile.flush()
            time.sleep(0.6)
            try:
                self.wfile.write(body[128 * 1024 :])
            except (BrokenPipeError, ConnectionResetError):
                pass
            return

        should_drop = path in {"/drop.bin", "/ignore-range.bin"} and count == 1 and start == 0
        if should_drop:
            self.wfile.write(body[: 600 * 1024])
            self.wfile.flush()
            self.connection.shutdown(socket.SHUT_RDWR)
            self.connection.close()
            return

        if path == "/slow.bin":
            for offset in range(0, len(body), 32 * 1024):
                self.wfile.write(body[offset : offset + 32 * 1024])
                self.wfile.flush()
                time.sleep(0.015)
            return

        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        return

    @staticmethod
    def _range_start(value: str) -> int:
        if not value.startswith("bytes=") or not value.endswith("-"):
            return 0
        start_text = value[6:-1]
        return int(start_text) if start_text.isdigit() else 0


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port-file", required=True)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", 0), RangeTestHandler)
    with open(args.port_file, "w", encoding="utf-8") as port_file:
        port_file.write(str(server.server_port))
    server.serve_forever()


if __name__ == "__main__":
    main()
