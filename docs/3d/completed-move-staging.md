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

All entries below are implemented. Individual user approval is recorded per move.

| Move | Motif | Space | Seconds | User approval |
| --- | --- | --- | --- | --- |
| Aqua Jet | water-rush | path | 1.1 | Pending |
| Body Press | heavy-ram | path | 1.45 | Pending |
| Extreme Speed | speed-rush | path | 1.1 | Pending |
| Fake Out | speed-rush | path | 0.95 | Pending |
| Flip Turn | water-rush | path | 1.3 | Pending |
| Frustration | speed-rush | path | 1.3 | Pending |
| Giga Impact | energy-rush | path | 1.8 | Pending |
| Grassy Glide | leaf-rush | path | 1.3 | Pending |
| Head Smash | heavy-ram | path | 1.6 | Pending |
| Headlong Rush | heavy-ram | path | 1.8 | Pending |
| Iron Head | heavy-ram | path | 1.3 | Pending |
| Knock Off | dark-rush | path | 1.3 | Pending |
| Outrage | energy-rush | path | 2.1 | Pending |
| Pursuit | speed-rush | path | 1.2 | Pending |
| Rapid Spin | rolling-rush | path | 1.8 | Pending |
| Return | speed-rush | path | 1.3 | Pending |
| Rollout | rolling-rush | path | 2.1 | Pending |
| Spark | electric-rush | path | 1.45 | Pending |
| U-turn | return-rush | path | 1.3 | Pending |
| Wood Hammer | heavy-ram | path | 1.6 | Pending |
| Bullet Punch | heavy-punch | path | 0.95 | Pending |
| Close Combat | [2D-inspired combo](close-combat-choreography.md) | path | 2.6 | Approved 2026-10-06 — red/blue barrage |
| Double Kick | rising-kick | path | 1.6 | Pending |
| Drain Punch | draining-punch | path | 1.45 | Pending |
| Fire Punch | elemental-punch | path | 1.45 | Pending |
| High Jump Kick | rising-kick | path | 1.6 | Pending |
| Ice Punch | elemental-punch | path | 1.45 | Pending |
| Low Kick | rising-kick | path | 1.2 | Pending |
| Pound | heavy-punch | path | 1.1 | Pending |
| Rock Smash | heavy-punch | path | 1.3 | Pending |
| Sucker Punch | heavy-punch | path | 0.95 | Pending |
| Superpower | heavy-punch | path | 1.8 | Pending |
| Thunder Punch | elemental-punch | path | 1.45 | Pending |
| Astonish | ghost-strike | path | 1.2 | Pending |
| Bug Bite | biting-strike | path | 1.2 | Pending |
| Ceaseless Edge | cross-slash | path | 1.6 | Pending |
| Dragon Claw | cross-slash | path | 1.45 | Pending |
| Fury Attack | piercing-strike | path | 1.8 | Pending |
| Kowtow Cleave | cross-slash | path | 1.6 | Pending |
| Lick | reaching-lash | path | 1.3 | Pending |
| Peck | piercing-strike | path | 1.1 | Pending |
| Razor Shell | cross-slash | path | 1.45 | Pending |
| Vine Whip | reaching-lash | path | 1.45 | Pending |
| Wing Attack | cross-slash | path | 1.45 | Pending |
| Dragon Breath | breath-stream | path | 1.6 | Pending |
| Electro Shot | electric-beam | path | 1.8 | Pending |
| Hyper Beam | charged-beam | path | 2.5 | Pending |
| Scald | breath-stream | path | 1.6 | Pending |
| Solar Beam | charged-beam | path | 2.5 | Pending |
| Volt Switch | electric-beam | path | 1.6 | Pending |
| Fairy Wind | swirling-orb | path | 1.3 | Pending |
| Hidden Power | swirling-orb | path | 1.45 | Pending |
| Leafage | leaf-fan | path | 1.2 | Pending |
| Mud-Slap | arcing-bomb | path | 1.2 | Pending |
| Pyro Ball | arcing-bomb | path | 2.1 | Pending |
| Rock Throw | spinning-shards | path | 1.45 | Pending |
| Water Shuriken | spinning-shards | path | 1.3 | Pending |
| Weather Ball | swirling-orb | path | 1.45 | Pending |
| Absorb | returning-drain | path | 1.6 | Pending |
| Confusion | psychic-tunnel | path | 1.6 | Pending |
| Dark Pulse | dark-tunnel | path | 1.8 | Pending |
| Disarming Voice | sound-tunnel | path | 1.6 | Pending |
| Draining Kiss | heart-stream | path | 1.6 | Pending |
| Gust | wind-spiral | path | 1.6 | Pending |
| Hex | dark-tunnel | path | 1.6 | Pending |
| Psychic | psychic-tunnel | path | 1.8 | Pending |
| Psychic Noise | sound-tunnel | path | 1.8 | Pending |
| Psyshock | psychic-tunnel | path | 1.8 | Pending |
| Screech | sound-tunnel | path | 1.6 | Pending |
| Sparkling Aria | sound-tunnel | path | 1.8 | Pending |
| Supersonic | sound-tunnel | path | 1.6 | Pending |
| Baby-Doll Eyes | heart-stream | path | 1.15 | Pending |
| Charm | heart-stream | path | 1.15 | Pending |
| Encore | taunt-glyph | path | 1.15 | Pending |
| Growl | sound-call | path | 1.15 | Pending |
| Leech Seed | seed-arc | path | 1.35 | Pending |
| Leer | taunt-glyph | path | 1.15 | Pending |
| Poison Powder | powder-cloud | path | 1.35 | Pending |
| Sand Attack | powder-cloud | path | 1.15 | Pending |
| Sleep Powder | powder-cloud | path | 1.35 | Pending |
| Smokescreen | powder-cloud | path | 1.35 | Pending |
| Spore | powder-cloud | path | 1.35 | Pending |
| String Shot | woven-threads | path | 1.35 | Pending |
| Sweet Scent | powder-cloud | path | 1.35 | Pending |
| Tail Whip | taunt-glyph | path | 1.15 | Pending |
| Taunt | taunt-glyph | path | 1.15 | Pending |
| Thunder Wave | paralysis-arcs | path | 1.35 | Pending |
| Toxic | toxic-arc | path | 1.35 | Pending |
| Will-O-Wisp | ghost-flames | path | 1.35 | Pending |
| Agility | orbit-dance | actor | 1.35 | Pending |
| Calm Mind | inward-focus | actor | 1.65 | Pending |
| Charge | electric-charge | actor | 1.35 | Pending |
| Defense Curl | armor-shell | actor | 1.15 | Pending |
| Double Team | orbit-dance | actor | 1.35 | Pending |
| Dragon Dance | orbit-dance | actor | 1.65 | Pending |
| Focus Energy | inward-focus | actor | 1.15 | Pending |
| Growth | growing-aura | actor | 1.35 | Pending |
| Harden | armor-shell | actor | 1.15 | Pending |
| Howl | sound-call | actor | 1.35 | Pending |
| Nasty Plot | thought-bubbles | actor | 1.35 | Pending |
| Recover | healing-rise | actor | 1.35 | Pending |
| Roost | healing-rise | actor | 1.35 | Pending |
| Swords Dance | sword-circle | actor | 1.65 | Pending |
| Withdraw | armor-shell | actor | 1.15 | Pending |
| Aurora Veil | protective-screen | actor | 1.65 | Pending |
| Chilly Reception | cold-front | arena | 1.65 | Pending |
| Court Change | exchanging-sides | arena | 1.65 | Pending |
| Defog | clearing-mist | arena | 1.65 | Pending |
| Electric Terrain | electric-field | arena | 1.65 | Pending |
| Future Sight | future-eye | opponent-side | 1.35 | Pending |
| Grassy Terrain | grass-field | arena | 1.65 | Pending |
| Haze | clearing-mist | arena | 1.65 | Pending |
| Light Screen | protective-screen | actor | 1.65 | Pending |
| Misty Terrain | mist-field | arena | 1.65 | Pending |
| Protect | protective-screen | actor | 1.65 | Pending |
| Psychic Terrain | psychic-field | arena | 1.65 | Pending |
| Reflect | protective-screen | actor | 1.65 | Pending |
| Spikes | scattered-hazards | opponent-side | 1.65 | Pending |
| Stealth Rock | scattered-hazards | opponent-side | 1.65 | Pending |
| Sticky Web | ground-web | opponent-side | 1.65 | Pending |
| Substitute | phase-portal | actor | 1.35 | Pending |
| Teleport | phase-portal | actor | 1.35 | Pending |
| Toxic Spikes | scattered-hazards | opponent-side | 1.65 | Pending |
| Wish | wishing-star | actor | 1.65 | Pending |
| 10,000,000 Volt Thunderbolt | rainbow_lightning | arena | 3.4 | Pending |
| Acid Downpour | acid_column | arena | 3.3 | Pending |
| All-Out Pummeling | barrage | arena | 3 | Pending |
| Black Hole Eclipse | black_hole | arena | 4.2 | Pending |
| Breakneck Blitz | rush | arena | 3 | Pending |
| Catastropika | electric_dive | arena | 3.3 | Pending |
| Clangorous Soulblaze | sound_rings | arena | 3.5 | Pending |
| Continental Crush | boulder | arena | 3.5 | Pending |
| Corkscrew Crash | drill | arena | 4.2 | Pending |
| Devastating Drake | dragon | arena | 3.5 | Pending |
| Extreme Evoboost | evolution | arena | 4.2 | Pending |
| Genesis Supernova | dna_nova | arena | 4.5 | Pending |
| Gigavolt Havoc | lightning | arena | 3.2 | Pending |
| Guardian of Alola | guardian_fist | arena | 3.5 | Pending |
| Hydro Vortex | water_vortex | arena | 3.4 | Pending |
| Inferno Overdrive | fire_orb | arena | 3.4 | Pending |
| Let’s Snuggle Forever | shadow_shroud | arena | 4.6 | Pending |
| Light That Burns the Sky | sun_nova | arena | 4.6 | Pending |
| Malicious Moonsault | moonsault | arena | 3.4 | Pending |
| Menacing Moonraze Maelstrom | moon_column | arena | 3.4 | Pending |
| Never-Ending Nightmare | chains | arena | 4.2 | Pending |
| Oceanic Operetta | ocean_orb | arena | 3.8 | Pending |
| Pulverizing Pancake | body_slam | arena | 4.1 | Pending |
| Savage Spin-Out | cocoon | arena | 4.1 | Pending |
| Searing Sunraze Smash | sun_column | arena | 3.4 | Pending |
| Shattered Psyche | prism | arena | 3.5 | Pending |
| Sinister Arrow Raid | arrow_rain | arena | 3.1 | Pending |
| Soul-Stealing 7-Star Strike | seven_stars | arena | 4.1 | Pending |
| Splintered Stormshards | stone_rain | arena | 3.3 | Pending |
| Stoked Sparksurfer | electric_surf | arena | 4.4 | Pending |
| Subzero Slammer | ice_prison | arena | 3.4 | Pending |
| Supersonic Skystrike | sky_dive | arena | 4 | Pending |
| Tectonic Rage | fissure | arena | 4.1 | Pending |
| Twinkle Tackle | fairy_comet | arena | 3.6 | Pending |
