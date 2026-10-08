# Gary co-op world return — 2026-10-08

## Report and read-only production diagnosis

Adinho reported an inability to move after a shared Gary victory with faker, a
brief view of PlayersHouse, and another Gary battle after logging in again.
No closing dialogue was visible. The exact stuck client input flags were not
captured, so the specific lock that stranded that client is not proven.

With explicit read-only authorization, production commit
`bde6fdebaad8e588be12bfea8c81c1e54d8bc264` had a clean checkout and healthy core
services. Read-only database transactions showed two distinct Gary activities,
created at 02:26:52 and 02:39:56 UTC. Both were settled wins, both participants
had acknowledged each, and both queue jobs were done after one settlement
attempt. Both accounts were idle on Route 22. The second activity was newly
initiated by Adinho; it was not a replay of an unacknowledged first battle.
No private teams, sessions or battle payloads were read or displayed. No
production mutation, recovery operation or deployment was performed.

## Client changes

A settled Gary activity now resumes the existing world only when the confirmed
profile is idle on the same map/tile and has no pending teleport. The existing
profile hydration and acknowledgement remain required. StoryService already
refreshes Gary's visibility and quest markers. Other trainer activities retain
their map reload and trainer-progress refresh behavior.

Battle cleanup clears a stale legacy global input lock when no dialogue is
open, preserving independently owned scoped locks. A winning Gary return
acquires the outro lock before exposing the overworld. Closing the dialogue
releases that lock on the following frame, preventing the closing interaction
press from reopening Gary on the same frame. Metadata failure and scene exit
also release the owned lock.

Changed positions, including an exhausted participant's respawn after a shared
win, retain the world-reload path. That path pauses the old player, fences old
position saves, and preserves the prepared authoritative destination through
world teardown. Ordinary teardown continues to discard old prepared state.

## Focused validation

- `coop_world_return_check`: real world/DialogueBox components with isolated
  movement/presence and cached metadata; same-world Gary return, stale global
  input cleanup, unrelated scopes, live/closed/missing outro, world replacement,
  authoritative respawn destination, old-save fence and ordinary-trainer reload.
- `game_state_scoped_input_lock_check`: scoped ownership, legacy cleanup,
  prepared-state preservation/one-time consumption and ordinary teardown.
- `coop_trainer_defeat_portrait_check`: existing Trainer/Gary outro portraits.
- `blackout_respawn_contract_check`: existing solo blackout/teleport contracts.
- `coop_gameplay_check`: functional assertions pass and exit 0; the previously
  documented ObjectDB/five-resource shutdown leak still reports an engine error.
  This pre-existing leak is not attributed to the reported movement block.

No full paired certification or live two-client playthrough was performed.
The fix requires a new client build and a real Gary win/return retest before
release; it does not change backend settlement or require a backend fix.
