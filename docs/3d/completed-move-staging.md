# Completion of the remaining 3D move staging

Scope: **124 ordinary moves and 34 Z-moves**, following the battlefield batches.
The 24 dedicated renderers and 12 battlefield renderers retain their dispatch
and choreography, including the user-approved Heat Wave and Tera Starstorm.
There are 194 supported keys in total: the 193-entry 2D catalog plus Bubble Beam.
Moves outside that catalog retain the fast native-animation fallback.

## Presentation

`data/battle_move_staging_3d.json` assigns an explicit motif, intended space and
visual weight to every remaining key. `staged_move_effect_3d.gd` renders the
ordinary moves; the existing Z renderer retains its individual storyboards and
adds matching arena choreography. Related moves share primitives and motifs;
this is not 158 independently imported cinematic assets.

- Contact moves keep native approach/return and gain moving wakes, curved slashes,
  staggered punches, elemental fists, lashes, biting teeth and returning drain.
- Beams keep live anatomical emitters, including both Blastoise cannons. A
  near-body fallback avoids the projectile-sized gap for unprofiled species.
  Charge streaks, source masks and travelling bands lead into the impact.
- Projectiles use arcing bombs, spreading leaves, spinning shards and orb trails.
  Psychic, dark and sound waves travel through the space between the combatants.
- Status casts use travelling hearts, threads, seeds, powder clouds, spectral
  flames and electrical arcs. Self casts include orbiting swords, armor arcs,
  rising healing crosses/feathers and inward energy.
- Screens stand upright; hazards land on the opposing half. Terrain casts
  develop over the field, with separate grass, electricity, psychic and mist
  motifs. These temporary effects never mutate persistent field/status state.
- Z-moves draw energy from the battle circle, pull water into vortices, scatter
  descending fragments, branch lightning and fissures over the floor, or trace
  physical attack corridors. Their existing 2D source hashes, normal durations,
  cues and native contact choreography remain unchanged.

The effects use packaged SV dump masks and authored 3D geometry/motion. No new
external assets or 2D move sheets were added. Source aliases reuse the packaged
fire/water/flash/cloud masks; each recipe still supplies its source bindings.
Visual size is world-space, while camera-facing accents follow camera rotation.
Arena/aim anchors are captured so dodge cannot drag a cast across the ground.

## Validation and limits

Focused checks:

- `move_recipe_3d_check.tscn`: all 170 recipe moves, four actor slots, hit/miss/block,
  15,300 samples, finite geometry, <=90 pieces, audio bounds and lifecycle.
- `completed_move_staging_check.tscn`: all 158 revised moves in original and
  translated/elevated arenas, two emitters, native-clock pause and stable dodge
  aim/field. Highest sampled piece count: 89.
- `z_move_choreography_check.tscn`: all 35 source storyboards, native clip lengths,
  contact/airborne movement, cancellation and sound markers.
- `battlefield_move_check.tscn`: the 12 protected field moves in three arenas and
  singles/doubles, plus hit/miss/block, captured aim and geometry budget.
- `test_move_recipe_sources.py`: packaged texture provenance and audio mappings.
- `move_presentation_review_preview.gd -- --moves --smoke-review`: full-catalog
  rendered smoke review (194 moves, two phases per move). After inspecting the
  images, the 124 ordinary moves and two affected Z-moves were re-rendered for
  softer slash edges and correctly oriented beam/sound rings.
- `completed_move_staging_preview.gd -- --moves --smoke-staging`: 15 representative
  ordinary/Z moves, both sides, 90 captures over three phases, including
  miss/orbit/pause and cleanup. Elemental fists were checked at their final strike
  positions in this pass.

The rendered harnesses now defer shutdown until the awaiting preview coroutine
returns. This removes the zero-reference `RefCounted` exit warning observed in
the initial bulk runs; focused shutdown reproductions were checked separately.

Interactive review: run `tests/completed_move_staging_preview.gd` through the
assigned slot with `-- --moves`. The selector contains these 158 revisions.
The full-catalog preview remains available separately.

Rendering review uses the stadium. Alternate arena placement and four-slot
routing are tested programmatically. Arena footprints remain inferred from
spawn positions; effects do not clip to scenery obstacles. Species without an
anatomical profile retain bounds-based emitters. Shared motifs and native poses
remain candidates for individual tuning after the user's visual review.
**Implementation/check completion does not mean user visual approval.**

## Visual review register

All 158 entries below were accepted by the user on 2026-10-06 as part of the
[current 194-move approval](current-move-approval.md). Future tuning follows actual
gameplay feedback; no individual visual review remains required for this batch.

| Move | Motif | Space | Seconds | User approval |
| --- | --- | --- | --- | --- |
| Aqua Jet | water-rush | path | 1.1 | Approved 2026-10-06 |
| Body Press | heavy-ram | path | 1.45 | Approved 2026-10-06 |
| Extreme Speed | speed-rush | path | 1.1 | Approved 2026-10-06 |
| Fake Out | speed-rush | path | 0.95 | Approved 2026-10-06 |
| Flip Turn | water-rush | path | 1.3 | Approved 2026-10-06 |
| Frustration | speed-rush | path | 1.3 | Approved 2026-10-06 |
| Giga Impact | energy-rush | path | 1.8 | Approved 2026-10-06 |
| Grassy Glide | leaf-rush | path | 1.3 | Approved 2026-10-06 |
| Head Smash | heavy-ram | path | 1.6 | Approved 2026-10-06 |
| Headlong Rush | heavy-ram | path | 1.8 | Approved 2026-10-06 |
| Iron Head | heavy-ram | path | 1.3 | Approved 2026-10-06 |
| Knock Off | dark-rush | path | 1.3 | Approved 2026-10-06 |
| Outrage | energy-rush | path | 2.1 | Approved 2026-10-06 |
| Pursuit | speed-rush | path | 1.2 | Approved 2026-10-06 |
| Rapid Spin | rolling-rush | path | 1.8 | Approved 2026-10-06 |
| Return | speed-rush | path | 1.3 | Approved 2026-10-06 |
| Rollout | rolling-rush | path | 2.1 | Approved 2026-10-06 |
| Spark | electric-rush | path | 1.45 | Approved 2026-10-06 |
| U-turn | return-rush | path | 1.3 | Approved 2026-10-06 |
| Wood Hammer | heavy-ram | path | 1.6 | Approved 2026-10-06 |
| Bullet Punch | heavy-punch | path | 0.95 | Approved 2026-10-06 |
| Close Combat | [2D-inspired combo](close-combat-choreography.md) | path | 2.6 | Approved 2026-10-06 — red/blue barrage |
| Double Kick | rising-kick | path | 1.6 | Approved 2026-10-06 |
| Drain Punch | draining-punch | path | 1.45 | Approved 2026-10-06 |
| Fire Punch | elemental-punch | path | 1.45 | Approved 2026-10-06 |
| High Jump Kick | rising-kick | path | 1.6 | Approved 2026-10-06 |
| Ice Punch | elemental-punch | path | 1.45 | Approved 2026-10-06 |
| Low Kick | rising-kick | path | 1.2 | Approved 2026-10-06 |
| Pound | heavy-punch | path | 1.1 | Approved 2026-10-06 |
| Rock Smash | heavy-punch | path | 1.3 | Approved 2026-10-06 |
| Sucker Punch | heavy-punch | path | 0.95 | Approved 2026-10-06 |
| Superpower | heavy-punch | path | 1.8 | Approved 2026-10-06 |
| Thunder Punch | elemental-punch | path | 1.45 | Approved 2026-10-06 |
| Astonish | ghost-strike | path | 1.2 | Approved 2026-10-06 |
| Bug Bite | biting-strike | path | 1.2 | Approved 2026-10-06 |
| Ceaseless Edge | cross-slash | path | 1.6 | Approved 2026-10-06 |
| Dragon Claw | cross-slash | path | 1.45 | Approved 2026-10-06 |
| Fury Attack | piercing-strike | path | 1.8 | Approved 2026-10-06 |
| Kowtow Cleave | cross-slash | path | 1.6 | Approved 2026-10-06 |
| Lick | reaching-lash | path | 1.3 | Approved 2026-10-06 |
| Peck | piercing-strike | path | 1.1 | Approved 2026-10-06 |
| Razor Shell | cross-slash | path | 1.45 | Approved 2026-10-06 |
| Vine Whip | reaching-lash | path | 1.45 | Approved 2026-10-06 |
| Wing Attack | cross-slash | path | 1.45 | Approved 2026-10-06 |
| Dragon Breath | breath-stream | path | 1.6 | Approved 2026-10-06 |
| Electro Shot | electric-beam | path | 1.8 | Approved 2026-10-06 |
| Hyper Beam | charged-beam | path | 2.5 | Approved 2026-10-06 |
| Scald | breath-stream | path | 1.6 | Approved 2026-10-06 |
| Solar Beam | charged-beam | path | 2.5 | Approved 2026-10-06 |
| Volt Switch | electric-beam | path | 1.6 | Approved 2026-10-06 |
| Fairy Wind | swirling-orb | path | 1.3 | Approved 2026-10-06 |
| Hidden Power | swirling-orb | path | 1.45 | Approved 2026-10-06 |
| Leafage | leaf-fan | path | 1.2 | Approved 2026-10-06 |
| Mud-Slap | arcing-bomb | path | 1.2 | Approved 2026-10-06 |
| Pyro Ball | arcing-bomb | path | 2.1 | Approved 2026-10-06 |
| Rock Throw | spinning-shards | path | 1.45 | Approved 2026-10-06 |
| Water Shuriken | spinning-shards | path | 1.3 | Approved 2026-10-06 |
| Weather Ball | swirling-orb | path | 1.45 | Approved 2026-10-06 |
| Absorb | returning-drain | path | 1.6 | Approved 2026-10-06 |
| Confusion | psychic-tunnel | path | 1.6 | Approved 2026-10-06 |
| Dark Pulse | dark-tunnel | path | 1.8 | Approved 2026-10-06 |
| Disarming Voice | sound-tunnel | path | 1.6 | Approved 2026-10-06 |
| Draining Kiss | heart-stream | path | 1.6 | Approved 2026-10-06 |
| Gust | wind-spiral | path | 1.6 | Approved 2026-10-06 |
| Hex | dark-tunnel | path | 1.6 | Approved 2026-10-06 |
| Psychic | psychic-tunnel | path | 1.8 | Approved 2026-10-06 |
| Psychic Noise | sound-tunnel | path | 1.8 | Approved 2026-10-06 |
| Psyshock | psychic-tunnel | path | 1.8 | Approved 2026-10-06 |
| Screech | sound-tunnel | path | 1.6 | Approved 2026-10-06 |
| Sparkling Aria | sound-tunnel | path | 1.8 | Approved 2026-10-06 |
| Supersonic | sound-tunnel | path | 1.6 | Approved 2026-10-06 |
| Baby-Doll Eyes | heart-stream | path | 1.15 | Approved 2026-10-06 |
| Charm | heart-stream | path | 1.15 | Approved 2026-10-06 |
| Encore | taunt-glyph | path | 1.15 | Approved 2026-10-06 |
| Growl | sound-call | path | 1.15 | Approved 2026-10-06 |
| Leech Seed | seed-arc | path | 1.35 | Approved 2026-10-06 |
| Leer | taunt-glyph | path | 1.15 | Approved 2026-10-06 |
| Poison Powder | powder-cloud | path | 1.35 | Approved 2026-10-06 |
| Sand Attack | powder-cloud | path | 1.15 | Approved 2026-10-06 |
| Sleep Powder | powder-cloud | path | 1.35 | Approved 2026-10-06 |
| Smokescreen | powder-cloud | path | 1.35 | Approved 2026-10-06 |
| Spore | powder-cloud | path | 1.35 | Approved 2026-10-06 |
| String Shot | woven-threads | path | 1.35 | Approved 2026-10-06 |
| Sweet Scent | powder-cloud | path | 1.35 | Approved 2026-10-06 |
| Tail Whip | taunt-glyph | path | 1.15 | Approved 2026-10-06 |
| Taunt | taunt-glyph | path | 1.15 | Approved 2026-10-06 |
| Thunder Wave | paralysis-arcs | path | 1.35 | Approved 2026-10-06 |
| Toxic | toxic-arc | path | 1.35 | Approved 2026-10-06 |
| Will-O-Wisp | ghost-flames | path | 1.35 | Approved 2026-10-06 |
| Agility | orbit-dance | actor | 1.35 | Approved 2026-10-06 |
| Calm Mind | inward-focus | actor | 1.65 | Approved 2026-10-06 |
| Charge | electric-charge | actor | 1.35 | Approved 2026-10-06 |
| Defense Curl | armor-shell | actor | 1.15 | Approved 2026-10-06 |
| Double Team | orbit-dance | actor | 1.35 | Approved 2026-10-06 |
| Dragon Dance | orbit-dance | actor | 1.65 | Approved 2026-10-06 |
| Focus Energy | inward-focus | actor | 1.15 | Approved 2026-10-06 |
| Growth | growing-aura | actor | 1.35 | Approved 2026-10-06 |
| Harden | armor-shell | actor | 1.15 | Approved 2026-10-06 |
| Howl | sound-call | actor | 1.35 | Approved 2026-10-06 |
| Nasty Plot | thought-bubbles | actor | 1.35 | Approved 2026-10-06 |
| Recover | healing-rise | actor | 1.35 | Approved 2026-10-06 |
| Roost | healing-rise | actor | 1.35 | Approved 2026-10-06 |
| Swords Dance | sword-circle | actor | 1.65 | Approved 2026-10-06 |
| Withdraw | armor-shell | actor | 1.15 | Approved 2026-10-06 |
| Aurora Veil | protective-screen | actor | 1.65 | Approved 2026-10-06 |
| Chilly Reception | cold-front | arena | 1.65 | Approved 2026-10-06 |
| Court Change | exchanging-sides | arena | 1.65 | Approved 2026-10-06 |
| Defog | clearing-mist | arena | 1.65 | Approved 2026-10-06 |
| Electric Terrain | electric-field | arena | 1.65 | Approved 2026-10-06 |
| Future Sight | future-eye | opponent-side | 1.35 | Approved 2026-10-06 |
| Grassy Terrain | grass-field | arena | 1.65 | Approved 2026-10-06 |
| Haze | clearing-mist | arena | 1.65 | Approved 2026-10-06 |
| Light Screen | protective-screen | actor | 1.65 | Approved 2026-10-06 |
| Misty Terrain | mist-field | arena | 1.65 | Approved 2026-10-06 |
| Protect | protective-screen | actor | 1.65 | Approved 2026-10-06 |
| Psychic Terrain | psychic-field | arena | 1.65 | Approved 2026-10-06 |
| Reflect | protective-screen | actor | 1.65 | Approved 2026-10-06 |
| Spikes | scattered-hazards | opponent-side | 1.65 | Approved 2026-10-06 |
| Stealth Rock | scattered-hazards | opponent-side | 1.65 | Approved 2026-10-06 |
| Sticky Web | ground-web | opponent-side | 1.65 | Approved 2026-10-06 |
| Substitute | phase-portal | actor | 1.35 | Approved 2026-10-06 |
| Teleport | phase-portal | actor | 1.35 | Approved 2026-10-06 |
| Toxic Spikes | scattered-hazards | opponent-side | 1.65 | Approved 2026-10-06 |
| Wish | wishing-star | actor | 1.65 | Approved 2026-10-06 |
| 10,000,000 Volt Thunderbolt | rainbow_lightning | arena | 3.4 | Approved 2026-10-06 |
| Acid Downpour | acid_column | arena | 3.3 | Approved 2026-10-06 |
| All-Out Pummeling | barrage | arena | 3 | Approved 2026-10-06 |
| Black Hole Eclipse | black_hole | arena | 4.2 | Approved 2026-10-06 |
| Breakneck Blitz | rush | arena | 3 | Approved 2026-10-06 |
| Catastropika | electric_dive | arena | 3.3 | Approved 2026-10-06 |
| Clangorous Soulblaze | sound_rings | arena | 3.5 | Approved 2026-10-06 |
| Continental Crush | boulder | arena | 3.5 | Approved 2026-10-06 |
| Corkscrew Crash | drill | arena | 4.2 | Approved 2026-10-06 |
| Devastating Drake | dragon | arena | 3.5 | Approved 2026-10-06 |
| Extreme Evoboost | evolution | arena | 4.2 | Approved 2026-10-06 |
| Genesis Supernova | dna_nova | arena | 4.5 | Approved 2026-10-06 |
| Gigavolt Havoc | lightning | arena | 3.2 | Approved 2026-10-06 |
| Guardian of Alola | guardian_fist | arena | 3.5 | Approved 2026-10-06 |
| Hydro Vortex | water_vortex | arena | 3.4 | Approved 2026-10-06 |
| Inferno Overdrive | fire_orb | arena | 3.4 | Approved 2026-10-06 |
| Let’s Snuggle Forever | shadow_shroud | arena | 4.6 | Approved 2026-10-06 |
| Light That Burns the Sky | sun_nova | arena | 4.6 | Approved 2026-10-06 |
| Malicious Moonsault | moonsault | arena | 3.4 | Approved 2026-10-06 |
| Menacing Moonraze Maelstrom | moon_column | arena | 3.4 | Approved 2026-10-06 |
| Never-Ending Nightmare | chains | arena | 4.2 | Approved 2026-10-06 |
| Oceanic Operetta | ocean_orb | arena | 3.8 | Approved 2026-10-06 |
| Pulverizing Pancake | body_slam | arena | 4.1 | Approved 2026-10-06 |
| Savage Spin-Out | cocoon | arena | 4.1 | Approved 2026-10-06 |
| Searing Sunraze Smash | sun_column | arena | 3.4 | Approved 2026-10-06 |
| Shattered Psyche | prism | arena | 3.5 | Approved 2026-10-06 |
| Sinister Arrow Raid | arrow_rain | arena | 3.1 | Approved 2026-10-06 |
| Soul-Stealing 7-Star Strike | seven_stars | arena | 4.1 | Approved 2026-10-06 |
| Splintered Stormshards | stone_rain | arena | 3.3 | Approved 2026-10-06 |
| Stoked Sparksurfer | electric_surf | arena | 4.4 | Approved 2026-10-06 |
| Subzero Slammer | ice_prison | arena | 3.4 | Approved 2026-10-06 |
| Supersonic Skystrike | sky_dive | arena | 4 | Approved 2026-10-06 |
| Tectonic Rage | fissure | arena | 4.1 | Approved 2026-10-06 |
| Twinkle Tackle | fairy_comet | arena | 3.6 | Approved 2026-10-06 |
