# Adventure Party waiting and turn feedback — 2026-10-07

The native doubles presenter previously put detailed public actions into the
battle log while its central prompt usually stayed on “Turn is playing…”.
Capture feedback could also replace a later playback or waiting message for
four seconds. This made normal synchronization look like an unexplained pause.

The central prompt now follows the public event currently being played locally:
move, damage/healing, switch, faint, status/stat change, mechanic, capture or
field effect. Existing event formatters localize names and narration. A thicker
green allied or pink opponent HP border identifies the Pokémon for that event;
damage highlights the victim, and a miss with a target highlights that target.
No border or selected move is shown in advance of a public battle event.

The presenter keeps the earlier visible Pokémon identity until its ordered
switch/details event, even if a newer snapshot already contains its replacement.
Polling and final settlement preserve the current playback message. Feedback
clears with playback or a new battle. Controls reopen only after the same final
event cursor as before. When the partner's readiness belongs to a newer turn
than the local display,
the row says “Next: pending” or “Next: ready” instead of mixing
that choice with the current animation. This does not claim the remote client
has finished its own playback. A new primary action also clears the previous
Trainer callout when the new actor has no Trainer art, as with wild Pokémon.
No animation, extra wait, timer, polling period or server behavior was changed.

When a current decision is authoritatively confirmed, the waiting prompt says
“Choice confirmed · Waiting for [Trainer]…”. An implicit lock without that
confirmation keeps the ordinary waiting message. Both-ready preparation,
disconnection, sending, checking and world-return phases retain their distinct
messages. A capture request in flight is sending/checking; only actual ordered
local playback is labelled as playing. Older capture feedback cannot cover
playback, a capture in progress,
waiting or saving. Wrapped messages grow their existing panel upward; the
actions dock stays in place. Single-battle layout is unchanged.

## Validation

- `coop_turn_feedback_check.gd` uses actual native 2D attack/catalog playback,
  with a newer snapshot arriving during the attack. It checks earlier actor
  identity, both human actors, HP emphasis, hidden next-turn choices, final
  cursor completion, border cleanup, confirmed versus implicit waiting,
  both-ready preparation and final settlement priority in all four languages.
- The shared immersive 2D/3D layout fixture checks message-panel bounds across
  five host sizes, four locales and 150% text, and captures the 3D playback
  state using the real arena/camera and procedural actors.
- Existing co-op status, 3D doubles HUD and standalone presentation checks
  cover readiness, retries, capture/exit and cleanup behavior. Single/double
  immersive layout and PvP timer visibility checks provide regression coverage.
- The broad gameplay check now explicitly selects 2D for its sprite/capture-ball
  assertions instead of inheriting a saved 2.5D setting. It passes its behavior
  assertions and exits 0; the previously reproduced ObjectDB/five-resource
  shutdown issue remains.

The local browser preview includes own/partner action playback, confirmed
waiting, preparation and 3D feedback screenshots. The 3D example uses local
procedural test actors; this is not a live two-client walkthrough. Production
networking and the remote client's animation progress were not measured or
inferred. A new gameclient release is required; no backend change is involved.
