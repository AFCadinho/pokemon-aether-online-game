#!/usr/bin/env python3
"""Loopback-only connected web preview proxy. No production targets."""
import argparse
import asyncio
from pathlib import Path
import re
from urllib.parse import urlsplit

import httpx
import uvicorn
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, JSONResponse, Response
from websockets.asyncio.client import connect
from websockets.exceptions import ConnectionClosed, InvalidStatus

ROOT = Path(__file__).resolve().parents[1]
NEWS_URL = "https://updates.pokeaether.com/data/news.json"
POKEMON_ASSET_ROOT = (ROOT / "assets/sprites/pokemon/gen5").resolve()
HTTP_ROUTES = {
    ("GET", "/auth/status"), ("GET", "/presence/online-count"),
    ("GET", "/auth/web/meta"), ("GET", "/auth/web/me"),
    ("POST", "/auth/web/signup"), ("POST", "/auth/web/login"), ("POST", "/auth/web/logout"),
    ("GET", "/auth/web/preferences"), ("PUT", "/auth/web/preferences"),
    ("PATCH", "/auth/web/party/battle-state"),
    ("GET", "/auth/web/profile"), ("GET", "/auth/web/party"),
    ("GET", "/auth/web/inventory"), ("GET", "/auth/web/guilds"),
    ("GET", "/auth/web/transit"),
    ("GET", "/auth/web/starter/options"), ("POST", "/auth/web/starter"),
    ("GET", "/auth/web/ai-sparring/statistics"),
    ("GET", "/auth/web/ai-sparring/history"), ("DELETE", "/auth/web/ai-sparring/history"),
    ("GET", "/battle/pvp/training/ai/teams"),
    ("GET", "/battle/pvp/training/ai/live"),
    ("POST", "/battle/pvp/training/ai/battles"),
    ("POST", "/battle/wild-encounter"), ("GET", "/battle/wild/resume"),
    ("POST", "/battle/trainer"), ("GET", "/battle/trainer/resume"),
    ("POST", "/battle/pvp/rooms"),
    # Public species data needed by the battle hover card (including speed tiers).
    ("GET", "/pokemon/stats"),
    ("POST", "/auth/email-verification/confirm"),
}
AI_BATTLE_ROUTE = re.compile(
    r"^/battle/[A-Za-z0-9-]{1,128}/(?:state|lead|choice|choice-and-resolve|npc/(?:lead|choice)|pass-turn|pokemon-info|damage-calc|calcdex/v1/(?:snapshot|open|matchup|smart-matchup|inferred-matchup|set-suggestions))$"
)
HTTP_ROUTE_PREFIXES = (
	# Read/write game interfaces explicitly enabled in the browser demo. These
	# retain the normal account and server-side authorization checks.
	("GET", "/game/pokedex/"), ("GET", "/game/items/"),
	("GET", "/game/skills"),
	("GET", "/game/donator-store"), ("POST", "/game/donator-store/"),
	("GET", "/game/guilds"), ("POST", "/game/guilds"), ("PUT", "/game/guilds/"),
	("GET", "/game/guild-invitations"), ("POST", "/game/guild-invitations"),
	("GET", "/game/guild-notifications"),
    ("GET", "/battle/pvp/training/ai/live/"),
    ("GET", "/battle/pvp/rooms/"), ("POST", "/battle/pvp/rooms/"),
    ("GET", "/npcs/"),
    ("GET", "/dialogues/"),
    ("GET", "/encounters/"),
    ("GET", "/auth/web/world/story"),
    ("POST", "/auth/web/world/story"),
	("GET", "/auth/web/world/activity"), ("PUT", "/auth/web/world/activity"),
	("GET", "/auth/web/world/encounter-modifiers"),
    ("GET", "/auth/web/mail"), ("POST", "/auth/web/mail"),
    ("GET", "/auth/web/socials"), ("POST", "/auth/web/socials"),
    ("PUT", "/auth/web/socials"), ("DELETE", "/auth/web/socials"),
    ("POST", "/auth/web/wild-battles/"),
    ("POST", "/auth/web/transit/"),
    ("GET", "/game/replays"), ("POST", "/game/replays"),
    ("PATCH", "/game/replays"), ("DELETE", "/game/replays"),
    ("GET", "/auth/web/world/transitions/"),
    ("POST", "/auth/web/world/transitions/"),
    ("GET", "/auth/web/world/areas/"),
)
SECURITY_HEADERS = {
    "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff", "Referrer-Policy": "no-referrer",
    "Content-Security-Policy": "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; worker-src 'self' blob:; frame-ancestors 'none'",
}


def validate_upstream(value):
    parsed = urlsplit(value)
    if (parsed.scheme != "http" or parsed.hostname != "127.0.0.1" or not parsed.port
            or parsed.username or parsed.password or parsed.path not in {"", "/"} or parsed.query or parsed.fragment):
        raise ValueError("Upstream must be an explicit http://127.0.0.1:PORT local gateway, without credentials or paths")
    return value.rstrip("/")


def local_request(request):
    host = request.headers.get("host", "")
    if urlsplit("//" + host).hostname not in {"localhost", "127.0.0.1", "::1"}:
        return False
    origin = request.headers.get("origin")
    return not origin or origin == "http://" + host


def create_app(upstream, build=None, *, transport=None):
    upstream = validate_upstream(upstream)
    build = (build or ROOT / "builds/web").resolve()
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)

    @app.middleware("http")
    async def security(request, call_next):
        if not local_request(request):
            response = JSONResponse({"error": "Local same-origin preview only"}, status_code=403)
        else:
            response = await call_next(request)
        response.headers.update(SECURITY_HEADERS)
        if request.url.path.startswith("/pokemon-assets/gen5/") and response.status_code == 200:
            response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
        return response

    @app.api_route("/api/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD"])
    async def proxy(request: Request, path: str):
        route = "/" + path
        allowed = (request.method, route) in HTTP_ROUTES or any(
            request.method == method and route.startswith(prefix)
            for method, prefix in HTTP_ROUTE_PREFIXES
        )
        if route == "/auth/web/world" and request.method in {"GET", "PUT"}:
            allowed = True
        if request.method == "GET" and route.startswith("/battle/pvp/training/ai/teams/"):
            allowed = True
        if request.method in {"GET", "POST"} and AI_BATTLE_ROUTE.fullmatch(route):
            allowed = True
        if not allowed:
            return JSONResponse({"error": "Not enabled in this browser build"}, status_code=403)
        # A real party can contain detailed move, IV and cosmetic data.  The
        # 16 KiB preview default was below a legitimate wild/trainer battle
        # payload, so the request was rejected by the local proxy before it
        # reached the account-authorized battle service.  Keep a finite
        # browser boundary while allowing the normal client contract.
        max_request_bytes = 128 * 1024 if route.startswith("/battle/") else 16 * 1024
        body = bytearray()
        async for chunk in request.stream():
            body.extend(chunk)
            if len(body) > max_request_bytes:
                return JSONResponse({"error": "Request too large"}, status_code=413)
        # No forwarded host/IP, cookie, origin or arbitrary authority headers.
        headers = {name: request.headers[name] for name in (
            "authorization", "content-type", "accept", "x-pokeaether-client-build",
        ) if name in request.headers}
        headers["x-pokeaether-client-platform"] = "web"
        try:
            async with httpx.AsyncClient(timeout=15, trust_env=False, transport=transport) as client:
                # FastAPI's path parameter intentionally excludes the query
                # string. Preserve that query for the allowlisted route: many
                # normal client contracts use it for public lookup arguments
                # (for example Pokémon hover species/level data).
                query = request.url.query
                upstream_url = upstream + route + (("?" + query) if query else "")
                result = await client.request(request.method, upstream_url, content=bytes(body), headers=headers)
            # Never follow redirects (especially to external account services).
            if 300 <= result.status_code < 400:
                return JSONResponse({"error": "Unexpected upstream redirect"}, status_code=502)
            forwarded = {key: result.headers[key] for key in ("content-type", "retry-after") if key in result.headers}
            return Response(result.content, status_code=result.status_code, headers=forwarded)
        except httpx.HTTPError:
            return JSONResponse({"error": "Local account gateway unavailable"}, status_code=503)

    async def websocket_proxy(socket: WebSocket, channel: str):
        if not local_request(socket):
            await socket.close(code=1008)
            return
        # Gateway still authenticates the server-issued token against the
        # dedicated browser-chat identity capability.
        query = dict(socket.query_params)
        if not set(query) <= {"token", "clientBuild", "clientPlatform"}:
            await socket.close(code=1008)
            return
        query["clientPlatform"] = "web"
        url = httpx.URL(upstream.replace("http://", "ws://", 1) + f"/ws/{channel}", params=query)
        tasks = []
        try:
            async with connect(str(url), proxy=None, open_timeout=10, max_size=65536) as remote:
                await socket.accept()

                async def outbound():
                    while True:
                        message = await socket.receive_text()
                        if len(message.encode()) > 65536:
                            await socket.close(code=1009)
                            return
                        await remote.send(message)

                async def inbound():
                    async for message in remote:
                        if isinstance(message, str):
                            await socket.send_text(message)
                        else:
                            await socket.send_bytes(message)
                    await socket.close(code=remote.close_code or 1000)

                tasks = [asyncio.create_task(outbound()), asyncio.create_task(inbound())]
                done, _ = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
                for task in done:
                    task.result()
        except InvalidStatus:
            await socket.close(code=1008)
        except ConnectionClosed as error:
            code = error.rcvd.code if error.rcvd is not None else 1013
            await socket.close(code=code if code not in {1005, 1006, 1015} else 1013)
        except (OSError, TimeoutError):
            await socket.close(code=1013)
        except WebSocketDisconnect:
            pass
        finally:
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)

    @app.websocket("/api/ws/chat")
    async def chat_websocket_proxy(socket: WebSocket):
        await websocket_proxy(socket, "chat")

    @app.get("/news.json")
    async def browser_news():
        async with httpx.AsyncClient(follow_redirects=False, timeout=8.0) as client:
            response = await client.get(NEWS_URL, headers={"Accept": "application/json"})
        if response.status_code != 200:
            return Response(status_code=502)
        return Response(
            content=response.content,
            media_type="application/json",
            headers={"Cache-Control": "public, max-age=300"},
        )

    @app.websocket("/api/ws/world-presence")
    async def world_presence_websocket_proxy(socket: WebSocket):
        await websocket_proxy(socket, "world-presence")

    @app.websocket("/api/ws/pvp-battle")
    async def pvp_battle_websocket_proxy(socket: WebSocket):
        await websocket_proxy(socket, "pvp-battle")

    @app.get("/pokemon-assets/gen5/{side}/{species}/{filename}")
    async def pokemon_asset(side: str, species: str, filename: str):
        if (side not in {"front", "back", "shiny_front", "shiny_back"}
                or not re.fullmatch(r"[a-z0-9-]{1,96}", species)
                or filename not in {"animation.json", "sheet.png"}):
            return Response(status_code=404)
        target = (POKEMON_ASSET_ROOT / side / species / filename).resolve()
        if not target.is_relative_to(POKEMON_ASSET_ROOT) or target.is_symlink() or not target.is_file():
            return Response(status_code=404)
        return FileResponse(target)

    @app.get("/{path:path}")
    async def static(path: str):
        target = (build / (path or "index.html")).resolve()
        if (not target.is_relative_to(build) or any(part.startswith(".") for part in Path(path).parts)
                or not target.is_file() or target.suffix not in {".html", ".js", ".wasm", ".pck", ".png", ".svg", ".ico"}):
            return Response(status_code=404)
        mime = {".wasm": "application/wasm", ".pck": "application/octet-stream"}.get(target.suffix)
        return FileResponse(target, media_type=mime)

    return app


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", required=True, help="Explicit local integration gateway, e.g. http://127.0.0.1:8000")
    parser.add_argument("--port", type=int, default=8061)
    args = parser.parse_args()
    try:
        app = create_app(args.upstream)
    except ValueError as error:
        parser.error(str(error))
    print(f"Connected local web preview: http://127.0.0.1:{args.port}", flush=True)
    # Disable access logs: WebSocket queries can contain bearer credentials.
    uvicorn.run(app, host="127.0.0.1", port=args.port, access_log=False, log_level="critical", proxy_headers=False)


if __name__ == "__main__":
    main()
