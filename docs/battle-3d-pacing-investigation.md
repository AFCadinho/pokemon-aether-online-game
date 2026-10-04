# 3D battle pacing investigation — 2026-10-04

Investigated frontend `f44bc174a54027f5b52430c8e165f2972e7c1357` and paired
backend `0bca9c85e43d349a3c9cf48b307331700a8bf191` in assigned slot-a.
This task adds investigation evidence and an offline developer probe; game
behavior, approved assets and saved player settings are unchanged.

## Findings

The code contains substantial presentation latency even with an otherwise fast
client/server. Missing 3D move/effect visuals make that latency less informative,
but adding visuals alone will not reduce it. This is independent of whether the
real arena also drops frames; that remains unmeasured by this investigation.
The player specifically reports slow attack and take-damage animation playback,
so native action pacing and damage/HP alignment are the first visual priorities.

1. **The entire native attack completes before damage presentation begins.**
   `experimental_battle_3d.gd::_action` uses the reviewed clip length and speed;
   `wait_action` waits for completion. The 3D move driver waits on this boundary,
   and `battle.gd::_render_battle_events` awaits events sequentially. Native median
   physical/special durations are **2.17 / 2.30 s** across the 1,139 reviewed
   profiles. Physical/special p95 durations are **5.16 / 5.04 s** (floor-ranked
   95th percentile). 172 physical and 166 special profiles exceed 3 s.
   Pikachu's special attack is 2.00 s, Dragonite's 2.70 s, Blastoise's 6.79 s.
   These are approved playback lengths, not measured amounts of visible motion;
   a visual review must establish whether long clips contain removable idle tails.
2. **The 3D audio clock retains the complete legacy sprite-effect duration.**
   `battle_sound_timeline.gd::compile` derives `duration_seconds` from the selected
   frame range divided by FPS, rather than actual sound length or a 3D impact
   marker. `battle_audio_player.gd` completes only when this clock expires.
   `battle_move_presentation_3d.gd` waits until native motion and that clock finish.
   They overlap, so their costs must **not** be added together. Legacy movement
   is absent in active 3D, but its frame count can still delay damage. For example,
   Earthquake contributes 2.46 s, longer than Garchomp's 2.17 s physical clip.
   All 193 catalogued move plans have sound cues; their median clock is 1.25 s.
   A last cue timestamp is not a sound end timestamp: trimming to it blindly
   would cut sounds or change intended timing.
3. **Effect-only events wait while their native VFX are absent.**
   `BattleAnimationRouter.play_effect_animation` starts the audio-only clock in
   3D and waits for it. A stat-up/down clock takes 0.83 s; Grassy Terrain start
   takes 1.87 s. `play_heal_tween_for_target` and stat tweens return immediately
   in 3D, but the effect clock and text hold remain. The stat-up probe takes
   approximately 1.17 s without a corresponding 3D stat visual. Mega Evolution
   has a separate implemented 3D effect and must be treated separately.
4. **Text and reaction delays are sequential with completed animations.**
   Trainer move callouts add 0.40–0.62 s before the attack when shown. Wild
   battles do not show this trainer command. Move text contributes 0.20 s after
   the move completes; ordinary damage text contributes 0.32 s after its reaction.
   The renderer subtracts the artificial 0.12/0.08 s animation holds from those
   text holds; those smaller holds must not be counted again. It does not
   subtract time already spent in the native animation/audio wait.
   Damage reactions have a 0.67 s median, and some are much longer (Blastoise
   2.54 s). HP is restored to its previous value before the reaction and updated
   to the new value **after** that reaction; there is no HP interpolation in
   `pokemon_hud_panel.gd`. This makes the impact feel delayed and abrupt.
5. **Loading and FPS are separate issues.**
   Model imports and integrity reads already use threaded work and a model cache;
   preparation warms the rendered viewports before revealing the battle. Arena
   build, model instantiation and material-pass duplication still execute on the
   main thread. Two 3D render passes with MSAA and shadows create real GPU/CPU
   work; viewport size follows screen dimensions without a separate render-scale
   cap. These are profiling candidates, not proven FPS bottlenecks here.
   Prior retained model-pack reports document entry spikes of 0.52–1.43 s despite
   passing steady-state frame-time guards; those are historical evidence, not a
   measurement of this version. The concurrent slot-b repeat-arena-preparation
   task is outside this investigation. No changes to its worktree were made.

The normal opponent-response hold is already `0.0` s. Increasing network timeout
or removing that hold cannot improve the demonstrated presentation latency.
The 30 s event timeout and 1.5 s first-use audio preparation limit are watchdogs,
not unconditional pauses. No live backend/AI/network latency was benchmarked.

## Isolated runtime evidence

Godot 4.6.2 headless, fixed 0.40 s trainer command, playback speed 1.0, warmed
move audio. The probe runs the real event renderer, router, 3D driver and model
presenter's action/wait functions. Synthetic actors have real AnimationPlayers
with the reviewed clip clocks, but no imported model meshes or arena. Values
below are rounded observations; they are not GPU/FPS or live-battle measurements.

| Actor → target | Move | Move event | Damage event | Combined |
|---|---|---:|---:|---:|
| Pikachu → Charizard | Thunderbolt | 2.63 s | 1.00 s | 3.63 s |
| Dragonite → Pikachu | Flamethrower | 3.33 s | 1.00 s | 4.33 s |
| Garchomp → Pikachu | Earthquake | 3.08 s | 1.00 s | 4.08 s |
| Blastoise → Pikachu | Ice Beam | 7.41 s | 1.00 s | 8.41 s |
| Pikachu → Charizard, animations disabled | Thunderbolt | 0.61 s | 0.32 s | 0.94 s |

Separate stat-up event: **1.17 s**. Disabling animations still retains the trainer
callout and text waits. The measurements exclude click-to-response latency,
other events (effectiveness/status/weather/etc.), banter, fainting and battle
entry; full-turn latency will differ. The probe deliberately supplies only the
move/damage presentation fields needed to isolate those clocks.

Reproduce from the workspace root, using the assigned slot:

```sh
ops/worktrees/slot-env slot-a -- godot --headless \
  --path .worktrees/slot-a/frontend \
  res://tools/battle_3d_pacing_probe.tscn
```

The probe changes animation preference only in isolated process memory. It writes
`.tmp/battle-pacing-investigation/runtime.json` and prints `PACING_PROBE` JSON.
Raw local logs/JSON remain ignored. The initial exploratory run had an incomplete
synthetic action-panel tree; the committed probe supplies the expected child
nodes, and the final clean rerun is the evidence used for verification.

Metadata calculations use `reviewed_model_catalog.json::profiles` and
`frames / 60 / speed`. Audio plan durations use the same start/end range, FPS
and `speed_scale` as `BattleSoundTimeline.compile` and `BattleAudioCatalog`.
The authoritative registries and animation metadata are not modified.

## Recommended implementation order

1. **Separate 3D pacing from the legacy sprite timeline.** Define 3D attack,
   impact, reaction and recovery beats; give native effects an explicit lifetime.
   First remove waits for invisible legacy effect tails, retaining scheduled
   audio and actual audio completion deliberately. Keep a readable text minimum
   based on elapsed display time, rather than always appending it after action
   completion. Overlap trainer command reading with visible anticipation where
   appropriate. Preserve the existing 2D fallback timing.
2. **Make impact visibly immediate.** Use a reviewed impact marker so target
   reaction and HP movement align with the attack's impact, while its recovery
   can finish concurrently. Keep authoritative events in order and never apply
   damage from VFX. Multi-hit moves, misses, residual damage, switches, fainting,
   cancellation and PvP render completion need explicit regression coverage.
3. **Review native animation pacing.** Compare a modest faster playback candidate
   (for example 1.25–1.5×) against the current clips, especially the long-duration
   cohort. Inspect active movement and trailing poses before cutting tails or
   forcing all species into a duration cap. Keep validated placement/motion and
   audio synchronized. Replay speed infrastructure exists, but a live-speed policy
   is not currently exposed and some battle waits bypass it; setting one global
   multiplier is not a complete solution.
4. **Measure actual rendering and entry separately.** In a rendered offline
   runtime compare cold/warm repeated battles, common and long-clock species,
   forest/stadium arenas, and normal/high-resolution windows. Capture frame p50,
   p95/max, CPU/GPU pass time, build/instantiate duration, click→response,
   response→impact, response→actions-ready and cold→warm entry time. Disable
   screenshot readbacks in timing runs. Investigate arena reuse, material/skeleton
   duplication and render scale only where this evidence points.

New 3D projectiles, flashes and camera beats can then make the shorter timeline
readable. They should occupy existing beats rather than add further serial waits.

## Focused verification

- `battle_message_timing_check.gd`: passed.
- `battle_voice_timing_check.gd`: passed.
- `battle_move_presentation_routes_check.tscn`: passed (`BATTLE_MOVE_PRESENTATION_ROUTES_OK`).
- `battle_audio_playback_check.tscn`: passed (`BATTLE_AUDIO_PLAYBACK_OK`).
- `tools/battle_3d_pacing_probe.tscn`: final clean runtime run recorded the table
  above, including the animation-disabled control and stat-only event.

No full paired certification, live accounts, production access, deployment or
player-visible gameplay change is part of this investigation.

## Follow-up: reused 2D move sounds are out of sync with 3D

On 2026-10-04 the player specifically identified the reused 2D move sound effects
as poorly synchronized with the Pokémon's 3D motion. Follow-up source/audio audit
uses frontend `62f933225d6aad7c48dc152e141f74617deedbb7`. No gameplay fix is
implemented by this follow-up; these are findings and implementation constraints.

**Reusing the sound files is compatible with 3D; reusing their sprite-frame
schedule is the mismatch.** `BattleAudioCatalog` gets cue offsets and duration
from the same 2D JSON/config as the sprite animation. The native action has an
independent clock, without reviewed anticipation/release/impact markers.

Source-file lengths were measured with ffprobe. Cue positions below include
catalog `speed_scale`, and natural sound ends include the individual cue pitch.
At ordinary playback speed, assuming aligned starts and no resource-loading
skew, the current router releases audio after the longer of the native clip and
source clock. Releasing calls `cancel`, which stops still-playing sounds.

| Move / model | Native attack | 2D clock | Last sound's natural end | Consequence |
|---|---:|---:|---:|---|
| Flamethrower / Dragonite | 2.70 s | 0.76 s | 1.09 s | Sound finishes about 1.61 s before the action ends. |
| Ice Beam / Blastoise | 6.79 s | 1.21 s | 1.29 s | Sound finishes about 5.50 s before the action ends. |
| Thunderbolt / Pikachu | 2.00 s | 1.17 s | 2.39 s | About 0.39 s of the last sample can be stopped at normal completion. |
| Earthquake / Garchomp | 2.17 s | 2.46 s | 2.68 s | Sprite clock prolongs the move, yet can still stop about 0.22 s of its last sample. |

These intervals describe clip/sample clocks, not visually reviewed impact
frames or perceived audible silence. Source files can include silence, so their
full duration is not a measurement of audible energy. Repeated cues with the
same sound name restart the same AudioStreamPlayer; Flamethrower currently
restarts its sample at 0.00, 0.08 and 0.16 s. This is inherited 2D choreography,
not an authored 3D sustained-flame sequence.

There are two further synchronization issues:

- The renderer calls `play_attack_tween_for_actor`, which immediately starts
  native motion. Only its next call, `play_move_animation`, awaits `_start_3d_audio`
  resource preparation. Cold audio can therefore start later than the animation.
  Active 3D skips the legacy move-prewarm route; audio readiness before native
  motion is not guaranteed. The 1.5 s preparation limit is a watchdog, not a
  measured constant delay.
- Playback speed advances cue timestamps and model motion, but deliberately
  does not multiply an audio sample's pitch/rate. Globally increasing speed can
  thus compress the intervals between triggers without shortening the samples,
  causing more overlap/restarts or an earlier completion cut. It cannot replace
  an explicit 3D audio schedule.

The implementation should retain the current 2D sounds and leave the 2D route
unchanged, while introducing a separate 3D schedule:

1. Prepare required audio **before** starting native motion, then start both from
   one action clock. Test cold preparation, direct move calls, cancellation and
   unavailable optional audio, without delaying a clip midway through playback.
2. Review native attack anticipation, release/impact and recovery markers for
   the actual selected clip. Bind move sound roles (wind-up, beam/strike,
   sustained/repeated, impact) to those markers. Physical and special attacks
   need different policies; avoid assuming a single universal percentage or
   changing sample pitch to stretch all sounds to every model's clip length.
   Keep reviewed timing outside untrusted downloaded model metadata.
3. Separate **cue dispatch completion**, **sample completion** and **action
   completion**. On ordinary completion, allow appropriate short sound tails
   to finish or deliberately fade them, without making every tail another
   sequential battle wait. Cancellation/scene teardown must still stop and
   release all audio. Sustained effects need an authored stop/fade policy rather
   than repeated restarts copied from 2D. Missing optional sounds must never
   block progression.
4. Align attack-impact audio, target reaction and HP presentation on the same
   reviewed impact beat. Preserve server event order, misses, multi-hit outcomes,
   and PvP render completion; sound playback must not generate battle damage.

Raw source/cue audit is retained in assigned slot-a at
`.tmp/battle-audio-sync/audit.json` (ignored). File-duration checks can be repeated
with `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "PATH.wav"`; cue/clip calculations use the
existing timeline compiler formula and reviewed profile lengths. The focused
`battle_audio_playback_check.tscn` rerun passed, including the explicit checks
that cancellation stops samples and playback speed preserves source pitch.
No rendered audiovisual audition or live backend measurement was performed.

## Implemented first timing pass

The follow-up implements 1.5× attack/damage presentation speed with unchanged
idle pacing, audio preparation before motion, and native-clock impact profiles
for Pikachu Thunderbolt/Tackle and Blastoise Ice Beam. See
`battle-move-presentation-3d.md` for eligibility, recovery and fallback rules.

Rendered native pose sheets in assigned slot-a were inspected for Pikachu's
special and physical clips and Blastoise's special clip. The Pikachu runtime
matched the currently approved installed model. Blastoise inspection used the
existing slot-local pre-eye-texture runtime with the same reviewed action
lengths; this was a pose/timing check, not approval of that old visual asset.
Impact markers are an initial authored choice; no projectile/contact VFX exists.

The focused synthetic check uses real AnimationPlayers with canonical lengths
and the actual stage/router/event renderer. At ordinary replay speed it observed
Thunderbolt impact at about 0.57 s including an injected 0.12 s audio-readiness
delay, Tackle at 0.48 s and Ice Beam at 1.35 s. Attack/reaction recovery boundaries
completed at approximately 1.36, 1.24 and 4.55 s respectively. These exclude
trainer callouts, real geometry and backend transport; compare phase behavior,
not FPS or full encounter duration, with the earlier sequential probe.

A rendered offline Thunderbolt check also ran the real battle scene and ordered
batch renderer against two approved installed Pikachu models. The HP bar was
already at 50% when the target damage reaction started, while the attacker was
still in special_attack near native position 0.83 s. The complete attack/reaction
pair took about 1.39 s without trainer callouts. Native audio tails were released
naturally and the authoritative HP state reached 50 after its damage event.
Before/impact/after screenshots and raw pose sheets remain ignored under
`.tmp/3d-pacing-review/` in the assigned slot. This verifies rendered sequencing;
perceived sound fit and the longer Blastoise recovery still need play review.
