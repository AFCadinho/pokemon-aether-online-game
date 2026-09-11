import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import unittest

import httpx
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect
from websockets.sync.server import serve

spec = importlib.util.spec_from_file_location("preview_proxy", Path(__file__).resolve().parents[1] / "tools/serve_web_connected.py")
proxy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proxy)


class ConnectedProxyTests(unittest.TestCase):
    def test_local_target_validation(self):
        for url in ["https://pokeaether.com", "http://localhost:8000", "http://127.0.0.1:8000/path", "http://user:pass@127.0.0.1:8000", "http://127.0.0.1:8000?target=remote"]:
            with self.assertRaises(ValueError):
                proxy.create_app(url)

    def test_http_boundary_headers_payload_and_static_security(self):
        calls = []
        def upstream(request):
            calls.append(request)
            return httpx.Response(200, json={"ok": True})
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "index.html").write_text("test export")
            (root / ".secret").write_text("not served")
            (root / "external.js").symlink_to("/etc/passwd")
            client = TestClient(proxy.create_app("http://127.0.0.1:8000", root, transport=httpx.MockTransport(upstream)), base_url="http://127.0.0.1:8061")
            result = client.post("/api/auth/web/login", json={"username": "test"}, headers={
                "authorization": "Bearer test-only", "x-pokeaether-client-platform": "windows", "x-pokeaether-client-build": "web-test",
                "cf-connecting-ip": "203.0.113.12", "x-forwarded-for": "203.0.113.13",
            })
            self.assertEqual(result.status_code, 200)
            self.assertEqual(calls[0].url.path, "/auth/web/login")
            self.assertEqual(calls[0].headers["x-pokeaether-client-platform"], "web")
            self.assertEqual(calls[0].headers["authorization"], "Bearer test-only")
            self.assertNotIn("cf-connecting-ip", calls[0].headers)
            self.assertNotIn("x-forwarded-for", calls[0].headers)
            self.assertEqual(json.loads(calls[0].content), {"username": "test"})
            self.assertEqual(client.get("/api/auth/web/world").status_code, 200)
            self.assertEqual(client.put("/api/auth/web/world", json={"mapId": "kanto_pallet_town"}).status_code, 200)
            self.assertEqual(client.get("/api/auth/web/preferences").status_code, 200)
            self.assertEqual(client.put("/api/auth/web/preferences", json={"runningShoes": True}).status_code, 200)
            self.assertEqual(client.get("/api/auth/web/world/transitions/kanto_pallet_town__to_route_1/access").status_code, 200)
            self.assertEqual(client.post("/api/auth/web/world/transitions/kanto_pallet_town__to_route_1/enter", json={"facingDirection": "down"}).status_code, 200)
            self.assertEqual(client.get("/api/auth/web/world/areas/kanto_players_house/access").status_code, 200)
            self.assertEqual(client.get("/api/auth/web/world/story").status_code, 200)
            self.assertEqual(client.post("/api/auth/web/world/story/bootstrap").status_code, 200)
            self.assertEqual(client.get("/api/auth/web/profile").status_code, 200)
            self.assertEqual(client.get("/api/auth/web/party").status_code, 200)
            self.assertEqual(client.get("/api/auth/web/starter/options").status_code, 200)
            self.assertEqual(client.post("/api/auth/web/starter", json={"speciesId": "bulbasaur"}).status_code, 200)
            self.assertEqual(client.get("/api/auth/web/ai-sparring/statistics").status_code, 200)
            self.assertEqual(client.get("/api/auth/web/ai-sparring/history?limit=20&offset=0").status_code, 200)
            self.assertEqual(client.delete("/api/auth/web/ai-sparring/history").status_code, 200)
            self.assertEqual(client.get("/api/battle/pvp/training/ai/teams").status_code, 200)
            self.assertEqual(client.get("/api/battle/pvp/training/ai/live").status_code, 200)
            self.assertEqual(client.get("/api/pokemon/stats?species=rattata&level=2").status_code, 200)
            self.assertEqual(client.get("/api/battle/pvp/training/ai/live/training-test/spectate").status_code, 200)
            sprite = client.get("/pokemon-assets/gen5/front/pikachu/animation.json")
            self.assertEqual(sprite.status_code, 200)
            self.assertEqual(sprite.headers["cache-control"], "public, max-age=31536000, immutable")
            self.assertEqual(client.get("/pokemon-assets/gen5/front/pikachu/other.txt").status_code, 404)
            self.assertEqual(client.get("/api/battle/pvp/training/ai/teams/catalog-team").status_code, 200)
            self.assertEqual(client.post("/api/battle/pvp/training/ai/battles", json={}).status_code, 200)
            # A complete six-Pokémon party can exceed the generic UI request
            # limit. PvE battle creation keeps a bounded, larger allowance.
            self.assertEqual(client.post("/api/battle/wild-encounter", content="x" * 20000).status_code, 200)
            self.assertEqual(client.post("/api/battle/trainer", content="x" * 20000).status_code, 200)
            self.assertEqual(client.post("/api/battle/training-test/choice-and-resolve", json={}).status_code, 200)
            self.assertEqual(client.get("/api/battle/training-test/state").status_code, 200)
            self.assertEqual(client.get("/api/npcs/kanto_players_house_father").status_code, 200)
            self.assertEqual(client.get("/api/dialogues/kanto_players_house_father_starter_intro").status_code, 200)
            self.assertEqual(client.post("/api/npcs/kanto_players_house_father").status_code, 403)
            for path in ["/api/auth/login", "/api/internal/test", "/api/pvp/queues/ranked/join"]:
                self.assertEqual(client.post(path).status_code, 403)
            self.assertEqual(client.post("/api/auth/web/login", content="x" * 16385).status_code, 413)
            self.assertEqual(client.post("/api/battle/wild-encounter", content="x" * (128 * 1024 + 1)).status_code, 413)
            self.assertEqual(client.get("/", headers={"host": "attacker.example"}).status_code, 403)
            self.assertEqual(client.get("/", headers={"origin": "https://attacker.example"}).status_code, 403)
            self.assertEqual(client.get("/").text, "test export")
            self.assertIn("frame-ancestors 'none'", client.get("/").headers["content-security-policy"])
            for path in ["/.secret", "/external.js", "/%2e%2e/etc/passwd"]:
                self.assertEqual(client.get(path).status_code, 404)
            self.assertEqual(len(calls), 29)

    def test_redirects_and_upstream_failure_are_not_followed_or_exposed(self):
        for handler, status in [(lambda _: httpx.Response(302, headers={"Location": "https://example.com"}), 502),
                                (lambda _: (_ for _ in ()).throw(httpx.ConnectError("private detail")), 503)]:
            client = TestClient(proxy.create_app("http://127.0.0.1:8000", transport=httpx.MockTransport(handler)), base_url="http://localhost")
            result = client.get("/api/auth/web/meta")
            self.assertEqual(result.status_code, status)
            self.assertNotIn("private detail", result.text)

    def test_websocket_roundtrip_and_close_through_same_origin_path(self):
        paths = []
        def echo(socket):
            paths.append(socket.request.path)
            socket.send(socket.recv())
            socket.close(1000)
        with serve(echo, "127.0.0.1", 0) as upstream:
            worker = threading.Thread(target=upstream.serve_forever, daemon=True)
            worker.start()
            port = upstream.socket.getsockname()[1]
            client = TestClient(proxy.create_app(f"http://127.0.0.1:{port}"), base_url="http://localhost")
            with client.websocket_connect("ws://localhost/api/ws/chat?token=test-only&clientBuild=web-test&clientPlatform=windows") as socket:
                socket.send_text("ping")
                self.assertEqual(socket.receive_text(), "ping")
                self.assertEqual(socket.receive()["code"], 1000)
            self.assertIn("clientPlatform=web", paths[0])
            with client.websocket_connect("ws://localhost/api/ws/world-presence?token=test-only&clientBuild=web-test") as socket:
                socket.send_text("presence")
                self.assertEqual(socket.receive_text(), "presence")
                self.assertEqual(socket.receive()["code"], 1000)
            self.assertIn("/ws/world-presence", paths[1])
            upstream.shutdown()
            worker.join(timeout=5)

    def test_websocket_preserves_policy_rejection_and_blocks_other_origins(self):
        def reject(socket):
            socket.close(1008)
        with serve(reject, "127.0.0.1", 0) as upstream:
            worker = threading.Thread(target=upstream.serve_forever, daemon=True)
            worker.start()
            port = upstream.socket.getsockname()[1]
            client = TestClient(proxy.create_app(f"http://127.0.0.1:{port}"))
            with client.websocket_connect("ws://localhost/api/ws/chat?token=test-only") as socket:
                self.assertEqual(socket.receive()["code"], 1008)
            with self.assertRaises(WebSocketDisconnect) as rejected:
                with client.websocket_connect("ws://localhost/api/ws/chat", headers={"origin": "https://attacker.example"}):
                    self.fail("foreign origin was accepted")
            self.assertEqual(rejected.exception.code, 1008)
            upstream.shutdown()
            worker.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
