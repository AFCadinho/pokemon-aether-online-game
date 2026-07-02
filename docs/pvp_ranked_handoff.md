# PvP Ranked Continuation Handoff

Last updated: 2026-07-02

## Repository State

- Client repo: `pokemon-aether-online`
  - Branch: `main`
  - Synced with `origin/main`
  - Current commit: `111e10b3f5f6959b1a47471ca7f8c763c9f2036d`
- Backend repo: `pokemon-aether-backend`
  - Branch: `main`
  - Synced with `origin/main`
  - Current commit: `f60b6bf23b36b0c1f076b6514f30bab053de0841`
- Old local branches `pvp-competitive-foundation` and `refine-pokedex` were merged into `main` and removed.

## What Has Been Built

### PvP Competitive Foundation

The PvP foundation has been implemented through multiple phases and merged into `main`.

Backend foundation includes:

- Persistent PvP match identity:
  - `pvp_matches`
  - `pvp_match_participants`
  - `pvp_rulesets`
- Server-side ownership enforcement:
  - Authenticated user -> match participant -> server-assigned side.
  - Client `playerId` is kept only for backward compatibility and must not be trusted.
- Gateway realtime identity:
  - Join/reconnect/ACK routing use server-resolved participant identity.
- Ruleset timer foundation:
  - `pvp_match_timers`
  - Server-side timer state and timeout detection.
- Timeout/disconnect/forfeit policy:
  - `pvp_match_connections`
  - reconnect grace
  - idempotent end decision.
- Idempotent settlement pipeline:
  - `pvp_match_results`
  - settlement key
  - match completed through settlement.
- Normal battle-end settlement:
  - Showdown battle-end maps winner side to participant user.
  - Normal win, forfeit, timeout and disconnect all use the same settlement flow.
- Match history foundation:
  - History endpoints based on `pvp_matches` + `pvp_match_results`.
- Outbox/worker foundation:
  - `pvp_outbox_events`
  - worker tick for expired timers and disconnect grace.
- Rating engine foundation:
  - `pvp_seasons`
  - `pvp_ratings`
  - `pvp_rating_events`
  - simple provisional points/rating behavior.
- Queue foundation:
  - `pvp_queues`
  - `pvp_queue_entries`
  - queue worker matches two compatible users.
- Queue match -> battle start:
  - Queue-created match can start a real battle through the existing battle-orchestrator/Showdown flow.
  - `battle_id` is bound to `pvp_matches`.

Client foundation includes:

- Minimal queue flow:
  - Join queue.
  - Leave queue.
  - Queue status polling.
  - Match found auto-opens battle.
  - Reconnect to active queue battle.
- PvP interface:
  - Toolbar PvP button opens a small menu:
    - `Ranked`
    - `Tournaments`
    - `Custom / Casual`
  - Ranked opens its own interface with:
    - Play
    - Rules
    - Leaderboard
    - Battle History
  - Tournaments opens a not-implemented placeholder.
  - Custom/Casual opens the room-code interface.
- Ranked UI has:
  - queue controls
  - current party selector placeholder
  - team validator
  - leaderboard
  - battle history
- Aether Exchange toolbar button was added:
  - asset: `pokemon-aether-online/assets/ui/aether_exchange.png`
  - currently returns `Aether Exchange is not implemented yet.`

## Important Files

Backend:

- `pokemon-aether-backend/account-service/pvp_models.py`
- `pokemon-aether-backend/account-service/pvp_schemas.py`
- `pokemon-aether-backend/account-service/pvp_services.py`
- `pokemon-aether-backend/account-service/pvp_routes.py`
- `pokemon-aether-backend/account-service/pvp_workers.py`
- `pokemon-aether-backend/account-service/migrations/versions/0030_*` through `0038_*`
- `pokemon-aether-backend/account-service/tests/test_pvp_foundation.py`
- `pokemon-aether-backend/battle-orchestrator/routes/battle_controller.py`
- `pokemon-aether-backend/battle-orchestrator/services/pvp_match_client.py`
- `pokemon-aether-backend/gateway/pvp_battle.py`
- `pokemon-aether-backend/gateway/main.py`
- `pokemon-aether-backend/gateway/tests/test_pvp_battle.py`
- `pokemon-aether-backend/showdown-api/src/routes/battle-routes.ts`

Client:

- `pokemon-aether-online/scripts/ui/ui_overlay.gd`
- `pokemon-aether-online/scenes/interface/ui_overlay.tscn`
- `pokemon-aether-online/scripts/battle/battle.gd`
- `pokemon-aether-online/scripts/battle/battle_api/battle_api_client.gd`
- `pokemon-aether-online/scripts/services/pvp_battle_realtime_service.gd`
- `pokemon-aether-online/scripts/services/gateway_api_config.gd`
- `pokemon-aether-online/assets/ui/aether_exchange.png`

## Manual Validation Already Done

The user manually validated:

- Room-code PvP still works.
- Queue join with two clients works.
- Queue worker matching works.
- Queue-created battle starts automatically after match found.
- Both clients enter the same battle.
- Lead selection works after queue battle start.
- Normal battle actions work.
- Forfeit works.
- Normal battle-end settlement works.
- Reconnect works from both sides.
- Reconnect during:
  - normal action turn
  - waiting for opponent
  - force switch
  - after opponent switch
- Battle log restore was improved.
- Reconnect/disconnect messages are shown in battle log with player names instead of generic opponent wording.
- PvP history shows completed battles.
- Leaderboard shows provisional points.

## Known Technical Notes

- The rating/leaderboard is currently provisional:
  - intended simple player-facing model: win `+10`, loss `-10`.
  - Full MMR/Elo/Glicko/placements are future work.
- Casual and ranked share the same PvP foundation.
- Room-code flow is now under `Custom / Casual`, not inside Ranked.
- Tournaments are UI placeholder only.
- Team preset/team builder is not implemented yet.
- Team validator is client-side only and not authoritative.
- Server remains authoritative for:
  - user identity
  - side
  - winner/loser
  - rating/result processing
  - timers
  - settlement
- Do not trust client-provided `playerId`, side, winner, timer, or rating.
- `.import` files are ignored by the client repo. Godot can regenerate imports for new assets.
- `godot --headless --path . --quit` produces known headless warnings/errors:
  - SubViewport stretch warning in login preview
  - socket `_sock == -1` errors
  - resource leak warnings
  These were pre-existing and not treated as blockers.
- `godot --headless --path . --import` may also warn about existing duplicate sprite UIDs and fail saving editor settings outside the workspace; asset import itself worked.

## Useful Test Commands

Client:

```bash
cd /home/adinho/Desktop/pokemonaetheronline/pokemon-aether-online
godot --headless --path . --quit
```

Backend account-service:

```bash
cd /home/adinho/Desktop/pokemonaetheronline/pokemon-aether-backend/account-service
POETRY_VIRTUALENVS_IN_PROJECT=false poetry run python -m unittest tests.test_pvp_foundation
```

Battle orchestrator note:

- Local Poetry environment was previously missing some dependencies such as FastAPI.
- Syntax check used when needed:

```bash
cd /home/adinho/Desktop/pokemonaetheronline/pokemon-aether-backend/battle-orchestrator
python3 -m py_compile routes/battle_controller.py
```

## Recommended Next Work

The next agent should continue ranked implementation, but should avoid overbuilding a full ladder/MMR system immediately.

Recommended next steps:

1. Improve the Ranked UI/UX around the current provisional ladder:
   - clearer ranked queue status
   - better empty states
   - better leaderboard row design
   - clearer win/loss/points language
2. Add a server-backed team validation endpoint:
   - same ruleset snapshot logic as matches
   - validates current party against selected queue/ruleset
   - returns structured eligibility issues
   - client validator should display this response
3. Make ranked/casual policy explicit:
   - ensure casual room-code battles do not affect ranked points unless intentionally configured.
   - ensure ranked queue matches do affect the provisional leaderboard.
4. Add lightweight ranked result display:
   - after a ranked match ends, show points delta if available.
5. Add admin/dev observability:
   - endpoint or simple debug view for queues, active entries, outbox status and rating processing.
6. Later, design real MMR/season system:
   - placement matches
   - hidden MMR
   - visible rank/tiers
   - seasonal reset/rewards.

## Prompt For New Agent

Use this prompt for a new coding agent:

```text
We are continuing Pokémon Aether Online PvP Ranked work.

Repositories:
- /home/adinho/Desktop/pokemonaetheronline/pokemon-aether-online
- /home/adinho/Desktop/pokemonaetheronline/pokemon-aether-backend

Both repos are on `main` and synced with `origin/main`.

Important context:
- A large PvP Competitive Foundation has already been implemented and merged.
- Do not rebuild the PvP foundation.
- Do not trust client-side playerId/side/winner/timer/rating.
- Server authority is required for PvP identity, ownership, timers, settlement and rating.
- Room-code PvP is now under Custom / Casual.
- Ranked uses queue-created matches and the same foundation as room-code PvP.
- Tournaments are placeholder only.
- Current leaderboard is provisional points: win +10, loss -10.
- Team preset/team builder does not exist yet.
- Client-side team validator exists but is not authoritative.

Start by reading:
- docs/pvp_ranked_handoff.md
- pokemon-aether-backend/account-service/pvp_services.py
- pokemon-aether-backend/account-service/pvp_routes.py
- pokemon-aether-backend/account-service/tests/test_pvp_foundation.py
- pokemon-aether-online/scripts/ui/ui_overlay.gd
- pokemon-aether-online/scripts/battle/battle_api/battle_api_client.gd

Your task:
Continue ranked implementation safely. Prefer small, mergeable changes.

Recommended first task:
Implement a server-backed ranked team validation endpoint and connect the Ranked UI validator to it.

Scope for that first task:
- Backend endpoint/service method validates authenticated user's current party/team payload against selected queue/ruleset.
- It must use server-side user context and selected queue/ruleset, not client authority.
- Return structured issues/warnings like:
  - party empty
  - party too small/large
  - species clause duplicate
  - queue inactive/missing
  - ruleset missing
- Client Ranked UI should call this endpoint when opening Ranked or changing queue/team source.
- Keep the existing client-only validator as fallback while loading or if endpoint fails.
- Do not implement full MMR, placement matches, season rewards, tournaments, clan wars or team builder in this task.

Validation:
- Run account-service PvP tests:
  cd pokemon-aether-backend/account-service
  POETRY_VIRTUALENVS_IN_PROJECT=false poetry run python -m unittest tests.test_pvp_foundation
- Run client compile check:
  cd pokemon-aether-online
  godot --headless --path . --quit

Known benign client headless output:
- SubViewport stretch warning
- socket `_sock == -1` errors
- resource leak warnings
```
