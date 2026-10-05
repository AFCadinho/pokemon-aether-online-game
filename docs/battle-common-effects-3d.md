# Common 3D battle effects

The existing 2D effect catalog supplies canonical event keys, aliases and sound
metadata. Active desktop 3D battles present general events using short native
geometry from `common_battle_effect_3d.gd`, owned by the arena. One-shot effects leave model poses/materials and gameplay state alone. Persistent
status presentation separately owns a reversible tint overlay and quiet repeating
particles; native sleep/frozen idle playback follows the displayed condition. Actual 2D fallback retains its current presentation.

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
| `use_item` | Golden light bands and particles sweeping up and down | 0.85 |
| `eat_berry` | A native berry in front of the body, bite and crumbs | 0.75 |
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
| `z_power` | Building gold aura, rising sparks and expanding burst | 1.35 |
| `mega_evolution` | Purple aura and staged reveal for other reviewed Megas | 1.40 |

The existing qualified Dragonite Mega reveal remains first priority. Other reviewed
Megas are now prepared before the species changes, including exact shiny forms.
A missing local model is requested through the existing pinned on-demand service
while the original actors remain visible. The generic effect owns a reveal beat
at 55% of its timeline; the existing battle callback applies the form at that beat.
Cancellation before that beat prevents the callback. Disabling animations still
prepares the announced model before applying the form.

The three move-specific effect entries `future_sight_impact`, `solar_beam_charge`
and `electro_shot_charge` are deferred: active 3D presents neither their 2D visual
nor their animation sound until matching native move VFX exist. Model attack,
damage and faint reactions remain on their separate routes. There is no new
generic attack sound.

## Timing, sound and ownership

The router prepares optional common sounds, then starts native visuals and sound
from one effect clock. Each distinct source sample is cued once, retaining its
file, volume and pitch. Cue offsets are scaled to the short native duration;
repeated sheet cues do not restart a sample. `UseItem.ogg` starts with the golden vertical sweep; the existing berry `PRSFX- Bite.wav` plays at the visible bite (32%).
The second generic Mega sound is aligned with the 55% reveal beat. A sound's natural tail may finish
after the effect without holding the next battle event. Tail players remain
owned by the router and cancellable until they finish. Missing audio never
prevents a native visual from playing.

Effects follow replay speed and pause. The event renderer awaits the native
completion boundary, retaining its existing heal HP-update order, status/stat
ordering and gameplay authority. Glyph billboards preserve their authored scale.
Target placement uses reviewed idle bounds transformed into arena coordinates,
so visual height/radius follow each model's calibrated size without touching it.
For older approved models without sampled bounds (including Hippowdon), the
visible posed mesh envelope is measured once and cached in model units.
Missing or hidden/fainted targets receive no visual; a valid common sound can
still play. Battlefield terrain does not require an individual target.

Cancellation, actor replacement/visibility changes, arena deactivation and scene
teardown release visuals and their waiters. Cleanup also runs before returning a
pooled world. One-shot effects use at most 19 lightweight mesh nodes, no shadow casting,
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

## Persistent statuses and Substitute

The 2D status overlay respects SpriteBox model ownership, including its tint reset,
so poison/burn/paralysis cannot set a hidden sprite's alpha back to one. Its
condition is retained for actual 2D fallback. Single battles and all four co-op
slots feed the same displayed condition into the native presenter, preserving
pending-status event order.

Native poison/toxic, burn, paralysis, freeze and sleep use a quiet model tint
between periodic particle pulses. The loops are silent and follow replay pause.
Frozen resting playback pauses; sleep retains the native sleep clip. Per-actor
material overlays preserve existing materials and co-op target outlines; cure,
visibility changes, replacement and arena cleanup restore their ownership.

Substitute no longer excludes a reviewed Pokémon from 3D. An original procedural
3D doll owns the visible placeholder, reveals the Pokémon for its attack, returns
afterward and takes its own short hit reaction. Item/heal/common effects may target
the visible doll. Existing SpriteBox state remains authoritative for 2D fallback,
with the sprite concealed while the 3D presenter owns it.

## External effect source and model availability

The power aura adapts the MIT-licensed shader code from GDQuest's
[Godot 4 VFX assets](https://github.com/gdquest-demos/godot-4-VFX-assets), pinned at
`f6034a88877f6ea144ae487694cc8fde82d4da7f`. It uses our procedural cylinder and
analytic mask/noise, driven by the effect clock instead of global shader time.
No upstream artwork is included; that repository licenses artwork separately.
The source license is retained in `docs/licenses/gdquest-vfx-MIT.txt`.

`garchomp-mega-z` and its shiny appearance exist in the reviewed registry and v8
asset index. They are absent from the v7 required set. This change fixes preparation
and staging; it does not change release selection or publish a new model release.
`moltres-galar` is absent from the reviewed registry and v8 index, so it still needs
its own source intake, appearance/motion review and model bundle. Ordinary Moltres
is never silently substituted. The previously documented source drive path was
unavailable during this task.

Additional focused evidence: `battle_3d_status_lifecycle_check.tscn` exercises
persistent status ownership/cure/pause, 2D suppression/restoration, co-op outlines,
all four Substitute slots, native hits/reveal/cleanup, normal/shiny Mega staging,
reveal cancellation, up-and-down item motion and the exact item/berry audio resources.
Rendered Hippowdon's poison/toxic/burn, Pikachu's status/item/berry/Z-Power/Substitute
and shiny Garchomp-Mega-Z. The actual reviewed shiny Garchomp → Mega-Z preparation
and reveal ran through the pinned on-demand service and real presenter without
losing the original actor during preparation or switching to 2D. The rendered
compatibility run exited cleanly; the headless model probe hit Godot dummy-renderer
material warnings, so rendered validation is the final model evidence.

The rendered real-model probe also checked frozen idle stops and resumes after
cure. Existing Substitute contracts, specialized Mega, move routing and impact/
faint pacing checks passed. Co-op gameplay assertions passed in the compatibility
renderer (exit 0), with a five-resource teardown warning still present in that
fixture; native status lifecycle and real-model probes exit cleanly.

## Visual approval checklist

Only explicit player approval completes an entry.

- [x] Z-Moves / Z-Power
- [x] Item activation — golden bands and particles sweeping up and down; approved after gem-before-attack timing fix
- [x] Berry eating
- [ ] Poison — bubble diameter reduced by 40%; awaiting visual approval
- [ ] Toxic — same smaller bubbles; awaiting visual approval
- [ ] Burn
- [ ] Paralysis
- [ ] Freeze
- [ ] Sleep
- [ ] Substitute
- [ ] Mega evolution

Gem activation events emitted after a move announcement are presented before
that move's animation. This uses the same ordered batch for rendering and HP
rewind, including replays. Only the attacker's gem consumption moves; defensive
items, berries, recoil and end-of-turn effects retain their event order.
