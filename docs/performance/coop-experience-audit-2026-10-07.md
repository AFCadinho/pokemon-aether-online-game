# Adventure Party battle pacing audit — 2026-10-07

## Scope and conclusion

The reported pain is waiting between turns and returning to the world after a
shared battle, with both 2D/3D in use. This audit examines local development
(frontend base `868b9da9ceab1b917f06f080da9105cd3498c5eb`, backend base
`4b4ed31ff0e1b2f74ae9bd90dcaa4892c4c526c0`). Production versions, requests,
worker flags and two actual game clients were not inspected or exercised.

The strongest measured opportunity is native co-op presentation: it repeats a
spread move's entire catalog effect sequentially for each target and keeps all
choices disabled until the event batch finishes. Closing then has another
serial profile/acknowledgement chain and always reloads the world scene for
trainer battles. These are separate from baseline network RTT.

No gameplay or runtime behavior was changed. The commits contain optional
measurement tools and this report only; no new client build is required to
publish the audit itself.

## Local presentation measurements

`tests/coop_experience_probe.gd` mounts the real native co-op presenter in the
ordinary battle scene, using 2D sprites, the immersive layout, a headless renderer
and synthetic public snapshots. No authenticated session or backend is used.
The rows are individual observations, not production percentiles or GPU/frame
rate results. Actual catalog animations/timers run; the 3D model action duration
is not measured. The first effect can include local resource preparation.

| Case | Elapsed |
| --- | ---: |
| Earthquake, one target | 2,698 ms |
| Earthquake, two targets | 5,133 ms |
| Earthquake, three targets | 7,604 ms |
| Four Tackle attacks plus four damage events | 3,080 ms |
| Same Tackle batch with animations disabled | 12 ms |
| Backlog of 24 damage events | 4,628 ms |

The turn snapshot already has a new decision ID and legal actions when the
four-Tackle measurement begins. `_present()` nevertheless holds `_playing`
through all animations, and `_update_actions()` hides choices while that flag is
set. In the measured animated case it remained set for 445 headless process
frames. This is intentional visual gating, not server compute time.

The probe passes its functional/cursor assertions but native animation teardown
reports leaked Tween/RefCounted instances and five script resources still in
use. A 0.5-second teardown drain did not remove them. The existing standalone
`coop_battle_presentation_check.gd` passes without those shutdown errors. Treat
native animation lifetime as a separate follow-up investigation; this audit
does not prove the warnings cause ongoing gameplay slowdown.

## Between-turn flow

1. Both participants can submit their current choices independently. The
   simulator correctly refuses to advance NPCs until all required humans choose.
2. The public account decision route calls the simulator; that simulator request
   already advances NPCs inline and reads a participant view. A healthy normal
   turn does **not** require waiting for the one-second gameplay worker loop or
   its five-second recovery scheduling.
3. The submitter receives its projection directly. The other participant learns
   about progress via `CoopService` state polling: each active poll waits for its
   response and then schedules a further 0.5-second pause. Thus 0.5 seconds is
   the pause, not a guaranteed full update period; network/server time is extra.
4. Every received fresh event is played in order before local choices reopen.
   Native `_play_native_catalog_move()` awaits each spread target in a loop;
   the older standalone presenter already uses concurrent target-pair playback.
   The native loop is shared by both 2D and 3D; 3D additionally awaits its model
   attack/damage actions before the catalog/hit sequence continues.
5. The ordinary native prompt reports generic "Waiting for the other actions"
   or "Battle in progress". The legacy panel has a separate `partnerReady`
   label; the native display has less information about why it is waiting.

Initial/recreated battle snapshots snap directly to authority. Once a live
stream is established, all delivered fresh events are animated without a total
batch pacing budget. One stale-but-live client can therefore spend seconds
catching up. The current server projection returns the most recent 160 public
events; it also scans the full simulator log while generating that projection.
Do not restore an arbitrary old event-count cutoff that loses finishing moves.

Connected participants have no automatic move-choice timeout. Disconnect
fallback is currently eight seconds on the backend, with recovery-worker
scheduling on top; some client strings still say 30 seconds. This discrepancy
is a separate UI issue, and neither value is a normal-turn wait requirement.

## Backend probe

Run `node tools/performance/coop-experience-probe.cjs` from the backend
`showdown-api` task worktree after its own `npm ci --ignore-scripts`. The probe
uses real coordinator/projection functions with an in-memory checkpoint store.
It counts actual checkpoint restores and store operations. It excludes HTTP,
SQL, encryption, public session authorization and production contention.

| View fixture | Median of 15 warm samples | Restores per view | View bytes |
| --- | ---: | ---: | ---: |
| One Pokemon, two moves | 3.6 ms | 7 | 3,124 |
| Three Pokemon, four moves | 10.8 ms | 11 | 4,704 |
| Same roster with 30 turns' worth of synthetic public log entries | 8.7 ms | 11 | 14,018 |

The history fixture extends the log to isolate projection work; it is not a
completed 30-turn battle or a valid long-battle gameplay replay.

One simple two-human turn measured 3.2 ms for the first player's decision and
17.5 ms for the last player's decision/NPC advancement/view. The latter performs
five checkpoint reads, three writes and 11 restores in the fixture. Each
candidate legal action is currently tested by restoring another battle clone.
This is a concrete CPU/serialization optimization opportunity under load, but
these local measurements do not identify it as the source of seconds of wait.

## Finishing flow

The final checkpoint durably wakes the settlement queue in its database
transaction. An idle queue worker polls after two seconds; it processes one job
at a time. The gameplay recovery worker can also discover an ending battle,
with active runtime IDs scheduled five seconds apart. Actual production worker
enablement and load were not checked, so neither delay is attributed to a
specific reported battle.

The presenter waits for both settled status and final event playback (with a
30-second safety bound), then `world.finish_coop_activity()` loads the player's
profile, applies authoritative party/inventory/wallet/story and sends the
acknowledgement. An inventory HTTP fallback exists only if the profile cannot
supply usable inventory. The normal acknowledger does not wait for the partner
also to acknowledge before returning.

A settled wild battle on the same saved map/tile can resume in place. A trainer
battle always follows `reload_current_scene()`, even on victory in an unchanged
map. That adds scene/map construction and world-startup work after the two
requests. Settlement and final animation can overlap: their durations must
not simply be added together when estimating the total closing delay.

## Recommended implementation order

1. **One presentation per spread attack.** Animate its multiple targets together,
   with one actor motion and one soundtrack. Use independent target adapters or
   one field effect; the current mutable alias router cannot safely be reused by
   concurrent targets without changing ownership. Preserve move order, misses,
   HP, faint, switching, capture and outcome presentation.
2. **Faster complete turn playback.** Group simultaneous damage/residual feedback,
   avoid stacking a separate full model action and a redundant effect/impact
   sequence, and accelerate an accumulated live backlog. Preserve every
   important outcome and log entry; no silent final-event dropping.
3. **Return from unchanged trainer maps in place.** Keep the existing authoritative
   profile and acknowledgement checks. Refresh trainer/quest/map interactions
   explicitly; retain full world reload for changed maps, respawn and story
   transitions. Fetch the confirmed post-settlement profile during the final
   animation and apply it only when ready to close, with session/revision guards.
4. **Deliver partner progress promptly.** Send a bounded authenticated revision
   notification through the existing realtime infrastructure, with polling as
   recovery. Show separately: sending, own choice accepted/partner choosing,
   turn playback, and saving the settled result. Checkpoint/receipt ownership
   and session authorization remain required.
5. **Reduce repeated projection work.** Reuse immutable projections keyed by
   battle/revision/participant while continuing authorization/presence checks;
   investigate a legal-action path with fewer clone restores. Add stage timings
   before deciding whether settlement-worker throughput also needs changes.

All proposals can use the current infrastructure. They require follow-up code,
focused two-participant tests, and client/backend releases as applicable; none
has been implemented or deployed by this audit.

## Validation

- Presentation probe: all cursor/state assertions passed; the native-only
  shutdown resource issue above remains open.
- Standalone co-op presentation check: PASS, no script/shutdown errors.
- Three focused simulator suites: 52 tests passed (coordinator, participant view,
  gameplay HTTP contracts).
- Account gameplay suite: 10 tests passed, two opt-in simulator bridge tests
  skipped. These are not a live paired walkthrough or full release certification.
