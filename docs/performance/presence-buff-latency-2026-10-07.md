# Presence visuals and startup buffs, 2026-10-07

## Scope

Follow-up to the startup latency work. Desktop arena preparation and battle
entry/recovery retain their existing wait boundaries. No production access,
publishing, deployment or release certification is part of this task. Both the
client and account service need release updates for the combined read.

## Remote avatars

WorldPresenceService still polls packets, handles pong timestamps, and applies
all authoritative roster messages and revision checks in order. World now
queues only avatar rendering. The visual child processes after the realtime
autoloads (process priority 100), with a 2,000 microsecond cooperative budget and
a 32-operation cap per frame. A single avatar operation cannot be preempted and
can exceed that budget; subsequent operations wait until another frame. Avatar
ordering is updated once per processed batch instead of once per new avatar.

The queue keeps the latest pending visual state per user. A leave cancels a
pending spawn; a subsequent rejoin replaces the removal. Fresh snapshots replace
pending visuals and remove already displayed users absent from the snapshot.
World map/account cleanup clears the queue, including the same-map teleport
roster restoration path. Battle activity and other authoritative gameplay
messages are not deferred or coalesced.

The functional probe sends a real loopback WebSocket snapshot and pong through
the production presence service and World handlers. Its renderer fixture costs
5 ms per avatar. It checks that the authoritative roster and pong receipt are
available before any of the 24 avatars render, and that the visual budget stops
after the first costly operation. This is a synthetic boundary check, not an
Internet-ping or production-performance forecast. A crowded roster can take
several frames to appear; individual expensive avatar construction can still
cause a frame hitch.

## Global buffs

`GET /game/global-buffs` returns five typed boost states plus the personalized
heal state. It uses the existing game authentication/maintenance gate once. The
boost states and configured goals share one settings query; heal retains its
existing per-user seen/accepted-event filtering and adds one settings query.
Existing boost contribution and heal activation/acceptance APIs are unchanged.
No global heal recipient lists or raw settings enter the response.

A real FastAPI/SQLite fixture verifies identical values against all six old
reads. With default settings, the six reads use six authentications and eleven
AppSetting queries; the combined read uses one authentication and two queries.
These counts do not represent the complete route SQL budget or a measured
production RTT reduction.

HUD startup uses one combined GET. Only an HTTP 404 triggers compatibility reads
against the old backend, sequentially instead of a simultaneous burst. Other
failures, invalid combined payloads and account/session changes do not trigger
that fan-out. Successful legacy entries remain independently usable. Requests
and HUD application are bound to the initiating account and session. A late
startup response cannot replace a newer boost or heal state already received by
that HUD. Explicit refreshes and mutation responses continue using existing APIs.

The request is deferred and does not gate world or battle entry. Older clients
remain supported by the backend; newer clients retain a 404 fallback until the
backend endpoint is deployed. Actual startup time and ping effects need a new
client build and a new production measurement.

## Focused verification

Backend: 8 snapshot route tests, 12 boost service tests, 9 heal service tests,
and 13 game-settings tests passed (42 total). Each suite runs in a separate
Python process, following the existing boost-suite isolation convention. Loading
the route fixture and old Base.metadata.create_all suites in one Python process
exposes an existing missing-table registration dependency; isolated suites pass.

Frontend: 14 distinct focused checks passed under Godot 4.6.2 headless/dummy:

- global_buffs_startup_check and remote_player_visual_queue_check;
- world_presence_roster_check and presence_packet_budget_check;
- remote_player_ordering_performance_check and web_gameplay_readiness_check;
- global_heal_dialog_runtime_check, global_buff_notification_cards_check and
  global_heal_check;
- wild_entry_before_response_check, trainer_entry_before_response_check and
  world_activity_recovery_check;
- startup_lazy_popups_check and startup_request_reuse_check.

The real desktop/browser roster-to-avatar fixture now explicitly drains the
visual queue. The notification-card fixture supplies its missing chat controls
and also checks that an activation adds exactly one system chat message. Initial
probe fixture type errors were corrected before counting passes. A wild-entry
run during the UID scan emitted a shutdown resource diagnostic; isolated
original-base and candidate reruns completed without script/resource errors.
Cold import and a subsequent warm native UID scan completed in slot-d. Existing
asset UID fallback warnings remain; no full GPU or device certification is
claimed. The 5 ms synthetic visual operation measured approximately 5.08 ms and
left the other 23 avatars queued after the first budgeted batch.

New regression checks are registered with the frontend check runner; the backend
snapshot suite is registered with the existing per-suite CI loop. The complete
paired gate is intentionally not run. Work used the explicitly authorized
paired temporary slot-d, with task-local tooling support; shared slot tooling
was not edited. No caches, userdata or credentials were copied between slots.
