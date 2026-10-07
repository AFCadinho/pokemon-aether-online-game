# Adventure Party team status — 2026-10-07

Adventure Party now presents two battle sides, with stable rows for up to two
Trainers on each side. The shared VS header reuses the existing panel style;
ordinary single PvP retains its timer presentation. Co-op has no decision clock
or new deadline. Animation duration, turn authority and settlement remain intact.

## Presentation contract

`BattleVsPanelContainer.show_team_status(left, right)` accepts arrays of public
Trainer records: `name`, optional `local`, and optional `state`. Supported states
are choosing, switching, sending, checking, ready, waiting, confirming, playing,
connecting, disconnected and finished, plus pending/ready next-choice states
when the local client is still showing an earlier turn. No selected attack or target is exposed
through this contract. Empty rows preserve the panel height; long names truncate
with a full-name tooltip. Text is translated in English, Dutch, Brazilian
Portuguese and Simplified Chinese.

The live Adventure Party adapter maps p1/p3 to the allied side and presents one
NPC/wild name on the opposing side without invented readiness. A four-Trainer
fixture covers the future 2-vs-2 layout. Actual four-player PvP matchmaking,
protocols and timers are not implemented by this change.

Partner choice acceptance comes from the existing `partnerReady` projection;
connection status comes from `partnerConnected`. These do not reveal a partner's
local animation progress. Own readiness requires a confirmed current-decision
submission: `locked` alone can also mean no local action is required. A choice
in flight displays Sending and cannot be retried concurrently. An uncertain
submission retains its idempotency key and exposes the existing durable retry.
A reset, reservation change or acknowledgement invalidates late replies.

Playback is established before the next decision controls appear. Final playback
has priority over the saving label; automatic world return displays team refresh
and return status without adding a player confirmation or a partner-ack barrier.

## Focused validation

- `coop_team_status_check.gd`: real native scene, p3 ownership, partner readiness,
  disconnect, forced switch, in-flight/uncertain choice, final playback, stable
  row identity, all four languages and 1280x720/1600x900/1920x1080 layouts. An
  isolated service fixture checks concurrent retry prevention, same-key recovery,
  next-turn readiness reset and stale replies after reset.
- Existing PvP timer visibility, co-op presentation, gameplay, immersive doubles
  layout and 3D doubles HUD checks.
- OpenGL screenshots of choosing, waiting and four-Trainer presentation.
- Catalog JSON and placeholders checked for all added translation keys.

Tests use fixtures, not two authenticated production clients. Deployment requires
a new gameclient build; no backend release is needed for these status indicators.

The extended gameplay check passes its assertions and exits 0, but reports
ObjectDB leaks and five resources still in use at shutdown. The same check run
with the pre-change scripts and fixture (base `7e9c9e2f`) reports the identical
shutdown warnings and also exits 0. The immersive doubles check has a shutdown
ObjectDB warning as well; this task does not repair the animation/resource
lifecycle. The 3D fixture now mounts its test actor before querying world-space
visual bounds, avoiding a fixture-only out-of-tree transform error.
