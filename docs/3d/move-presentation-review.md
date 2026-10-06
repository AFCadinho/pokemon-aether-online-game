# 3D move presentation review — flow before spectacle before brevity

Review scope: **all 194 supported 3D move keys** (24 dedicated renderers,
135 ordinary family recipes and 35 separately staged Z-moves). These are the
193 entries in the 2D animation catalog plus Bubble Beam, not every gameplay
move. The user's priority is smooth flow, then attractive presentation; short
duration is only a priority for moves without an effect.

Current follow-up: [completed move staging](completed-move-staging.md) covers the
remaining 124 ordinary and 34 Z-moves after both battlefield batches. The register
below is the earlier presentation review snapshot.

## Changes and findings

Follow-up: [battlefield staging](battlefield-move-staging.md) replaces the
target-local rendering for Earthquake, Blizzard and Bloom Doom. Their current
durations are 2.8, 3.0 and 3.8 seconds respectively; the register below preserves
the earlier all-move review snapshot.

- Every supported move now has an explicit normal-speed presentation duration.
  Ordinary attacks/casts are individually assigned 0.95–2.5 seconds, rather than
  sharing a 0.95–1.65-second family default. Dedicated moves have explicit
  0.8–3.2-second durations. Z-moves retain 3.0–4.6-second staging.
- Unsupported moves retain native Pokémon motion, capped at 0.65 seconds. They
  have no invented VFX or mismatched move audio. Common damage/heal audio remains
  event-owned. This cap does not limit an implemented move's effect.
- Source atlases blend adjacent frames instead of stepping, with atlas-edge
  clamping to avoid sampling the neighboring cell. Spheres/cylinders have smoother
  silhouettes; surfaces have translucent rim highlights and subtle emission.
- Beams grow into their width and taper away with a soft envelope. Projectiles
  ease into/out of travel and dissolve at arrival. Wave rings appear/disappear
  smoothly; thinner rings keep Pokémon readable. Elemental rushes carry source
  particles with the actor; punches/kicks use rounded, staggered strike forms.
- Gust, Draining Kiss, Growl and Howl previously lost their wind/heart/sound
  identity through generic dispatch. These now have their intended motifs.
  Aurora Veil, Light Screen, Reflect and Protect use vertical screen geometry.
  Self-targeting field moves now reach their field renderer instead of accidentally
  taking the generic self-cast path.
- Dodge previously clamped impact to 65% of the clip and could return before a
  late Z-move impact. It now holds displacement through the real impact and
  smoothly returns in the remaining time. Attack, effects, audio and damage
  bridge still share the native clock; pause/cancel semantics are retained.
- Twelve two-cue casts overwrote their first sound with their second because
  both exported to the same filename. Unique cue files restore both sources,
  and the second cast cue follows its source-frame relationship. All ordinary
  edits are rebuilt for the new durations (184 WAVs), retaining pitch/volume,
  bounded playback and fades. Z and dedicated audio source edits are retained.

These are authored Godot effects using the packaged dump masks, not a conversion
of Nintendo's animation simulation. No new external assets or 2D sprite effects
were introduced. This pass does not mark any revised move as user-approved.

## What still deserves individual art direction

The 135 family variants still share choreography. This pass improves their
flow and presentation; it does not make each of them a bespoke cinematic.
In particular, ordinary psychic attacks still share pulse staging, most
physical strikes share native attack poses, and species-specific Z-move body
performances remain stylized. Those are the clearest candidates for further
individual tuning after visual review. Longer playback alone is not proof of
better presentation.

## Per-move review register

Each row was included in the code/timing audit and rendered review. Seconds
are at normal playback speed. Existing native pose markers are preserved.
The final column records the relevant treatment, not user approval.

| Move | Renderer | Before → now (s) | Treatment |
| --- | --- | --- | --- |
| Tackle | Dedicated | native, capped at 1.25 → 0.95 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Scratch | Dedicated | native, capped at 1.25 → 1 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Bite | Dedicated | native, capped at 1.25 → 1.1 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Quick Attack | Dedicated | native, capped at 0.8 → 0.8 | Retain deliberate fast approach, strike and return |
| Ember | Dedicated | native, capped at 1.25 → 1.25 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Water Gun | Dedicated | native, capped at 1.25 → 1.35 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Thunder Shock | Dedicated | native, capped at 1.25 → 1.25 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Thunderbolt | Dedicated | native, capped at 1.25 → 1.8 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Flamethrower | Dedicated | native, capped at 1.25 → 1.9 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Bubble | Dedicated | native, capped at 1.25 → 1.45 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Bubble Beam | Dedicated | native, capped at 1.25 → 1.8 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Ice Beam | Dedicated | native, capped at 1.25 → 1.9 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Razor Leaf | Dedicated | native, capped at 1.25 → 1.45 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Shadow Ball | Dedicated | native, capped at 1.25 → 1.7 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Sludge Bomb | Dedicated | native, capped at 1.25 → 1.6 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Focus Blast | Dedicated | native, capped at 1.25 → 1.9 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Moonblast | Dedicated | 2.0 → 2 | Retain approved 2.0 s moon/charge/flight sequence and body clearance |
| Ice Shard | Dedicated | native, capped at 1.25 → 1.15 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Poison Sting | Dedicated | native, capped at 1.25 → 1.05 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Swift | Dedicated | native, capped at 1.25 → 1.45 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Flash Cannon | Dedicated | native, capped at 1.25 → 1.9 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Magical Leaf | Dedicated | native, capped at 1.25 → 1.55 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Water Pulse | Dedicated | native, capped at 1.25 → 1.6 | Keep established source art/anchors; explicit pacing and smooth texture frames |
| Draco Meteor | Dedicated | 3.2 → 3.2 | Retain approved 3.2 s ascent, sky burst and meteor shower |
| Aqua Jet | contact | 1.1 → 1.1 | Source-textured elemental wake travels with actor; stronger rush silhouette |
| Body Press | contact | 1.1 → 1.45 | Approach/return, source-textured hit and softened effect edges |
| Extreme Speed | contact | 1.1 → 1.1 | Approach/return, source-textured hit and softened effect edges |
| Fake Out | contact | 1.1 → 0.95 | Approach/return, source-textured hit and softened effect edges |
| Flip Turn | contact | 1.1 → 1.3 | Source-textured elemental wake travels with actor; stronger rush silhouette |
| Frustration | contact | 1.1 → 1.3 | Approach/return, source-textured hit and softened effect edges |
| Giga Impact | contact | 1.1 → 1.8 | Source-textured elemental wake travels with actor; stronger rush silhouette |
| Grassy Glide | contact | 1.1 → 1.3 | Source-textured elemental wake travels with actor; stronger rush silhouette |
| Head Smash | contact | 1.1 → 1.6 | Approach/return, source-textured hit and softened effect edges |
| Headlong Rush | contact | 1.1 → 1.8 | Source-textured elemental wake travels with actor; stronger rush silhouette |
| Iron Head | contact | 1.1 → 1.3 | Approach/return, source-textured hit and softened effect edges |
| Knock Off | contact | 1.1 → 1.3 | Approach/return, source-textured hit and softened effect edges |
| Outrage | contact | 1.1 → 2.1 | Source-textured elemental wake travels with actor; stronger rush silhouette |
| Pursuit | contact | 1.1 → 1.2 | Approach/return, source-textured hit and softened effect edges |
| Rapid Spin | contact | 1.1 → 1.8 | Approach/return, source-textured hit and softened effect edges |
| Return | contact | 1.1 → 1.3 | Approach/return, source-textured hit and softened effect edges |
| Rollout | contact | 1.1 → 2.1 | Approach/return, source-textured hit and softened effect edges |
| Spark | contact | 1.1 → 1.45 | Source-textured elemental wake travels with actor; stronger rush silhouette |
| U-turn | contact | 1.1 → 1.3 | Approach/return, source-textured hit and softened effect edges |
| Wood Hammer | contact | 1.1 → 1.6 | Approach/return, source-textured hit and softened effect edges |
| Bullet Punch | strikes | 1.1 → 0.95 | Rounded, staggered strikes; readable impact and return |
| Close Combat | strikes | 1.1 → 2.1 | Rounded, staggered strikes; readable impact and return |
| Double Kick | strikes | 1.1 → 1.6 | Rounded, staggered strikes; readable impact and return |
| Drain Punch | strikes | 1.1 → 1.45 | Rounded, staggered strikes; readable impact and return |
| Fire Punch | strikes | 1.1 → 1.45 | Rounded, staggered strikes; readable impact and return |
| High Jump Kick | strikes | 1.1 → 1.6 | Rounded, staggered strikes; readable impact and return |
| Ice Punch | strikes | 1.1 → 1.45 | Rounded, staggered strikes; readable impact and return |
| Low Kick | strikes | 1.1 → 1.2 | Rounded, staggered strikes; readable impact and return |
| Pound | strikes | 1.1 → 1.1 | Rounded, staggered strikes; readable impact and return |
| Rock Smash | strikes | 1.1 → 1.3 | Rounded, staggered strikes; readable impact and return |
| Sucker Punch | strikes | 1.1 → 0.95 | Rounded, staggered strikes; readable impact and return |
| Superpower | strikes | 1.1 → 1.8 | Rounded, staggered strikes; readable impact and return |
| Thunder Punch | strikes | 1.1 → 1.45 | Rounded, staggered strikes; readable impact and return |
| Astonish | claws | 1.1 → 1.2 | Keep sharp sweep; give attack and recovery their own space |
| Bug Bite | claws | 1.1 → 1.2 | Keep sharp sweep; give attack and recovery their own space |
| Ceaseless Edge | claws | 1.1 → 1.6 | Keep sharp sweep; give attack and recovery their own space |
| Dragon Claw | claws | 1.1 → 1.45 | Keep sharp sweep; give attack and recovery their own space |
| Fury Attack | claws | 1.1 → 1.8 | Keep sharp sweep; give attack and recovery their own space |
| Kowtow Cleave | claws | 1.1 → 1.6 | Keep sharp sweep; give attack and recovery their own space |
| Lick | claws | 1.1 → 1.3 | Keep sharp sweep; give attack and recovery their own space |
| Peck | claws | 1.1 → 1.1 | Keep sharp sweep; give attack and recovery their own space |
| Razor Shell | claws | 1.1 → 1.45 | Keep sharp sweep; give attack and recovery their own space |
| Vine Whip | claws | 1.1 → 1.45 | Keep sharp sweep; give attack and recovery their own space |
| Wing Attack | claws | 1.1 → 1.45 | Keep sharp sweep; give attack and recovery their own space |
| Dragon Breath | beams | 1.35 → 1.6 | Grow beam width smoothly; layered glow and sustained delivery |
| Electro Shot | beams | 1.35 → 1.8 | Grow beam width smoothly; layered glow and sustained delivery |
| Hyper Beam | beams | 1.65 → 2.5 | Grow beam width smoothly; layered glow and sustained delivery |
| Scald | beams | 1.35 → 1.6 | Grow beam width smoothly; layered glow and sustained delivery |
| Solar Beam | beams | 1.65 → 2.5 | Grow beam width smoothly; layered glow and sustained delivery |
| Volt Switch | beams | 1.35 → 1.6 | Grow beam width smoothly; layered glow and sustained delivery |
| Fairy Wind | projectiles | 1.15 → 1.3 | Ease flight and dissolve at arrival; avoid abrupt disappearance |
| Hidden Power | projectiles | 1.15 → 1.45 | Ease flight and dissolve at arrival; avoid abrupt disappearance |
| Leafage | projectiles | 1.15 → 1.2 | Ease flight and dissolve at arrival; avoid abrupt disappearance |
| Mud-Slap | projectiles | 1.15 → 1.2 | Ease flight and dissolve at arrival; avoid abrupt disappearance |
| Pyro Ball | projectiles | 1.15 → 2.1 | Give charge, arcing projectile and dissipation more time |
| Rock Throw | projectiles | 1.15 → 1.45 | Ease flight and dissolve at arrival; avoid abrupt disappearance |
| Water Shuriken | projectiles | 1.15 → 1.3 | Ease flight and dissolve at arrival; avoid abrupt disappearance |
| Weather Ball | projectiles | 1.15 → 1.45 | Ease flight and dissolve at arrival; avoid abrupt disappearance |
| Absorb | waves | 1.15 → 1.6 | Fade each wave in/out along its path |
| Confusion | waves | 1.15 → 1.6 | Fade each wave in/out along its path |
| Dark Pulse | waves | 1.15 → 1.8 | Fade each wave in/out along its path |
| Disarming Voice | waves | 1.15 → 1.6 | Fade each wave in/out along its path |
| Draining Kiss | waves | 1.15 → 1.6 | Traveling hearts instead of generic rings |
| Gust | waves | 1.15 → 1.6 | Moving 3D wind spiral instead of sound rings |
| Hex | waves | 1.15 → 1.6 | Fade each wave in/out along its path |
| Psychic | waves | 1.15 → 1.8 | Fade each wave in/out along its path |
| Psychic Noise | waves | 1.15 → 1.8 | Fade each wave in/out along its path |
| Psyshock | waves | 1.15 → 1.8 | Fade each wave in/out along its path |
| Screech | waves | 1.15 → 1.6 | Fade each wave in/out along its path |
| Sparkling Aria | waves | 1.15 → 1.8 | Fade each wave in/out along its path |
| Supersonic | waves | 1.15 → 1.6 | Fade each wave in/out along its path |
| Bleakwind Storm | area | 1.35 → 2.1 | Let the source-textured field effect develop before its climax |
| Blizzard | area | 1.35 → 2.1 | Let the source-textured field effect develop before its climax |
| Earth Power | area | 1.35 → 1.8 | Let the source-textured field effect develop before its climax |
| Earthquake | area | 1.35 → 2.1 | Let the source-textured field effect develop before its climax |
| Explosion | area | 1.35 → 2.5 | Let the source-textured field effect develop before its climax |
| Freeze-Dry | area | 1.35 → 1.6 | Let the source-textured field effect develop before its climax |
| Heat Wave | area | 1.35 → 1.8 | Let the source-textured field effect develop before its climax |
| Hurricane | area | 1.35 → 2.1 | Let the source-textured field effect develop before its climax |
| Make It Rain | area | 1.35 → 2.1 | Let the source-textured field effect develop before its climax |
| Powder Snow | area | 1.35 → 1.6 | Let the source-textured field effect develop before its climax |
| Tera Starstorm | area | 1.35 → 2.5 | Let the source-textured field effect develop before its climax |
| Baby-Doll Eyes | status | 0.95 → 1.15 | Readable cast with soft fade; persistent status remains event-owned |
| Charm | status | 0.95 → 1.15 | Readable cast with soft fade; persistent status remains event-owned |
| Encore | status | 0.95 → 1.15 | Readable cast with soft fade; persistent status remains event-owned |
| Growl | status | 0.95 → 1.15 | Expanding sound rings instead of powder sprites |
| Leech Seed | status | 0.95 → 1.35 | Readable cast with soft fade; persistent status remains event-owned |
| Leer | status | 0.95 → 1.15 | Readable cast with soft fade; persistent status remains event-owned |
| Poison Powder | status | 0.95 → 1.35 | Readable cast with soft fade; persistent status remains event-owned |
| Sand Attack | status | 0.95 → 1.15 | Readable cast with soft fade; persistent status remains event-owned |
| Sleep Powder | status | 0.95 → 1.35 | Readable cast with soft fade; persistent status remains event-owned |
| Smokescreen | status | 0.95 → 1.35 | Readable cast with soft fade; persistent status remains event-owned |
| Spore | status | 0.95 → 1.35 | Readable cast with soft fade; persistent status remains event-owned |
| String Shot | status | 0.95 → 1.35 | Readable cast with soft fade; persistent status remains event-owned |
| Sweet Scent | status | 0.95 → 1.35 | Readable cast with soft fade; persistent status remains event-owned |
| Tail Whip | status | 0.95 → 1.15 | Readable cast with soft fade; persistent status remains event-owned |
| Taunt | status | 0.95 → 1.15 | Readable cast with soft fade; persistent status remains event-owned |
| Thunder Wave | status | 0.95 → 1.35 | Readable cast with soft fade; persistent status remains event-owned |
| Toxic | status | 0.95 → 1.35 | Readable cast with soft fade; persistent status remains event-owned |
| Will-O-Wisp | status | 0.95 → 1.35 | Readable cast with soft fade; persistent status remains event-owned |
| Agility | self | 0.95 → 1.35 | Readable buildup/settling; no duplicate status/heal gameplay |
| Calm Mind | self | 0.95 → 1.65 | Readable buildup/settling; no duplicate status/heal gameplay |
| Charge | self | 0.95 → 1.35 | Readable buildup/settling; no duplicate status/heal gameplay |
| Defense Curl | self | 0.95 → 1.15 | Readable buildup/settling; no duplicate status/heal gameplay |
| Double Team | self | 0.95 → 1.35 | Readable buildup/settling; no duplicate status/heal gameplay |
| Dragon Dance | self | 0.95 → 1.65 | Readable buildup/settling; no duplicate status/heal gameplay |
| Focus Energy | self | 0.95 → 1.15 | Readable buildup/settling; no duplicate status/heal gameplay |
| Growth | self | 0.95 → 1.35 | Readable buildup/settling; no duplicate status/heal gameplay |
| Harden | self | 0.95 → 1.15 | Readable buildup/settling; no duplicate status/heal gameplay |
| Howl | self | 0.95 → 1.35 | Expanding sound rings around caster instead of generic charge |
| Nasty Plot | self | 0.95 → 1.35 | Readable buildup/settling; no duplicate status/heal gameplay |
| Recover | self | 0.95 → 1.35 | Readable buildup/settling; no duplicate status/heal gameplay |
| Roost | self | 0.95 → 1.35 | Readable buildup/settling; no duplicate status/heal gameplay |
| Swords Dance | self | 0.95 → 1.65 | Keep orbiting blades; restore two distinct, sequential sound cues |
| Withdraw | self | 0.95 → 1.15 | Readable buildup/settling; no duplicate status/heal gameplay |
| Aurora Veil | field | 0.95 → 1.65 | Vertical translucent screen with border and shimmer instead of ground rings |
| Chilly Reception | field | 0.95 → 1.65 | Readable placement and fade into event-owned field state |
| Court Change | field | 0.95 → 1.65 | Readable placement and fade into event-owned field state |
| Defog | field | 0.95 → 1.65 | Readable placement and fade into event-owned field state |
| Electric Terrain | field | 0.95 → 1.65 | Readable placement and fade into event-owned field state |
| Future Sight | field | 0.95 → 1.35 | Readable placement and fade into event-owned field state |
| Grassy Terrain | field | 0.95 → 1.65 | Readable placement and fade into event-owned field state |
| Haze | field | 0.95 → 1.65 | Readable placement and fade into event-owned field state |
| Light Screen | field | 0.95 → 1.65 | Vertical translucent screen with border and shimmer instead of ground rings |
| Misty Terrain | field | 0.95 → 1.65 | Readable placement and fade into event-owned field state |
| Protect | field | 0.95 → 1.65 | Vertical translucent screen with border and shimmer instead of ground rings |
| Psychic Terrain | field | 0.95 → 1.65 | Readable placement and fade into event-owned field state |
| Reflect | field | 0.95 → 1.65 | Vertical translucent screen with border and shimmer instead of ground rings |
| Spikes | field | 0.95 → 1.65 | Readable placement and fade into event-owned field state |
| Stealth Rock | field | 0.95 → 1.65 | Readable placement and fade into event-owned field state |
| Sticky Web | field | 0.95 → 1.65 | Readable placement and fade into event-owned field state |
| Substitute | field | 0.95 → 1.35 | Readable placement and fade into event-owned field state |
| Teleport | field | 0.95 → 1.35 | Readable placement and fade into event-owned field state |
| Toxic Spikes | field | 0.95 → 1.65 | Readable placement and fade into event-owned field state |
| Wish | field | 0.95 → 1.65 | Readable placement and fade into event-owned field state |
| 10,000,000 Volt Thunderbolt | z | 3.4 → 3.4 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Acid Downpour | z | 3.3 → 3.3 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| All-Out Pummeling | z | 3 → 3 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Black Hole Eclipse | z | 4.2 → 4.2 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Bloom Doom | z | 3.2 → 3.2 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Breakneck Blitz | z | 3 → 3 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Catastropika | z | 3.3 → 3.3 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Clangorous Soulblaze | z | 3.5 → 3.5 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Continental Crush | z | 3.5 → 3.5 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Corkscrew Crash | z | 4.2 → 4.2 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Devastating Drake | z | 3.5 → 3.5 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Extreme Evoboost | z | 4.2 → 4.2 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Genesis Supernova | z | 4.5 → 4.5 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Gigavolt Havoc | z | 3.2 → 3.2 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Guardian of Alola | z | 3.5 → 3.5 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Hydro Vortex | z | 3.4 → 3.4 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Inferno Overdrive | z | 3.4 → 3.4 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Let’s Snuggle Forever | z | 4.6 → 4.6 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Light That Burns the Sky | z | 4.6 → 4.6 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Malicious Moonsault | z | 3.4 → 3.4 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Menacing Moonraze Maelstrom | z | 3.4 → 3.4 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Never-Ending Nightmare | z | 4.2 → 4.2 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Oceanic Operetta | z | 3.8 → 3.8 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Pulverizing Pancake | z | 4.1 → 4.1 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Savage Spin-Out | z | 4.1 → 4.1 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Searing Sunraze Smash | z | 3.4 → 3.4 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Shattered Psyche | z | 3.5 → 3.5 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Sinister Arrow Raid | z | 3.1 → 3.1 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Soul-Stealing 7-Star Strike | z | 4.1 → 4.1 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Splintered Stormshards | z | 3.3 → 3.3 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Stoked Sparksurfer | z | 4.4 → 4.4 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Subzero Slammer | z | 3.4 → 3.4 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Supersonic Skystrike | z | 4 → 4 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Tectonic Rage | z | 4.1 → 4.1 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |
| Twinkle Tackle | z | 3.6 → 3.6 | Retain 2D-inspired staging; smoother masks/geometry; late dodge aligned |

## Validation and preview

`move_presentation_review_check.tscn` checks all 194 durations over three native
clip lengths, that dodge is fully displaced at every real impact, the fast
unsupported route, and fractional atlas-frame interpolation. Existing recipe,
dedicated-effect and dodge checks cover four slots, pause, cancellation,
Substitute, hit gating, audio clocks and 15,300 sampled geometry frames.
The audio source audit additionally checks that every cue references the
correct source sample by name, preventing the two-cue overwrite regression.

Rendered coverage: every move with Dragonite → Pikachu in the PvP arena,
main and impact phases (388 captures), followed by 66 focused rerenders of
adjusted family geometry and restored audio, plus final rush-effect checks. This is not a visual approval of
every species/pose combination or a mobile GPU performance certification.

```sh
ops/worktrees/slot-env SLOT -- godot --path .worktrees/SLOT/frontend \
  --script res://tests/move_presentation_review_preview.gd -- --moves
```

`--smoke-review` runs the entire list; `POKEAETHER_STAGE_OUTPUT` chooses a
slot-local screenshot directory. `POKEAETHER_REVIEW_MOVES` optionally filters
comma-separated normalized keys for focused rechecks. Normal preview playback
remains at the user's selected battle speed.
