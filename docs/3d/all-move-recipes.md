# Complete first-pass 3D move coverage

Implemented on 6 October 2026. All **193 moves registered in the 2D animation
catalog** now have a native 3D route. Bubble Beam is also retained, giving
**194 supported move keys**: 24 individually approved dedicated renderers and
170 new, individually tunable family recipes. Draco Meteor was approved by the
user before this batch; the new recipes still need individual visual review.

This is parity with the existing 2D catalog, not a claim that all 919 gameplay
move records have bespoke animations. Unsupported catalog additions remain
model-only until a recipe is added; they cannot silently load a 2D move sheet.

## Implementation

`data/battle_move_recipes_3d.json` is the tuning entry point. Each move has its
own family, variant, color, size, attachment, target, launch/impact fractions,
wall-clock duration and audio cues. `family_move_effect_3d.gd` draws geometry
and source-mask particles on the native model clock. Dedicated approved moves
keep their existing renderer, timing, scales, textures and audio edits.

Contact moves approach and return using the existing actor/HUD displacement
lifecycle. Beams sample current anatomical emitters; projectiles retain their
release origin and aim. Unprofiled emitters have body clearance. Misses keep
their original aim while the defender dodges; blocked/missed moves suppress
confirmed-hit art and impact audio. Four combatant slots and Substitute bounds
are supported. Area casts currently center on the announced target (or caster
for whole-field moves); bespoke multi-target choreography is a later refinement.

Self/side effects resolve their own anchor even without an explicit target.
Status, healing, stat, terrain and Substitute casts do not modify gameplay or
persistent state: the subsequent battle events still own those outcomes.
Solar Beam charge, Electro Shot charge and Future Sight's delayed impact are
also native common-effect phases, including bounded existing effect audio.

## Sources and sound

126 new recipes use emitter-bound masks extracted from their own numbered SV
move directory. Another 44 explicitly reuse existing packaged SV art: 43 move
directories are absent in this dump (including Z-moves), and Substitute has no
supported emitter mask. Its already approved 3D doll remains unchanged.

`assets/battles/moves_3d/sv_recipes/provenance.json` records the distinction,
original particle hashes, emitter bindings, decoded PNG hashes and the pinned
external decoder hash. Static texture preloads keep export dependencies
explicit. These are original source textures with authored Godot motion;
Nintendo's particle simulation, animation timeline and original audio have
**not** been converted. Source IDs are retained from PokeAPI's move-ID table.

239 short, faded, pitch-preserving WAV edits use the existing 2D audio and its
configured volume/pitch. Cues follow cast, launch or impact; the native clock
bounds their tails and cancellation. The 24 approved sound edits stay intact.
Disarming Voice, Growl, Howl and Breakneck Blitz have no playable sound in their
current 2D catalog and remain without a move sound rather than inventing one.

## Preview and verification

Run through the assigned slot environment:

```sh
ops/worktrees/slot-env SLOT -- godot --path .worktrees/SLOT/frontend \
  --script res://tests/move_recipe_preview.gd -- --moves
```

The selector includes all 194 moves. Hit, dodge, block, direction, model choice,
camera orbit, pause and cancellation remain available. The preview no longer
plays a damage reaction after non-damaging casts. `--smoke-recipes` renders the
170 new moves and ten additional reversed/pause/orbit/miss/block cases; set
`POKEAETHER_STAGE_OUTPUT` to a task-local screenshot directory.

Focused checks:

- `move_recipe_3d_check.tscn`: catalog/display-name coverage, 170 recipes,
  all four slots, three outcomes, 15,300 sampled frames, geometry budget,
  timing/audio, no 2D-config loads, self-targeting and router cleanup.
- `battle_move_effects_3d_check.tscn`: regression of the 24 approved renderers.
- `battle_common_effects_3d_check.tscn`: all 21 common/phase effects, audio,
  ownership, cancellation and ordered HP updates.
- `move_attachments_3d_check.tscn`: bone/cannon/body/Substitute anchors.
- `tools/battle_effects/test_move_recipe_sources.py`: coverage, source and PNG
  hashes, explicit shared-source exceptions, static export dependencies.
- `tools/battle_audio/build_recipe_edits.py --check`: all 239 source/edit
  hashes, PCM durations, non-silent samples, no clipping and faded edges.

The shared recipes are a first pass. Individual silhouettes, species poses,
multiple-hit timing, Z-move staging and sound character can be tuned afterward.
The source and audio builders require their explicit offline dependencies;
normal battles have no dependency on the dump, decoder, ffmpeg or `.tmp`.

## Review checklist — new recipes

The 24 dedicated moves, including Draco Meteor, are already approved. The
unchecked entries below are the new first-pass variants, not prior approvals.

### Contact

- [ ] Aqua Jet — dash; own SV masks.
- [ ] Body Press — dash; own SV masks.
- [ ] Extreme Speed — dash; own SV masks.
- [ ] Fake Out — dash; own SV masks.
- [ ] Flip Turn — dash; own SV masks.
- [ ] Frustration — dash; shared SV masks.
- [ ] Giga Impact — dash; own SV masks.
- [ ] Grassy Glide — dash; own SV masks.
- [ ] Head Smash — dash; own SV masks.
- [ ] Headlong Rush — quakes; own SV masks.
- [ ] Iron Head — dash; own SV masks.
- [ ] Knock Off — dash; own SV masks.
- [ ] Outrage — dash; own SV masks.
- [ ] Pursuit — dash; shared SV masks.
- [ ] Rapid Spin — spin; own SV masks.
- [ ] Return — dash; shared SV masks.
- [ ] Rollout — spin; own SV masks.
- [ ] Spark — electric; own SV masks.
- [ ] U-turn — dash; own SV masks.
- [ ] Wood Hammer — dash; own SV masks.

### Strikes

- [ ] Bullet Punch — punch; own SV masks.
- [ ] Close Combat — flurry; own SV masks.
- [ ] Double Kick — kick; own SV masks.
- [ ] Drain Punch — drain; own SV masks.
- [ ] Fire Punch — punch; own SV masks.
- [ ] High Jump Kick — kick; own SV masks.
- [ ] Ice Punch — punch; own SV masks.
- [ ] Low Kick — kick; own SV masks.
- [ ] Pound — punch; own SV masks.
- [ ] Rock Smash — punch; own SV masks.
- [ ] Sucker Punch — punch; own SV masks.
- [ ] Superpower — punch; own SV masks.
- [ ] Thunder Punch — punch; own SV masks.

### Claws

- [ ] Astonish — slash; own SV masks.
- [ ] Bug Bite — bite; own SV masks.
- [ ] Ceaseless Edge — slash; own SV masks.
- [ ] Dragon Claw — slash; own SV masks.
- [ ] Fury Attack — flurry; own SV masks.
- [ ] Kowtow Cleave — slash; own SV masks.
- [ ] Lick — whip; own SV masks.
- [ ] Peck — slash; own SV masks.
- [ ] Razor Shell — slash; own SV masks.
- [ ] Vine Whip — whip; own SV masks.
- [ ] Wing Attack — slash; own SV masks.

### Beams

- [ ] Dragon Breath — beam; own SV masks.
- [ ] Electro Shot — electric; shared SV masks.
- [ ] Hyper Beam — beam; own SV masks.
- [ ] Scald — beam; own SV masks.
- [ ] Solar Beam — beam; own SV masks.
- [ ] Volt Switch — electric; own SV masks.

### Projectiles

- [ ] Fairy Wind — orb; own SV masks.
- [ ] Hidden Power — orb; shared SV masks.
- [ ] Leafage — leaves; own SV masks.
- [ ] Mud-Slap — arc; own SV masks.
- [ ] Pyro Ball — arc; own SV masks.
- [ ] Rock Throw — shards; own SV masks.
- [ ] Water Shuriken — shards; own SV masks.
- [ ] Weather Ball — orb; own SV masks.

### Waves

- [ ] Absorb — drain; own SV masks.
- [ ] Confusion — pulse; own SV masks.
- [ ] Dark Pulse — pulse; own SV masks.
- [ ] Disarming Voice — sound; own SV masks.
- [ ] Draining Kiss — hearts; own SV masks.
- [ ] Gust — storm; own SV masks.
- [ ] Hex — pulse; own SV masks.
- [ ] Psychic — pulse; own SV masks.
- [ ] Psychic Noise — pulse; shared SV masks.
- [ ] Psyshock — pulse; own SV masks.
- [ ] Screech — sound; own SV masks.
- [ ] Sparkling Aria — sound; shared SV masks.
- [ ] Supersonic — sound; own SV masks.

### Area

- [ ] Bleakwind Storm — storm; own SV masks.
- [ ] Blizzard — snow; own SV masks.
- [ ] Earth Power — quakes; own SV masks.
- [ ] Earthquake — quakes; own SV masks.
- [ ] Explosion — burst; own SV masks.
- [ ] Freeze-Dry — snow; own SV masks.
- [ ] Heat Wave — flames; own SV masks.
- [ ] Hurricane — storm; own SV masks.
- [ ] Make It Rain — rain; own SV masks.
- [ ] Powder Snow — snow; own SV masks.
- [ ] Tera Starstorm — burst; shared SV masks.

### Status

- [ ] Baby-Doll Eyes — hearts; own SV masks.
- [ ] Charm — hearts; own SV masks.
- [ ] Encore — debuff; own SV masks.
- [ ] Growl — sound; own SV masks.
- [ ] Leech Seed — arc; own SV masks.
- [ ] Leer — eye; own SV masks.
- [ ] Poison Powder — powder; own SV masks.
- [ ] Sand Attack — powder; own SV masks.
- [ ] Sleep Powder — powder; own SV masks.
- [ ] Smokescreen — powder; own SV masks.
- [ ] Spore — powder; own SV masks.
- [ ] String Shot — web; own SV masks.
- [ ] Sweet Scent — powder; own SV masks.
- [ ] Tail Whip — debuff; own SV masks.
- [ ] Taunt — eye; own SV masks.
- [ ] Thunder Wave — electric; own SV masks.
- [ ] Toxic — arc; own SV masks.
- [ ] Will-O-Wisp — flames; own SV masks.

### Self

- [ ] Agility — spin; own SV masks.
- [ ] Calm Mind — charge; own SV masks.
- [ ] Charge — charge; own SV masks.
- [ ] Defense Curl — shield; own SV masks.
- [ ] Double Team — spin; own SV masks.
- [ ] Dragon Dance — spin; own SV masks.
- [ ] Focus Energy — charge; own SV masks.
- [ ] Growth — charge; own SV masks.
- [ ] Harden — shield; own SV masks.
- [ ] Howl — sound; own SV masks.
- [ ] Nasty Plot — eye; own SV masks.
- [ ] Recover — heal; own SV masks.
- [ ] Roost — heal; own SV masks.
- [ ] Swords Dance — swords; own SV masks.
- [ ] Withdraw — shield; own SV masks.

### Field

- [ ] Aurora Veil — shield; own SV masks.
- [ ] Chilly Reception — snow; own SV masks.
- [ ] Court Change — portal; own SV masks.
- [ ] Defog — mist; own SV masks.
- [ ] Electric Terrain — terrain; own SV masks.
- [ ] Future Sight — eye; own SV masks.
- [ ] Grassy Terrain — terrain; own SV masks.
- [ ] Haze — mist; own SV masks.
- [ ] Light Screen — shield; own SV masks.
- [ ] Misty Terrain — terrain; own SV masks.
- [ ] Protect — shield; own SV masks.
- [ ] Psychic Terrain — terrain; own SV masks.
- [ ] Reflect — shield; own SV masks.
- [ ] Spikes — spikes; own SV masks.
- [ ] Stealth Rock — spikes; own SV masks.
- [ ] Sticky Web — web; own SV masks.
- [ ] Substitute — portal; shared SV masks.
- [ ] Teleport — portal; own SV masks.
- [ ] Toxic Spikes — spikes; own SV masks.
- [ ] Wish — heal; own SV masks.

### Z

- [ ] 10,000,000 Volt Thunderbolt — electric; shared SV masks.
- [ ] Acid Downpour — orb; shared SV masks.
- [ ] All-Out Pummeling — flurry; shared SV masks.
- [ ] Black Hole Eclipse — pulse; shared SV masks.
- [ ] Bloom Doom — leaves; shared SV masks.
- [ ] Breakneck Blitz — dash; shared SV masks.
- [ ] Catastropika — dash; shared SV masks.
- [ ] Clangorous Soulblaze — sound; shared SV masks.
- [ ] Continental Crush — rain; shared SV masks.
- [ ] Corkscrew Crash — spin; shared SV masks.
- [ ] Devastating Drake — orb; shared SV masks.
- [ ] Extreme Evoboost — portal; shared SV masks.
- [ ] Genesis Supernova — pulse; shared SV masks.
- [ ] Gigavolt Havoc — electric; shared SV masks.
- [ ] Guardian of Alola — orb; shared SV masks.
- [ ] Hydro Vortex — storm; shared SV masks.
- [ ] Inferno Overdrive — flames; shared SV masks.
- [ ] Let’s Snuggle Forever — hearts; shared SV masks.
- [ ] Light That Burns the Sky — burst; shared SV masks.
- [ ] Malicious Moonsault — kick; shared SV masks.
- [ ] Menacing Moonraze Maelstrom — pulse; shared SV masks.
- [ ] Never-Ending Nightmare — pulse; shared SV masks.
- [ ] Oceanic Operetta — sound; shared SV masks.
- [ ] Pulverizing Pancake — dash; shared SV masks.
- [ ] Savage Spin-Out — web; shared SV masks.
- [ ] Searing Sunraze Smash — burst; shared SV masks.
- [ ] Shattered Psyche — pulse; shared SV masks.
- [ ] Sinister Arrow Raid — orb; shared SV masks.
- [ ] Soul-Stealing 7-Star Strike — flurry; shared SV masks.
- [ ] Splintered Stormshards — rain; shared SV masks.
- [ ] Stoked Sparksurfer — dash; shared SV masks.
- [ ] Subzero Slammer — snow; shared SV masks.
- [ ] Supersonic Skystrike — storm; shared SV masks.
- [ ] Tectonic Rage — quakes; shared SV masks.
- [ ] Twinkle Tackle — hearts; shared SV masks.
