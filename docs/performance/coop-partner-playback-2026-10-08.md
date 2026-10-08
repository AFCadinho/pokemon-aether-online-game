# Co-op partner playback status — 2026-10-08

The simulator opens the next decision before both clients finish their local animations. Previously `partnerReady == false` was displayed as Choosing, even when the partner was still watching the previous turn. Own-client playback is not evidence of partner-client playback.

The battle presenter now reports its last fully presented event cursor and playing/idle phase through the existing authenticated co-op state poll. A backend capability flag preserves the empty request body required by older backends. The account runtime stores a bounded per-member presentation hint in a dedicated JSON column (migration `0315_coop_presentation`); only cursor and phase are returned to the partner. No team, move, command or client identifier is shared. Hints have an eight-second lifetime, renewed by repeated reports. Same-client sequence numbers reject late older updates, activity IDs fence prior battles, and removing the presenter stops renewal.

The partner status shows Playing turn when that client reports playback, Choosing only when an idle report exactly matches the public event cursor, and Waiting when the report is missing, expired, behind or ahead. Accepted choices retain Ready (Next: ready during local playback of the preceding turn). The waiting prompt also distinguishes partner animations from choosing. EN, NL, PT-BR and simplified Chinese strings are included. Both native 2D and 3D use the same classifier; the legacy connection label uses it too.

These hints only explain presentation. They do not gate actions, change simulator readiness, deadlines, polling frequency, animation speed, settlement or world return. Updates arrive on the existing polling cadence plus network latency, not frame-perfect synchronization. Older clients cannot report playback and therefore receive neutral waiting labels in updated clients. A new game build, backend release and migration are required for both players to report their real playback phase. No production write or deployment is part of this task.

## Focused verification

- Account-service gameplay and route unit tests: 28 tests, 26 passed and two opt-in real-simulator tests skipped. Includes partner-only projection, sequence ordering, unchanged report renewal, expiry despite presence heartbeats, previous-activity isolation, invalid hint rejection, unchanged mechanical checkpoint/generation, old empty-body support, and migration upgrade/downgrade with existing runtime data (SQLite).
- Account-service capture regression tests: 23 tests, 20 passed and three opt-in real-simulator tests skipped. Alembic reports a single head, `0315_coop_presentation`.
- Godot team-status check: request capability negotiation, immutable in-flight report snapshots, report cleanup, old-scene isolation, existing command feedback and translated status layout.
- Godot turn-feedback check: actual animation start/completion reports, a slower partner after our own playback finishes, local controls remaining available, animation-aware waiting prompt, stale/future cursor neutrality and caught-up Choosing.

- Godot immersive-team layout check passed for 2D/3D, four locales, multiple viewport sizes and increased UI scale; minimum HP/header gap remains 12 pixels. Godot logged existing asset UID path-fallback warnings, with no script errors or shutdown leaks in the final focused runs. Headless turn feedback drains the existing independent Trainer callout timers before teardown.
- `git diff --check` and the Godot UID sidecar check passed.

The final release still needs a real two-client co-op battle with different presentation modes or playback speeds. Focused local checks do not certify a production release or PostgreSQL migration rollout.
