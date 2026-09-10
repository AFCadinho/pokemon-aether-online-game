# Local browser build — phase 1

This is a real WebAssembly export of the existing Godot 4.6 client, using the
`Web Local Preview` preset and the Compatibility renderer only for web. Desktop
renderer settings are preserved. The output belongs in `builds/web/` and is not
committed. No second Godot project or duplicate source asset tree is created.

## Current scope

The browser can open the existing login screen, render the player preview, open
settings and switch languages. A click starts the engine and unlocks browser
audio. Refresh does not trigger the desktop interrupted-session warning.

Online gameplay is deliberately disconnected in this first milestone. The
loopback server answers `/api/auth/status` with an explicit closed status and
rejects other API requests. It has **no backend proxy**. The client uses the
page's origin plus `/api`, never the desktop production fallback. News polling,
account links and automatic session restoration are disabled in this preview.
The shell only starts on loopback hosts. Its badge always identifies the preview.

These are development safeguards, not server-side feature authorization. This
build is not the complete MMO demo and must not be published as one.

## Build and inspect

From the `game` workspace, for the assigned slot (example: slot-b):

```sh
ops/worktrees/slot-env slot-b -- python3 .worktrees/slot-b/frontend/tools/build_web_preview.py
python3 .worktrees/slot-b/frontend/tools/serve_web_preview.py
```

Open `http://127.0.0.1:8060` and click **Open browser preview**. Use
`--port 8061` if that port is occupied. The server binds only to 127.0.0.1, serves
only the generated export, and does not log request URLs or bodies.

The assigned slot needs Godot's matching `web_nothreads_release.zip` export
template installed in its own XDG data directory. This is engine tooling, not a
copy of another checkout's caches. No multithreaded export or COOP/COEP headers
are needed in phase 1.

`builds/web/build-receipt.json` records the engine version, source commit,
tracked dirty-state, hashes and uncompressed transfer sizes. This makes a build
identifiable without including user settings, sessions, or credentials.

## Asset selection

The preset includes the shared client code and resources, full player assets,
localization and login music. It excludes world scenes, generated map visuals,
the large Pokemon sprite collections, battle/overworld music, launcher, tests,
tools, docs and benchmarks. Shared runtime classes need more than the login
scene's immediate resource dependencies, so scene-only export is insufficient.

The first preview prioritizes correct shared-client startup. Its download size
does not predict the final demo size. The map allowlist and on-demand Gen 5
sprite loader are later milestones, not implemented here.

## Focused validation

```sh
python3 -m unittest discover -s .worktrees/slot-b/frontend/tests -p test_web_preview_server.py
ops/worktrees/slot-env slot-b -- godot --headless --path .worktrees/slot-b/frontend --script res://tests/web_runtime_check.gd
node .worktrees/slot-b/frontend/tests/web_preview_browser_smoke.cjs
```

The last command requires Playwright. An existing installation can be used via
`NODE_PATH`; a locally installed Chromium binary can be supplied via
`POKEAETHER_CHROME_PATH`. The browser test uses a fresh isolated context, blocks
external requests, checks startup/settings/refresh and records screenshots plus
errors in `builds/web-qa/`. It never uses a real account. Inspect those screenshots
as well as the test outcome. A Chromium pass is not a Firefox/Safari pass.

## Following milestones

1. **Connected local alpha:** backend-issued web sessions, web build/version
   handling, same-origin HTTP/WebSocket routing, registration and continuity with
   desktop accounts. Test against explicitly isolated local fixtures.
2. **World demo:** Pallet, Route 1, Viridian and their necessary interiors;
   enforce the allowed destinations server-side on all travel/respawn paths.
   Existing desktop characters outside the area must retain their real position.
3. **AI Sparring:** deliver Gen 5 sprites on demand with bounded caches,
   concurrency limits, missing-sprite fallback and complete form coverage; test
   a battle through to its recorded result. Keep the full team builder.
4. **Social and restrictions:** shared chat, reconnect and background-tab tests;
   enforce ranked exclusion from the issued web session, not just a UI flag or a
   spoofable platform header. Keep sparring teams separate from MMO rewards.
5. **Release candidate:** selected map/asset manifest audit, compressed load size,
   memory/performance measurements, Firefox and Safari checks, production hosting
   design and an explicit promotion/deployment decision.

Reference: [Godot 4.6 web export documentation](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html).
