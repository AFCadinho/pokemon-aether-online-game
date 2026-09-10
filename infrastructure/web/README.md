# Local browser build — phase 5

This is a real WebAssembly export of the existing Godot 4.6 client, using the
`Web Local Preview` preset and the Compatibility renderer only for web. Desktop
renderer settings are preserved. The output belongs in `builds/web/` and is not
committed. No second Godot project or duplicate source asset tree is created.

## Current scope

The browser can open the existing login screen, render the player preview, open
settings and switch languages. A click starts the engine and unlocks browser
audio. Refresh does not trigger the desktop interrupted-session warning.

Phase 3 connects real shared accounts and a bounded browser-world position through dedicated `/auth/web` endpoints.
Registration retains the existing legal acceptance, registration toggle and
email-verification flow. Login and refresh open an account card, not the world.
Remembered sessions use browser localStorage; otherwise sessionStorage retains
the session only in this tab (including refresh). Logout clears both. Only the
token, expiry and remember choice are stored, never a password or account profile.
The server revalidates every restored session. Temporary restore network failures
preserve storage; expired/revoked/forbidden sessions clear it.

The server issues `session_type=web` independently of client headers. Web login
rotates only other web sessions; desktop login rotates only desktop sessions.
Web logout does not cancel desktop queues. All existing authenticated gameplay
and ranked routes reject web tokens by default. No character position is read or
written; existing characters outside the future demo remain where they were.
Background trade, guild, thieving and Rock Smash discovery are disabled on web.

The client uses the page's origin plus `/api`, never the desktop production
fallback. News polling and password-reset links remain disabled. The shell only
starts on loopback hosts. This is not the complete MMO demo or a public release.

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
are needed for this single-threaded build.

### Connected preview

The original `serve_web_preview.py` still offers a completely disconnected
visual preview on port 8060. For accounts, use the separate explicit local proxy:

```sh
python3 -m venv .worktrees/slot-b/web-preview-venv
.worktrees/slot-b/web-preview-venv/bin/pip install -r .worktrees/slot-b/frontend/tools/web-preview-requirements.txt
.worktrees/slot-b/web-preview-venv/bin/python .worktrees/slot-b/frontend/tools/serve_web_connected.py --upstream http://127.0.0.1:8000
```

Open `http://127.0.0.1:8061`. The normal integration gateway must already run
the paired phase-2 development source; the proxy does not start/reconfigure a
backend or enable account creation/mail. It only allows an explicit
`http://127.0.0.1:PORT` target. No production target, environment proxy, redirect
following, arbitrary API access or forwarded authority headers are allowed.
HTTP requests are restricted to account endpoints and public status; the
`/api/ws/chat` tunnel maps to `/ws/chat` and preserves gateway authentication.
Web chat itself is still denied until the social capability is implemented.
The proxy disables access logs because WebSocket URLs may contain tokens.

Do not start a slot backend beside the normal Compose stack. The automated
account browser test below needs neither: real FastAPI account routes run via
TestClient/ASGITransport against in-memory SQLite over a private subprocess pipe.
Only test registration emails are verified through the in-memory test outbox.
No real mail is sent and no application workers or database port are started.

`builds/web/build-receipt.json` records the engine version, source commit,
tracked dirty-state, hashes and uncompressed transfer sizes. This makes a build
identifiable without including user settings, sessions, or credentials.

## Asset selection

The preset includes the shared client code, all player appearance assets, the
nine interiors/exteriors reachable inside the three-map demo, localization and
the complete regular/shiny HOME sprite collection. AI Sparring therefore has a
static visual fallback for every available Pokemon and form. The full animated
Gen 5 collection is deliberately excluded: in this checkout it is about 1.1 GiB
before Godot export and is not a viable initial browser download. A later
on-demand asset delivery phase can add those animations without blocking play.

Generated demo-map textures are stored as self-contained, lossless compressed
resources. This preserves their pixels and works on desktop and Web without
duplicating the project. The build command verifies required/excluded pack
markers and rejects an initial payload above 300 MiB. Phase 5 is 285 MiB before
HTTP compression, down from the phase-4 baseline of 559 MiB while adding the
static battle sprite catalog.

## Focused validation

```sh
python3 -m unittest discover -s .worktrees/slot-b/frontend/tests -p test_web_preview_server.py
ops/worktrees/slot-env slot-b -- godot --headless --path .worktrees/slot-b/frontend --script res://tests/web_runtime_check.gd
node .worktrees/slot-b/frontend/tests/web_preview_browser_smoke.cjs
POKEAETHER_TEST_PYTHON=/absolute/path/to/account-test-python node .worktrees/slot-b/frontend/tests/web_accounts_browser_smoke.cjs
```

The last command requires Playwright. An existing installation can be used via
`NODE_PATH`; a locally installed Chromium binary can be supplied via
`POKEAETHER_CHROME_PATH`. The browser test uses a fresh isolated context, blocks
external requests, checks startup/settings/refresh and records screenshots plus
errors in `builds/web-qa/`. It never uses a real account. Inspect those screenshots
as well as the test outcome. A Chromium pass is not a Firefox/Safari pass.

The account browser test uses the disconnected static server at port 8060 and
intercepts only `/api` requests into the paired test fixture. It covers browser
registration, test-email verification, Godot login, remembered and tab-only
refresh, and logout. Screenshots and non-sensitive route/status evidence go to
`builds/web-accounts-qa/`. It rejects any world or external request. It does not
prove SMTP delivery, PostgreSQL concurrency or the full deployed gateway stack.

Using a Python environment with `tools/web-preview-requirements.txt`, run
`python -m unittest discover -s tests -p test_web_connected_proxy.py` from the
frontend. This covers local-target/Host/Origin guards, path and header filtering,
redirect/failure handling and a real loopback WebSocket roundtrip and closure.
Backend focused suites: `tests.test_web_sessions`,
`tests.test_auth_email_security`, `tests.test_impersonation_sessions` from
`account-service`, and `tests.test_client_version` from `gateway`.

### Remaining release requirements

- The web build has a separate `web-preview-2` ID (overridable by
  `application/config/web_build_id`) and uses the `web` manifest platform.
  No web manifest has been published. The existing gateway manifest-unavailable
  fail-open policy is unchanged; publish and verify an immutable web manifest
  before a release, with reload-oriented update messaging.
- Browser storage can be unavailable or cleared by privacy settings. Tokens are
  JavaScript-readable, as required by this Godot bearer client. Before public
  hosting, review XSS/CSP, HTTPS, session design and edge auth rate limits.
- Registration uses the existing email URLs and operational email settings.
  Real email delivery, password reset, browser compatibility and hosting are
  later explicit integration/release checks, not silently enabled here.

## Following milestones

1. **Connected local alpha (phase 2, implemented):** server-issued web sessions,
   version platform, same-origin proxy, registration and account continuity.
2. **World demo:** Pallet, Route 1, Viridian and their necessary interiors;
   enforce the allowed destinations server-side on all travel/respawn paths.
   Existing desktop characters outside the area must retain their real position.
3. **AI Sparring:** deliver Gen 5 sprites on demand with bounded caches,
   concurrency limits, missing-sprite fallback and complete form coverage; test
   a battle through to its recorded result. Keep the full team builder.
4. **Social:** explicitly authorize shared chat, reconnect and background-tab
   behavior while retaining server-side ranked exclusion. Keep sparring teams
   separate from MMO rewards.
5. **Release candidate:** selected map/asset manifest audit, compressed load size,
   memory/performance measurements, Firefox and Safari checks, production hosting
   design and an explicit promotion/deployment decision.

Reference: [Godot 4.6 web export documentation](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html).
WebSocket proxy API: [websockets 16 client documentation](https://websockets.readthedocs.io/en/16.1/reference/asyncio/client.html).
