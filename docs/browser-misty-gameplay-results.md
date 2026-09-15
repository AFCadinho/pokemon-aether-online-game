# Misty browser gameplay review — 2026-09-15

This review uses the real integration WebGL preview on `127.0.0.1:8061`
and canonical account-service HTTP handlers against a disposable SQLite fixture.
HTTP authentication and story progression are exercised; WebSocket presence and
authorized map travel are fixture transports. Existing accounts and the shared
backend database are not changed.

## Corrections found during active review

- Twelve existing Misty visual directories still contained oversized atlas
  chunks. Reimporting them into lossless chunks no larger than 4096 × 4096 fixes
  missing floors/walls in the actual browser. The rebuild tool compares every
  used tile's pixels, position, layer and transformation against its original:
  all twelve rebuilds passed pixel identity.
- The editor's placeholder Player House started NPC requests while the optional
  map pack was loading. Browser startup now removes that placeholder before
  its children enter readiness and pauses player processing until the actual
  saved map is ready. Desktop startup is unchanged.
- Visual reimports now construct a fresh tileset instead of applying old atlas
  rows to already-overwritten texture pages.

## Focused evidence

- `web_misty_gameplay_smoke.cjs`: Bill's meeting, computer/cell separator,
  restored human Bill, S.S. Ticket and 100 Aetherite complete through the browser
  UI. The quest advances to challenging Cerulean Gym.
- The final repeat opens all sixteen added maps in the active world, including
  NPC initialization, camera setup and acknowledged authorized travel. It
  passes with no captured runtime errors/warnings or external HTTP traffic.
  The Misty pack downloads once and is reused for subsequent map changes.
- The scoped atlas probe checks all twelve visual maps, valid atlas cells,
  the 4096-pixel ceiling and disabled placeholder-player processing.
  Autosave is unavailable without a map and becomes available with the owned
  canonical map. The existing first-gym contract check also passes.
- Texture storage validation passes for all 324 generated textures, using
  lossless `PortableCompressedTexture2D` storage.
- TMX visual importer, Bill runtime transition and Cerulean gym trainer checks
  pass. The latter native checks retain existing shutdown resource-leak warnings.
- The isolated browser-fixture protocol unit test passes, including all sixteen
  Misty map definitions and canonical pending-teleport acknowledgement state.
- Integration exports: initial core 300.9 MiB before HTTP compression; rebuilt
  optional Misty pack approximately 24.6 MiB, within its 32 MiB limit.

## Acceptance boundary

This is focused active-map/cutscene evidence, not a complete playthrough.
Every door/ladder, wild encounters/capture, trainer battles and Misty's actual
battle/reward still need end-to-end gameplay acceptance against the real battle
runtime. Automated map review suppresses automatic trainer starts and uses
authorized fixture travel rather than walking every connection.

Chromium runs at 1440 × 900 with software WebGL. Recorded JavaScript heap and
DOM metrics do not measure total Wasm/GPU memory or certify lower-memory devices.
No production access, full paired certification, promotion or release is implied.
