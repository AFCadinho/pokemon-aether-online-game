# Common 3D battle effects

The existing 2D effect catalog supplies canonical event keys, aliases and sound
metadata. Active desktop 3D battles present general events using short native
geometry from `common_battle_effect_3d.gd`, owned by the arena. The Pokémon keeps
its existing model animation; these effects do not change its pose, material,
transform, HP or battle state. Actual 2D fallback retains its current presentation.

## Coverage

Durations are seconds at normal replay speed. Event aliases (including recovery
sources, stat names, item activations and Terastalization) resolve through the
same catalog as 2D, before native selection. No per-move authoring is required.

| Canonical effect | Native visual | Duration |
| --- | --- | --- |
| `stat_up` | Blue rising chevrons and rings | 0.65 |
| `stat_down` | Pink falling chevrons and contracting rings | 0.65 |
| `health_up` | Rising green crosses and rings | 0.85 |
| `wish_fulfilled` | Falling gold stars | 0.70 |
| `use_item` | Blue radial sparkles and rings | 0.55 |
| `eat_berry` | Pink motes converging toward the body | 0.55 |
| `shiny_sparkle` | Gold radial sparkles | 0.70 |
| `protect_block` | Translucent blue shell and shield rings | 0.65 |
| `status_paralysis` | Yellow lightning glyphs | 0.65 |
| `status_poisoned` | Rising purple bubbles | 0.70 |
| `status_badly_poisoned` | Rising darker purple bubbles | 0.75 |
| `status_burned` | Flickering orange embers | 0.70 |
| `status_frozen` | Blue crystals around the body | 0.75 |
| `status_sleeping` | Rising blue Z glyphs | 0.80 |
| `status_confused` | Small gold stars orbiting above the head | 0.70 |
| `grassy_terrain_start` | Expanding green rings centered on the battlefield | 0.75 |
| `z_power` | Gold power sparkles and rings | 0.85 |
| `mega_evolution` | Purple power sparkles and rings, generic fallback | 0.85 |

The existing qualified Dragonite Mega reveal remains first priority and owns
its staged animation/audio. The generic Mega burst applies when that pilot is
unavailable; it does not add a model transformation or delay the reveal callback.

The three move-specific effect entries `future_sight_impact`, `solar_beam_charge`
and `electro_shot_charge` are deferred: active 3D presents neither their 2D visual
nor their animation sound until matching native move VFX exist. Model attack,
damage and faint reactions remain on their separate routes. There is no new
generic attack sound.

## Timing, sound and ownership

The router prepares optional common sounds, then starts native visuals and sound
from one effect clock. Each distinct source sample is cued once, retaining its
file, volume and pitch. Cue offsets are scaled to the short native duration;
repeated sheet cues do not restart a sample. A sound's natural tail may finish
after the effect without holding the next battle event. Tail players remain
owned by the router and cancellable until they finish. Missing audio never
prevents a native visual from playing.

Effects follow replay speed and pause. The event renderer awaits the native
completion boundary, retaining its existing heal HP-update order, status/stat
ordering and gameplay authority. Glyph billboards preserve their authored scale.
Target placement uses reviewed idle bounds transformed into arena coordinates,
so visual height/radius follow each model's calibrated size without touching it.
Missing or hidden/fainted targets receive no visual; a valid common sound can
still play. Battlefield terrain does not require an individual target.

Cancellation, actor replacement/visibility changes, arena deactivation and scene
teardown release visuals and their waiters. Cleanup also runs before returning a
pooled world. Effects use at most 10 lightweight mesh nodes, no shadow casting,
no imported sprite sheets, no particle simulation and no camera overrides.

## Focused validation

- `battle_common_effects_3d_check.tscn`: all 21 2D catalog entries classified;
  all 18 native profiles and aliases; geometry and calibrated bounds; all four
  slots; aligned sounds and natural tails; replay speed/pause; absent audio;
  missing/hidden/replaced actors; cancellation/deactivation; ordered heal HP.
- `battle_move_presentation_routes_check.tscn`: silent model-only moves,
  shared effect audio, cancellation, misses and unchanged actual 2D fallback.
- `battle_audio_playback_check.tscn` and `battle_animation_contract_check.tscn`:
  source cue parsing, pitch/volume and unchanged 2D audio timeline contracts.
- `battle_3d_impact_pacing_check.tscn`: attack/impact/recovery and faint timing,
  retained common sounds, cancellation and 2D/3D HP ordering.
- Rendered all 18 effects at 40% progress on the installed, SHA-verified reviewed
  Pikachu model using its canonical scale/bounds and the desktop compatibility
  renderer. Visual review corrected billboard scale retention and reduced
  overlapping glyphs/overbright colors. This is a representative model preview,
  not a full battle or every-species visual certification.
