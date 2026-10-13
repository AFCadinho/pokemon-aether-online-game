# Aethering at Route 5 Daycare

The Aether Researcher opens `AetheringPopup`; the Wing Merchant uses the existing
`MarketAttendantNPC` and named market flow. The server contract is documented
in the paired backend's `docs/aethering_backend.md`.

The picker uses the authenticated read-only `/game/aethering/candidates`
projection rather than trying to infer protected origins from client snapshots.
Party/PC filtering, search, shared Egg Groups and protection reasons are shown.
Eligible donors sort first, then matching 31/0 IVs, other matches and perfect
stats. This sort changes no gameplay rules. Preview/confirmation recheck all
server eligibility and resources; the picker is advisory.

Lock choices invalidate the preview. Each Pokémon has at most one optional lock,
with the other Pokémon's lock stat disabled. The comparison shows only existing
IVs until a server preview arrives; no client roll or mutation is generated.

The irreversible confirmation states the donor loss, recipient retention,
possible IV gains/losses, Wing count and 10,000 fee. A shiny donor additionally
requires an acknowledgement checkbox. One pending receipt is saved per account
before HTTP confirmation; transport failures, server errors, auth expiry and
retryable conflicts retain exactly the same preview/request UUIDs. Pending
confirmation blocks another selection until resolved. Responses from an older
login are not applied to a new account. A process restart restores the receipt
when that account opens the NPC again.

Results display actual IV changes, refresh normal party/inventory/wallet reads,
invalidate PC caches and keep the recipient selected. The Next Donor action
opens the existing in-popup picker. Quantity-only audit receipts are not Bag
metadata. If refresh fails, the result remains visible and another preview is
blocked until refresh succeeds.

The popup follows the current UI window layer and movement-blocking lifecycle.
Its scroll area fits the viewport, buttons have at least 44 design pixels of
height, and locked comparisons remain adjacent. Native Android inherits the
existing WindowFit/UI scale; no new device-specific mutation path exists.
English, Dutch and Brazilian Portuguese instructions, errors and Wing tooltips
follow the current localization catalogs. Chinese catalogs retain parity too.

## Focused checks

Run Godot only through the workspace `ops/worktrees/slot-env` wrapper:

- `godot --headless --path FRONTEND --script tests/aethering_ui_check.gd`
- Existing market, localization, storage and Route 5 checks under `tests/`.
- `tests/aethering_end_to_end_check.gd` against the backend's isolated
  `tests.aethering_daycare_fixture_app:app`, with `POKEAETHER_GATEWAY_URL` pointing
  at its localhost HTTP port. The fixture requires disposable PostgreSQL through
  `AETHERING_TEST_POSTGRES_URL`; run isolated runtime work with `runtime-lock`.

The HTTP integration test buys all six Wings with an active Blessing, previews
Party/PC Pokémon, confirms a shiny donor, recovers a deliberately lost committed
response and an expired-auth retry, checks one charge/audit, then rejects a stale
preview without a second consumption. A graphical run also exports desktop and
compact-viewport screenshots under `/tmp`. The fixture replaces authentication
and unrelated read dependencies; it does not exercise production login, gateway
deployment, physical Android touch input or a player walking through the map.
