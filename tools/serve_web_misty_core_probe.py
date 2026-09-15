#!/usr/bin/env python3
"""Loopback-only core + Misty QA server. No backend, proxy, accounts or credentials."""
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCOPE = json.loads((ROOT / "docs/browser-misty-scope.json").read_text())
CATALOG = json.loads((ROOT.parent / "backend/account-service/generated/world_access_catalog.json").read_text())
PACK = ROOT / "builds/web-misty-trial/misty-maps.pck"
HTML = b'''<!doctype html><canvas id="canvas" width="1280" height="720"></canvas>
<script src="/core.js"></script><script>
window.pokeaetherPreview = {};
const engine = new Engine({executable:'core', mainPack:'core.pck',canvas:document.querySelector('canvas'),
canvasResizePolicy:2});
engine.startGame().catch(e=>console.error(e));
</script>'''


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.headers.get("Host") != "127.0.0.1:8064":
            self.send_error(403)
            return
        files = {"/core.js": ROOT / "builds/web-misty-core/index.js", "/core.wasm": ROOT / "builds/web-misty-core/index.wasm",
                 "/core.pck": ROOT / "builds/web-misty-core/index.pck",
                 "/core.audio.worklet.js": ROOT / "builds/web-misty-core/index.audio.worklet.js",
                 "/core.audio.position.worklet.js": ROOT / "builds/web-misty-core/index.audio.position.worklet.js",
                 "/probe.gd": ROOT / "tests/web_misty_core_probe.gd",
                 "/loader.gd": ROOT / "scripts/services/web_asset_module_service.gd",
                 "/browser-audio/music/overworld/kanto/caves/mt_moon.ogg": ROOT / "assets/music/overworld/kanto/caves/mt_moon.ogg",
                 "/browser-audio/music/overworld/kanto/towns/cerulean_city.ogg": ROOT / "assets/music/overworld/kanto/towns/cerulean_city.ogg",
                 "/modules/misty-maps.pck": PACK}
        if self.path == "/":
            body = HTML
        elif self.path == "/scenes.json":
            body = json.dumps([CATALOG["areas"][i]["scenePath"] for i in SCOPE["additionalMapIds"]]).encode()
        elif self.path == "/modules/manifest.json":
            body = json.dumps({"modules": {"kanto-through-misty-maps": {
                "file": "misty-maps.pck", "version": "trial", "sha256": hashlib.sha256(PACK.read_bytes()).hexdigest(),
                "bytes": PACK.stat().st_size}}}).encode()
        elif self.path == "/news.json":
            body = b'{"items":[]}'
        elif self.path == "/favicon.ico":
            body = b''
        elif self.path in files and files[self.path].is_file():
            body = files[self.path].read_bytes()
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/html" if self.path == "/" else "application/wasm" if self.path.endswith(".wasm") else "text/javascript" if self.path.endswith(".js") else "application/octet-stream")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8064), Handler).serve_forever()
