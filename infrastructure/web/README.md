# Browser build

## Production delivery on Cloudflare

The production release is split deliberately. Cloudflare Pages serves the
small HTML and JavaScript loader and its `/api/*` Function. The Godot PCK,
WebAssembly runtime, browser audio and versioned Gen 5 sprite catalogs are
served from the existing R2 bucket through its HTTPS custom domain. Pages has
a 25 MiB per-file limit, so it cannot contain the complete Godot export.

Browser releases use two separate manual workflows so a candidate can be
validated without opening it to players:

1. Run `Build Browser Release Candidate (Preview)` from `main`. It uploads the
   immutable runtime to the dedicated browser bucket, deploys the preview to
   `https://rc.pokeaether-web.pages.dev`, and saves the exact production page
   bundle and manifest as a 30-day GitHub artifact. The preview temporarily
   identifies to the production API as the currently active web build, while
   its runtime assets remain under the new immutable candidate ID. It does not
   replace the production Pages site or `manifest-web.json`.
2. The workflow runs the automated browser and runtime checks. Preview testing
   with a designated test account is optional and useful for release-specific
   investigation; it talks to the live API, so it can change that account's
   saved game state. Do not use a staff or personal account for destructive
   gameplay checks.
3. When the candidate is ready, run `Publish Browser Candidate` with the
   successful preview run ID. It
   verifies the artifact, deploys its matching production page bundle, checks
   the public files, and publishes that same candidate's manifest last. It
   does not rebuild the game, so the tested build ID stays unchanged.

### Retrying a browser release

The candidate workflow has separate `build` and `deploy` jobs. The first checks
the map partition and packaging contracts before installing Godot, then exports
and tests the client. It saves the verified output in
`browser-release-build-RUN_ID` for 30 days. If upload, CORS, sprite publication
or preview deployment fails, use **Re-run failed jobs** (CLI:
`gh run rerun RUN_ID --failed`). The deploy job restores that output and its
original build ID; it does not run Godot again. A completed R2 upload with the
same receipt is reused. An incomplete upload is retried, and a conflicting
immutable receipt stops the job instead of being overwritten.

For a successful candidate, retry **Publish Browser Candidate** with the same
candidate run ID. Publication fixes or newer commits on `main` do not require
rebuilding the frozen game. The publisher checks that the source belongs to its
approved `main` history and that the artifact identifies the exact successful
source run. The selected run determines which game version is published; it
does not automatically publish newer game changes. Pages Functions and their
configuration are restored from that same source commit. New candidates also
record hashes of every production page file, including map modules. Existing
successful candidate artifacts remain supported.

The publisher accepts either the previously active build used for preview or
this candidate when it has already been activated. This makes retries after
manifest publication possible. A different active release or disagreement
between API and update manifest still blocks publication. Activation is polled
for up to three minutes to allow cached version information to converge.
Update-bucket credentials are checked before Pages changes. Cleanup runs only
after activation and its failure does not fail publication. Candidate and
publication workflows share one concurrency group so they cannot change the
browser release at the same time.

The workflow regression tests parse job dependencies and executable commands;
renaming or translating a step label does not invalidate a build. Install their
small dependency with `python3 -m pip install -r tools/web-release-requirements.txt`.

The preview serves large immutable runtime files through a same-origin Pages
Function backed by the browser R2 bucket. This avoids adding the preview domain
to the production bucket's browser CORS allowlist. Production continues to read
those files directly from `web-assets.pokeaether.com`.

The web manifest is different from those runtime files: the production gateway
reads `https://updates.pokeaether.com/manifest-web.json`. The publisher writes
that one small file to the existing updates bucket with the repository-level
`R2_*` credentials already used by desktop and Android publishing. Its final
manifest job has no `web-production` environment, so the environment's
browser-bucket `R2_*` secrets do not override them. The immutable browser
runtime is written to the `pokeaether-web` bucket by the `web-production` job.
The two buckets must not be the same.

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
   access; the `R2_*` keys need object read/write access to the browser bucket.
   The repository-level `R2_ACCOUNT_ID`, `R2_BUCKET`, `R2_ACCESS_KEY_ID` and
   `R2_SECRET_ACCESS_KEY` are used for the existing updates bucket that serves
   `updates.pokeaether.com/manifest-web.json`. Those keys need object write
   access to update manifests. Keep the `web-production` environment's `R2_*`
   secrets scoped to the browser assets bucket.
6. Add Cloudflare rate-limiting rules for `POST /api/auth/web/login` and
   `POST /api/auth/web/signup`. Start with a managed challenge after 10 login
   attempts per minute per client and after 5 signup attempts per hour, then
   tune from observed legitimate traffic. Keep the backend's account gates and
   audit trail authoritative.

The Pages Function forwards only the explicit browser route catalog and rejects
desktop ranked and internal routes. It requires an HTTPS API origin, refuses a
self-referential origin, does not follow upstream redirects and retains the
bounded request sizes used by the local connected preview. WebSocket upgrades
for chat, world presence, trading and PvP-room transport pass through the same origin.

Cross-browser and full gameplay checks in Chrome, Firefox and Safari are
optional release diagnostics, not a publication gate. Use them when a change
has browser-specific risk or when automated checks point to a problem. The
publisher still verifies the candidate identity, active build compatibility,
required bucket configuration, deployment and public files before it publishes
the manifest.

Rollback is manifest-based: republish the retained previous
`manifest-web.json`, then verify `/auth/web/login` accepts its build ID. Pages
deployments can also be rolled back in Cloudflare. Immutable R2 releases remain
available for rollback and should only be pruned by a separate retention task.

This is a real WebAssembly export of the existing Godot 4.6 client, using the
`Web Local Preview` preset and the Compatibility renderer only for web. Desktop
renderer settings are preserved. The output belongs in `builds/web/` and is not
committed. No second Godot project or duplicate source asset tree is created.

## Current scope

The browser uses the same gameplay endpoints, account state and interface as
native clients. Trading, Lending, Aether Exchange, Guild Bank and sending or
claiming mail attachments are available through the shared `/game/*` API.
Trading invitations and reconnects use `/ws/trade` through both browser proxies.
The account service still validates permissions, ownership, funds, party limits,
reservations, consent and feature rollout gates. Internal service routes are
not exposed through the browser proxy.

Registration retains the existing legal acceptance, registration toggle and
email-verification flow. Remembered sessions use browser localStorage;
otherwise sessionStorage retains the session only in this tab (including
refresh). Logout clears both. Only the token, expiry and remember choice are
stored, never a password or account profile. The server revalidates every
restored session. Temporary restore network failures preserve storage;
expired/revoked/forbidden sessions clear it.

The server issues `session_type=web` independently of client headers. Web login
rotates only other web sessions; desktop login rotates only desktop sessions.
Web logout does not cancel desktop queues. Gameplay and asset transfers accept
both session types; browser-specific authentication endpoints retain their
session-type checks. Legacy `/auth/web` gameplay aliases remain for older
clients rather than duplicating transfer routes for the current client.

The current browser uses the shared `/game/world` access and transition routes.
Its map modules cover the current Kanto catalog beyond Cerulean, including
Route 5, Route 9 and Cerulean Cave; canonical story and area requirements apply.
Transition, Aethernet travel and saved-map restoration prepare the required
map module before entering that map. Aether Clash retains its normal rules
against trading or lending inside the duel arena.

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
ops/worktrees/slot-env slot-b -- python3 .worktrees/slot-b/frontend/tools/build_web_asset_modules.py
python3 .worktrees/slot-b/frontend/tools/serve_web_preview.py
```

Open `http://127.0.0.1:8060` and click **Play now**. Use
`--port 8061` if that port is occupied. The server binds only to 127.0.0.1, serves
only the generated export, and does not log request URLs or bodies.

The core export includes Pallet Town through Pewter City plus the Aether Clash
Lobby. Waiting Area, Guild Duel and Battle Royale maps live in the separately
hashed `modules/aether-clash-maps.pck`; the web client verifies and mounts that
pack before it creates or accepts a Clash or enters an arena portal.
The 16 maps from Route 3 through Misty are separately exported to
`modules/kanto-through-misty-maps.pck`. They are verified and mounted before a
transition, Cerulean teleport or saved-location login needs them. The normal
module builder produces both packs and one manifest; the initial core stays small.
The preset retains its historical `Web Misty Maps Trial` name, but its pack is
now included in the normal browser build pipeline.

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

The preview workflow normally enforces the 312 MiB limit. For an explicitly
approved, one-release exception, its manual dispatch can allow a payload up to
328 MiB and requires an audit reason; the build receipt records that reason and
the exception ceiling. The normal limit stays at 312 MiB, and a payload above
328 MiB still fails. The candidate must still pass the regular automated preview
checks before publication.

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
as well as the test outcome. This fixture is an automated focused regression
check; optional Firefox/Safari testing can be used when investigating a
browser-specific change.

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
  settings. Validate real delivery when changing those flows; the full manual
  browser matrix is optional.

## Release boundary

Accounts, the bounded world, AI Sparring, on-demand Gen 5 sprites and browser
social access are implemented. Production activation still requires the
one-time Cloudflare configuration and successful automated candidate and
public asset checks.
Expanding the world boundary or enabling ranked play is a separate product and
security decision.

Reference: [Godot 4.6 web export documentation](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html).
WebSocket proxy API: [websockets 16 client documentation](https://websockets.readthedocs.io/en/16.1/reference/asyncio/client.html).


## On-demand startup assets

All browser music, cries and sound effects are served as raw files under
`browser-audio/`; their native/imported audio resources are excluded from the
web PCK. Before export the build generates `generated/browser_audio_catalog.json`
from the copied files. Cry/form resolution and animation availability use this
catalog on web rather than requiring bundled AudioStream resources. Native
clients retain the existing audio resources and mixer. The build rejects raw
or imported audio that accidentally gets embedded again.

The normal browser export excludes both HOME image directories and the login
OGV from the initial PCK. `build_web_preview.py` prepares `home-icons/` with a
case-sensitive normal/shiny catalog and content-hashed PNG filenames. Existing
HOME source archives remain the source of these assets; the browser fetches
individual PNGs rather than downloading or opening a whole ZIP. The placeholder
is bundled as `assets/ui/home_unknown.png`. Shared mutable textures refresh the
current UI in place; downloads are coalesced and limited to four concurrent
requests, and each memory cache retains at most 256 entries. Conservative RGBA estimates
also cap retained UI textures at 32 MiB and decoded images at 16 MiB; displayed
textures remain valid when evicted from the cache. Pokédex list icons
start loading only when their rows intersect the visible scroll area.

FFmpeg is required for web builds. It prepares `login-media/world.mp4` (H.264,
CRF 18, source resolution/frame rate, full length, no audio, faststart) and a
high-quality first-frame WebP poster. This prioritizes image quality; the
streamed video can be larger than the source OGV. It is not part of the startup
size budget. The native browser video plays behind the transparent login UI,
including fullscreen, pauses when the tab is hidden, and releases its source
when the login scene exits. Native clients keep playing the original OGV.

Packaging places HOME images, their catalog, and login media in the immutable
release R2 payload. Browser requests use `/web/releases/<build-id>/...` on the
Pages origin, whose existing function forwards range/cache headers to R2.
These changes are local until the usual separately authorized candidate
publication; no existing bucket objects need overwriting.

Focused checks include `web_home_icon_service_check.gd`,
`web_login_background_check.gd`, the Python export/packaging tests, fullscreen
smoke, and browser startup assets with
`POKEAETHER_STARTUP_ASSETS_ONLY=1` in `web_accounts_browser_smoke.cjs`.


Local comparison (2026-09-30, slot B, Godot 4.6.2): changing only the web
resource-selection preset on the same source/import cache reduced PCK payload
from 285.87 to 168.90 MiB. With the same engine and shell files, startup is
approximately 322.33 to 205.36 MiB (116.97 MiB, 36.3% less, before HTTP
compression). These figures exclude on-demand transfers and do not measure RAM.
The world-login smoke also found a pre-existing 3D sparkle preload under the
excluded `tools/` tree; its runtime copy now lives under `assets/battles/effect`.

Removing the duplicate audio resources on the same slot build reduced initial
payload from 205.4 to 167.5 MiB (about 37.9 MiB). The generated availability
catalog is included; sound downloads remain outside that initial figure.
Focused audio checks cover PCK exclusion, native animation timing and resource
lifetimes, native Mega Evolution, browser login/world entry, and actual browser
playback of music, an OGG cry, a battle WAV and the notification MP3.

The full-world map partition is listed in `docs/browser-full-world-scope.json`:
22 core maps (including the Aether Clash Lobby), 16 maps in the Misty module,
and 30 later Kanto maps in `kanto-extended-maps`. The extended module also
contains interiors, connecting gates, Underground Path, Diglett's Cave, both
Rock Tunnel floors and all three Cerulean Cave floors. Empty/unimplemented
catalog scene paths are not turned into playable maps. Transition and Aethernet
travel prepare the requested map module before committing travel; saved-map
restoration loads it before opening the world. Trading, Lending, Aether Exchange,
Guild Bank and mail attachments now use the same account-authorized game API
as the native client; `/ws/trade` also passes through both browser proxies.
Account permissions, ownership checks, reservations and feature rollout gates
remain authoritative. Legacy `/auth/web/world` demo
endpoints retain their compatibility scope and are not used by this client.

Local export after partitioning all later maps: initial 162.7 MiB; extended
module 9.7 MiB. Focused checks cover the complete current Kanto scene catalog,
actual module contents and audio exclusion, shared browser area access and
Cerulean Cave progression, plus Chromium login and
map restoration on Route 5, Vermilion City and Rock Tunnel 1F. No live release
has been published. New Kanto scenes missing from the partition fail the build.
