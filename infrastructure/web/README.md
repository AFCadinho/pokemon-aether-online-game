# Browser build

## Production delivery on Cloudflare

The production release is split deliberately. Cloudflare Pages serves the
small HTML and JavaScript loader and its `/api/*` Function. The Godot PCK,
WebAssembly runtime, browser audio and versioned Gen 5 sprite catalogs are
served from the existing R2 bucket through its HTTPS custom domain. Pages has
a 25 MiB per-file limit, so it cannot contain the complete Godot export.

The manual `Deploy Browser Game to Cloudflare` workflow builds and validates
both halves. It uploads immutable R2 objects first, deploys Pages second, checks
the public URLs and publishes `manifest-web.json` last. Leave
`publish_manifest` disabled for the first staging deployment. Enabling it opens
the exact build through the existing gateway client-version gate. Failed runs
before that final step do not change the active browser release.

One-time Cloudflare setup:

1. Use the Direct Upload Pages project `pokeaether-web`, with production branch
   `main`, and attach `play.pokeaether.com` (or change the workflow inputs and
   `wrangler.jsonc` together).
2. Set `API_ORIGIN=https://api.pokeaether.com` and
   `ASSET_BASE_URL=https://web-assets.pokeaether.com` for Pages production.
   Preview deployments must not publish the production web manifest.
3. Use the dedicated `pokeaether-web` R2 bucket through its HTTPS custom domain
   `web-assets.pokeaether.com`. Do not use the development `r2.dev` URL or the
   desktop update bucket for browser output. The workflow reads its immutable
   source archives from `https://updates.pokeaether.com` and publishes only the
   extracted browser catalogs and web runtime to this dedicated bucket.
4. Apply the read-only browser CORS policy in
   `infrastructure/web/r2-cors.example.json` to the web bucket. Do not add other
   browser origins unless they are intentionally supported. Purge the R2 custom
   hostname cache once after changing CORS so cached objects receive the new
   headers.
5. Add `CLOUDFLARE_API_TOKEN`, `R2_ACCOUNT_ID`, `R2_BUCKET`,
   `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY` to the GitHub
   `web-production` environment, with `R2_BUCKET=pokeaether-web`. Protect that
   environment with an approval rule. The Cloudflare API token needs Pages edit
   access; the R2 keys need object read/write access to the selected bucket.
6. Add Cloudflare rate-limiting rules for `POST /api/auth/web/login` and
   `POST /api/auth/web/signup`. Start with a managed challenge after 10 login
   attempts per minute per client and after 5 signup attempts per hour, then
   tune from observed legitimate traffic. Keep the backend's account gates and
   audit trail authoritative.

The Pages Function forwards only the explicit browser route catalog and rejects
desktop ranked and internal routes. It requires an HTTPS API origin, refuses a
self-referential origin, does not follow upstream redirects and retains the
bounded request sizes used by the local connected preview. WebSocket upgrades
for chat, world presence and PvP-room transport pass through the same origin.

Before setting `publish_manifest=true`, verify Chrome, Firefox and Safari on
the public custom domain. Complete registration and email verification, world
entry and transitions, a wild battle including catch/run, a trainer battle, a
complete AI Sparring battle, refresh during each state, logout, session expiry,
background-tab reconnect and simultaneous desktop/browser use. Record cold and
warm load time, transferred bytes, peak memory and API/WebSocket failures. The
current automated Chromium fixture remains a focused regression check and does
not replace this release-candidate matrix.

Rollback is manifest-based: republish the retained previous
`manifest-web.json`, then verify `/auth/web/login` accepts its build ID. Pages
deployments can also be rolled back in Cloudflare. Immutable R2 releases remain
available for rollback and should only be pruned by a separate retention task.

This is a real WebAssembly export of the existing Godot 4.6 client, using the
`Web Local Preview` preset and the Compatibility renderer only for web. Desktop
renderer settings are preserved. The output belongs in `builds/web/` and is not
committed. No second Godot project or duplicate source asset tree is created.

## Current scope

The browser demo uses the existing account, world and interface. Its opening
world is bounded to Pallet Town, Route 1 and Viridian City. Mail, friends, bag,
guild browsing, replays, Custom battles and AI Sparring remain visible; ranked,
competitive guild actions, Aether Exchange and My Powers require the client.

Phase 3 connects real shared accounts and a bounded browser-world position through dedicated `/auth/web` endpoints.
Registration retains the existing legal acceptance, registration toggle and
email-verification flow. Login and refresh restore the bounded browser world.
Remembered sessions use browser localStorage; otherwise sessionStorage retains
the session only in this tab (including refresh). Logout clears both. Only the
token, expiry and remember choice are stored, never a password or account profile.
The server revalidates every restored session. Temporary restore network failures
preserve storage; expired/revoked/forbidden sessions clear it.

The server issues `session_type=web` independently of client headers. Web login
rotates only other web sessions; desktop login rotates only desktop sessions.
Web logout does not cancel desktop queues. Existing desktop-only and ranked
routes reject web tokens by default. Browser movement uses the canonical
character state through server-owned map and transition allowlists; an existing
character outside the demo remains there and is refused browser-world entry.
Background trade, guild notifications, thieving and Rock Smash discovery are disabled on web.

The client uses the page's origin plus `/api`, never the desktop production
fallback. Pages proxies the approved API/WebSocket routes and same-origin news;
password recovery opens the existing HTTPS account flow. An unconfigured export
only starts on loopback. `package_web_release.py` injects the immutable release
configuration that permits the production host.

## Build and inspect

For normal local use, run the convenience launcher from the frontend checkout:

```sh
./run_web_local.sh
```

It builds the browser client, opens the local URL and automatically uses the
connected preview when the integration gateway is reachable on
`http://127.0.0.1:8000`. Otherwise it starts the offline preview. Use
`./run_web_local.sh --connected` to require accounts and online gameplay,
`--offline` for the standalone preview, or `--skip-build` to reuse the current
export. The first export can take several minutes and reports Godot's current
phase and percentage in the terminal. The connected mode creates a pinned virtual environment below
`builds/`; it never targets production.

From the `game` workspace, for the assigned slot (example: slot-b):

```sh
ops/worktrees/slot-env slot-b -- python3 .worktrees/slot-b/frontend/tools/build_web_preview.py
python3 .worktrees/slot-b/frontend/tools/serve_web_preview.py
```

Open `http://127.0.0.1:8060` and click **Open browser game**. Use
`--port 8061` if that port is occupied. The server binds only to 127.0.0.1, serves
only the generated export, and does not log request URLs or bodies.

The assigned slot needs Godot's matching `web_nothreads_release.zip` export
template installed in its own XDG data directory. This is engine tooling, not a
copy of another checkout's caches. The local preview servers send COOP/COEP
headers so Godot's WebAudio worklet mixer can use its shared-memory path; any
future public host must send those headers too.

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
interiors/exteriors reachable inside the three-map demo, its login, Pallet Town,
Route 1, Viridian City, Oak's Lab, Pokémon Center, wild-battle and trainer-battle
music, localization and the lightweight UI, item-icon, gender, badge and battle-indicator collections. The full animated
Gen 5 collection is deliberately excluded: in this checkout it is about 1.1 GiB
before Godot export and is not a viable initial browser download. A later
on-demand asset delivery phase can add those animations without blocking play.

Generated demo-map textures are stored as self-contained, lossless compressed
resources. This preserves their pixels and works on desktop and Web without
duplicating the project. The build command verifies required/excluded pack
markers and rejects an initial payload above 312 MiB. The audio-complete browser
demo is expected to be about 303 MiB before
HTTP compression, down from the phase-4 baseline of 559 MiB while adding the
static battle sprite catalog.

Phase 7 serves the optional Gen 5 sheets separately under
`/pokemon-assets/gen5/`. The browser build never embeds that 1.1 GiB source
collection: battle and detail views show their HOME fallback immediately, fetch
only the required front/back/shiny sheet and metadata, then retain those files
through the browser's immutable HTTP cache. Party and Pokédex result lists keep
using HOME icons so browsing never triggers bulk animation downloads.

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
registration, test-email verification, Godot login, world entry and a complete
AI Sparring turn with an isolated catalog team. Screenshots and non-sensitive
route/status evidence go to
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

- The web build uses a separate immutable build ID and the `web` manifest
  platform. The deployment workflow creates the manifest and publishes it only
  after R2, Pages and public URL checks pass. No production web manifest is
  published merely by merging this source.
- Browser storage can be unavailable or cleared by privacy settings. Tokens are
  JavaScript-readable, as required by this Godot bearer client. Before public
  hosting, review XSS/CSP, HTTPS, session design and edge auth rate limits.
- Registration and recovery use the existing email URLs and operational email
  settings. Real delivery and the browser release-candidate matrix remain
  explicit checks before the manifest is opened to players.

## Release boundary

Accounts, the bounded world, AI Sparring, on-demand Gen 5 sprites and browser
social access are implemented. Production activation still requires the
one-time Cloudflare configuration and public release-candidate checks above.
Expanding the world boundary or enabling ranked play is a separate product and
security decision.

Reference: [Godot 4.6 web export documentation](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html).
WebSocket proxy API: [websockets 16 client documentation](https://websockets.readthedocs.io/en/16.1/reference/asyncio/client.html).
