# Battle Voice Director

The battle voice layer is presentation-only. Showdown remains authoritative for
choices, order, accuracy, damage, forced switches, fainting, and every other
mechanical result. The voice director reads the already-public ordered event
stream and selects a localized callout; it never submits or changes an action.

## Flow

1. An ordered public battle event reaches the existing renderer.
2. The UI maps the event to an intent such as `move_command`,
   `save_wounded_pokemon`, `press_weak_opponent`, `forced_by_effect`, or
   `replacement_after_faint`.
3. `data/battle_voice_rules.json` selects the highest-priority rule that allows
   the battle mode and trainer profile.
4. A stable hash of the battle ID, turn, intent, rule, and public event names
   selects a weighted localization variant.
5. The existing trainer speech bubble renders the selected text at the same
   presentation boundary it already used.

## Presentation timing

`battle_voice_timing.gd` provides a bounded minimum read time; the renderer does
not wait for the bubble's full fade-out. Short move commands lead their attack
by 0.40 seconds, a true-miss dodge gets 0.70 seconds before the miss animation,
and switch commands scale from 0.45 to at most 0.80 seconds based on localized
text length. The bubble remains visible for about 2.1 seconds unless a later
callout replaces it after that minimum read boundary. These waits are part of
ordered presentation only and never alter battle resolution or server RNG.

The seed deliberately excludes local `p1`/`p2` identity. Participant responses
are side-relative while spectator responses are canonical, so including side
would allow viewers to select different lines. HP context uses the same public
ceiling percentage contract as PvP projections. Hidden teams, pending choices,
exact opponent HP, private requests, and battle RNG are prohibited inputs.

## Generic intents

- `move_command`: normal move call; always based on the public move event.
- `miss_dodge`: only follows a real public miss result.
- `voluntary_switch`: ordinary recall and replacement.
- `save_wounded_pokemon`: voluntary switch at or below 25% public HP.
- `press_weak_opponent`: voluntary switch while the public foe is at or below
  25% HP.
- `replacement_after_faint`: the previous active Pokémon publicly fainted.
- `forced_by_effect`: the switch event is publicly marked forced while the
  previous Pokémon has not fainted.
- `send_out`: no valid recalled Pokémon is publicly known.

More specific intents win before general variants. A command action produces at
most one generic callout. Special NPC `battle_banter` remains a separate,
one-shot scripted layer for rival, gym, and story moments; its cue IDs are
consumed once and its configured pause affects only presentation.

## Profiles and intensity

NPC metadata can expose a validated `battle_voice` object with one reusable
profile: `classic`, `respectful`, `confident`, `playful`, `dramatic`, `tactical`,
or `silent`. The reusable rule catalog owns the text; trainer metadata contains
no dialogue text or strategy.

`full` enables contextual intents, `reduced` keeps concise command/switch lines,
and `off` suppresses that configured NPC voice. PvP currently uses `classic`
and `full` for both players. The contract is ready for a later public player
preference, but no account setting or private player metadata is inferred.

## Spectators and reconnects

Live spectators pass through the same ordered event renderer and therefore see
new callouts. Stable public selection produces the same localization key as the
participants. Switching spectator perspective remaps only the snapshot and does
not replay events. A spectator joining an active battle receives the canonical
current snapshot without replaying historical bubbles, then sees future live
callouts normally.
