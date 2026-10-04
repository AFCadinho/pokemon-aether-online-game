# Browser route audit — 2026-10-04

Reviewed the Cloudflare Pages Functions, their configuration, the connected
preview proxy, release packaging and the client callers. This audit starts from
local `development` at `4df730bae`, including the earlier HOME configuration
bridge and forum-news fixes. The publicly checked site still serves v0.3.97.

## Route destinations

| Browser route | Destination | Verification |
| --- | --- | --- |
| `/api/*` | `API_ORIGIN`, with `/api` removed | Both proxies exercise 152 allowed and 32 rejected method/path cases; preserve authorization, query and build identity. |
| `/api/ws/{chat,world-presence,pvp-battle,pve-live,training-live,trade}` | Corresponding gateway WebSocket | Local echo, normal closure and policy rejection checks; Cloudflare forwarding checked with a simulated upstream. |
| `/news.json` | `https://updates.pokeaether.com/data/news.json` | Earlier fix reads the shared five-article feed instead of the browser bucket. |
| `/pokemon-assets/battle/*` | `ASSET_BASE_URL/web/assets/<animated-version>/*` | Public Pikachu metadata and PNG respond 200 for all four front/back/normal/shiny variants. |
| `/pokemon-assets/gen5/*` | `ASSET_BASE_URL/web/assets/<pixel-version>/*` | Public Pikachu metadata and PNG respond 200 for all four variants. |
| `/web/releases/<build>/*` | The same immutable path in `ASSET_BASE_URL` | HOME, login media and runtime assets; range/header checks and filename regression coverage. |
| `/modules/manifest.json`, `/modules/*.pck`, `/web-release-config.json` | Static Pages files from the candidate | Public configuration, manifest and all three map modules respond 200; packaging checks enforce the Pages file limit. |
| Browser audio | Configured release asset origin plus `web/releases/<build>/browser-audio/*` | Production uses R2 directly; preview uses the versioned Pages Function. |

Client gameplay services use the shared `/game/*` API. Browser login and session
restore use `/auth/web/*`; metadata, battle, calculator and WebSocket clients
use the same-origin `/api` base. Rental and Guild helper suffixes are appended
to `/game/rentals` and `/game/guilds`, respectively. Unused Pokémon/team parser
helpers are not currently browser requests; they do not require expanding the
allowlist.

## Additional fixes

1. `POST /battle/weekly-boss` was absent from both proxies, although the world
   client calls it and the gateway exposes it. Added that exact route and
   forwarding tests, including a full-party payload above 16 KiB. Wrong methods
   and additional action suffixes remain rejected.
2. The versioned asset Function rejected spaces and apostrophes in original
   music and move-sound filenames. Public `PRSFX- Tackle.wav` and
   `Kanto Wild Battle.ogg` returned 404 through Pages and 200 directly from R2.
   Allow those filename characters and encode each segment when forwarding.
   The actual Function accepts all 2,359 audio filenames in this task checkout.
   Existing immutable build-ID and traversal checks remain in place.
3. The API's `internal` check inspected the encoded pathname. A simulated
   request to `/game/trades/%69nternal/connections/connected` reached the
   gateway despite the intended restriction. Both proxies now check decoded
   components and reject nested encodings, traversal, backslashes and malformed
   paths. Normal Unicode names remain covered by the allowed-route matrix.

Each new defect was reproduced locally before its fix. These changes and the
earlier HOME/news repairs are local until an authorized publication.

## Validation and limits

- `node tests/web_cloudflare_function_test.mjs`: pass, including the complete
  method/path matrix through the actual Pages handler, upstream headers,
  request-size limits, sprite destinations, news and release-object handling.
- `python -m unittest tests.test_web_connected_proxy
  tests.test_web_preview_server tests.test_package_web_release`: 26 passing
  checks; simulated HTTP upstreams and real loopback WebSocket connections.
- The final connected-proxy check also covers all six WebSocket channels.
- Public probes were read-only GET/HEAD requests. No real account was used,
  no game action was sent, and no production configuration was changed.

This validates route selection and transport, not every gameplay result or a
full authenticated playthrough on the deployed gateway. Cloudflare WebSocket
upgrades were not exercised against a live account. No complete release
certification or production deployment was performed.
