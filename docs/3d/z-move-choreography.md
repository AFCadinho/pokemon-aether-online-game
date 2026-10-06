# Z-move choreography inspired by the 2D sources

All 35 registered Z-moves have authored 3D staging based on their existing 2D
JSON timelines and sampled sprite-sheet frames. Each recipe records both source
hashes, frame count, selected release/climax frames and observed visual motifs.
They are **interpretations**, not converted Nintendo 3D animations. The SV dump
has no own move directories for these Z-moves; volumetric Godot geometry uses
existing shared SV masks. No 2D Pokémon sheets are rendered in 3D.

Playback takes 3.0–4.6 seconds at normal battle speed, with distinct buildup,
action and climax. Contact approaches start after charging; aerial contact
moves follow an arc and return using the existing actor/HUD lifecycle. Misses
retain their original aim while the target dodges, and confirmed-hit flashes
and impact sounds remain outcome-gated. Existing event ordering owns HP/status
changes. The 135 ordinary recipes and 24 approved dedicated renderers are unchanged.

Audio uses 112 short edits of the packaged 2D Z-move samples. Up to four distinct
cues per move follow source timing relationships; the final cue is aligned to
the 3D impact. All edits retain configured pitch/volume and end within the move.
Breakneck Blitz has no playable sound in the 2D catalog and stays silent.

The geometric guardian fist, energy dragon and Mimikyu shroud are stylized
stand-ins, not new Pokémon models. Extreme Evoboost represents the eight
Eeveelutions with eight colored lights rather than summoning their models.
Shared ending shockwaves supplement each move's main shape. Cinematic camera
cuts, trainer poses and original-game species-specific Z poses are outside this
pass. Camera orbit, pause, cancellation and the normal battle framing remain available.

## Visual approval checklist

All entries below still require the user's visual approval. Source descriptions
are observations of our packaged 2D animations, not claims about every original
game rendition. The style column names the authored 3D interpretation.

| Approved | Move | 2D reference motifs | 3D style | Seconds |
| --- | --- | --- | --- | --- |
| [ ] | 10,000,000 Volt Thunderbolt | Electric charge, repeated bolts, final overhead discharge | `rainbow_lightning` | 3.4 |
| [ ] | Acid Downpour | Poison droplets gather into a tall spiral over the target | `acid_column` | 3.3 |
| [ ] | All-Out Pummeling | Rapid fists converge, then one heavy finishing blow | `barrage` | 3.0 |
| [ ] | Black Hole Eclipse | Dark orb grows inside red orbiting bands, then collapses | `black_hole` | 4.2 |
| [ ] | Bloom Doom | Rising light over greenery, target pillar and scattering leaves | `bloom_pillar` | 3.2 |
| [ ] | Breakneck Blitz | Accelerating body rush with dust and a final collision | `rush` | 3.0 |
| [ ] | Catastropika | Charged electric ball, lunge and overhead lightning | `electric_dive` | 3.3 |
| [ ] | Clangorous Soulblaze | Repeated widening purple sound rings toward the target | `sound_rings` | 3.5 |
| [ ] | Continental Crush | Rocks assemble overhead into a massive crushing formation | `boulder` | 3.5 |
| [ ] | Corkscrew Crash | Spinning metallic cone, forward drive and broken ground | `drill` | 4.2 |
| [ ] | Devastating Drake | Winged violet dragon energy with a winding flame trail | `dragon` | 3.5 |
| [ ] | Extreme Evoboost | Eight evolution colors gather around the user and converge | `evolution` | 4.2 |
| [ ] | Genesis Supernova | Pink double helix, growing psychic orb and supernova | `dna_nova` | 4.5 |
| [ ] | Gigavolt Havoc | Electric charge followed by a thick column of lightning | `lightning` | 3.2 |
| [ ] | Guardian of Alola | Floating fragments assemble into a giant golden fist | `guardian_fist` | 3.5 |
| [ ] | Hydro Vortex | Water funnels spiral inward, then merge into a tall vortex | `water_vortex` | 3.4 |
| [ ] | Inferno Overdrive | Flame ring charges a projectile, then a large fire eruption | `fire_orb` | 3.4 |
| [ ] | Let’s Snuggle Forever | Shadow approaches, enveloping cloth shape and a flurry of blows | `shadow_shroud` | 4.6 |
| [ ] | Light That Burns the Sky | Small sun grows through rotating fire rings into a huge flare | `sun_nova` | 4.6 |
| [ ] | Malicious Moonsault | Aerial approach and a fiery impact | `moonsault` | 3.4 |
| [ ] | Menacing Moonraze Maelstrom | Lunar portal, descending light column and an energy burst | `moon_column` | 3.4 |
| [ ] | Never-Ending Nightmare | Dark ground portal, surrounding chains and spectral constriction | `chains` | 4.2 |
| [ ] | Oceanic Operetta | Musical notes accompany a growing water sphere, then a splash | `ocean_orb` | 3.8 |
| [ ] | Pulverizing Pancake | Brief sleepy preparation, accelerating approach, leap and ground slam | `body_slam` | 4.1 |
| [ ] | Savage Spin-Out | Silk cocoon surrounds the target, tightens and bursts | `cocoon` | 4.1 |
| [ ] | Searing Sunraze Smash | Solar portal and a descending column wrapped in fire | `sun_column` | 3.4 |
| [ ] | Shattered Psyche | Psychic ring, suspended glass-like cube, compression and shattering | `prism` | 3.5 |
| [ ] | Sinister Arrow Raid | Gathered arrows descend as a dark volley | `arrow_rain` | 3.1 |
| [ ] | Soul-Stealing 7-Star Strike | Seven cyan points connect around the target before a dark finishing strike | `seven_stars` | 4.1 |
| [ ] | Splintered Stormshards | Rocks rise around the user and shower down onto the target | `stone_rain` | 3.3 |
| [ ] | Stoked Sparksurfer | Electric motion streaks and a large downward lightning column | `electric_surf` | 4.4 |
| [ ] | Subzero Slammer | Icy shards converge into an ice formation that breaks apart | `ice_prison` | 3.4 |
| [ ] | Supersonic Skystrike | Upward launch, fast descending aerial streaks and impact | `sky_dive` | 4.0 |
| [ ] | Tectonic Rage | Ground splits, dust rises and red energy erupts from the fissure | `fissure` | 4.1 |
| [ ] | Twinkle Tackle | Fairy-colored charge, sweeping approach and a sparkling climax | `fairy_comet` | 3.6 |

## Preview and focused verification

Run from the workspace control directory:

```sh
ops/worktrees/slot-env SLOT -- godot --path .worktrees/SLOT/frontend \
  --script res://tests/z_move_choreography_preview.gd -- --moves
```

The selector contains only these 35 moves. `--smoke-z` captures three phases per
move plus ten reversed miss/block cases with pause and camera orbit. Set
`POKEAETHER_STAGE_OUTPUT` to a slot-local output directory. For targeted visual
checks, `POKEAETHER_Z_PREVIEW_MOVES` accepts comma-separated normalized move keys.

Focused checks completed:

- `z_move_choreography_check.tscn`: all 35 styles, source timeline hashes,
  three native clip lengths, charge-before-approach, aerial arcs, cancellation
  restoration and synchronized audio markers.
- `move_recipe_3d_check.tscn`: all 170 recipes, four slots, three outcomes,
  15,300 sampled frames and the 90-piece geometry budget.
- `battle_move_effects_3d_check.tscn` and `contact_move_effects_3d_check.tscn`:
  approved renderer and contact/dodge/return regressions.
- `test_move_recipe_sources.py`: source JSON/sheet hashes, source sound paths,
  complete catalog coverage and exported source-mask dependencies.
- Both audio builders with `--check`: source/edit hashes, duration, faded edges,
  non-silent PCM and no clipping (172 ordinary + 112 Z edits).
- Rendered 35 moves in three phases, plus ten reversed miss/block cases;
  screenshots inspected for distinctive silhouettes and arena readability.

Regenerate Z audio with `tools/battle_audio/build_z_choreography_edits.py`;
`build_recipe_edits.py` intentionally skips Z choreography. These tools need
ffmpeg/ffprobe offline; normal battles need neither tool nor external dump files.
