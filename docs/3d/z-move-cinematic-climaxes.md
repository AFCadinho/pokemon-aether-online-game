# Cinematic Z-move finales

Supersonic Skystrike is the player-approved reference for this pass. The other
34 Z-moves now have individually authored finales in
`data/battle_z_climaxes_3d.json`; their updated presentations are pending player
review. Charge and delivery retain their existing choreography and native
timing. These are stylized interpretations, not original-game animation assets.

Each confirmed hit compresses, expands and dissipates within its existing
recovery. Camera framing reserves the full effect volume; light, recoil and
shader motion use the same paused native clock. Late-impact moves keep the
climax framed before returning to the overview. Misses and blocks retain their
delivery without the hit explosion or added impact sound. Extreme Evoboost
uses a user-centred aura, with no damage flash or camera recoil.

The existing per-move audio remains, with a quieter, individually pitched layer
of the packaged explosion impact on 33 damaging moves. No new sound files or
runtime dependencies are needed. Skystrike's dedicated explosion is unchanged.

Bloom Doom keeps its field flowers, replacing the old flat light shaft with
a three-dimensional flower burst. All other damaging finales replace the
lingering delivery form at impact, preventing overlapping cages/projectiles
from obscuring the blast.

| Move | Finale |
| --- | --- |
| 10,000,000 Volt Thunderbolt | Rainbow lightning converges into a white-gold detonation with eight branching arcs. |
| Acid Downpour | An acidic column bursts into a purple-green splash crown and spreading caustic wave. |
| All-Out Pummeling | The final punch releases a forward pressure cone with a thick amber blast. |
| Black Hole Eclipse | The singularity contracts, then releases a violet event-horizon shock shell. |
| Bloom Doom | A luminous flower opens into eight broad petals around an ascending golden seed blast. |
| Breakneck Blitz | A fast horizontal ram produces a flattened dust blast and a forward bow shock. |
| Catastropika | A compact gold flash erupts upward with a crown of electric fangs. |
| Clangorous Soulblaze | A dragon pulse detonates in three rolling shells edged with resonating golden scales. |
| Continental Crush | The boulder breaks into six heavy slabs through a dense low dust explosion. |
| Corkscrew Crash | A silver impact cloud opens into a corkscrew of broad metallic pressure arcs. |
| Devastating Drake | The dragon releases a violet-blue explosion with three claw-shaped energy plumes. |
| Extreme Evoboost | Eight evolution colours merge into a rising aura and open around the user. |
| Genesis Supernova | Psychic energy erupts into a pink supernova crossed by two tilted expanding shock planes. |
| Gigavolt Havoc | A vertical lightning blast splinters into six ground-reaching electric branches. |
| Guardian of Alola | The giant fist drives a golden impact dome into the floor with four broad rays. |
| Hydro Vortex | The vortex ruptures into a high rotating water crown and a broad circular surge. |
| Inferno Overdrive | A white-hot ignition becomes a rolling orange fireball with rising flame tongues. |
| Let’s Snuggle Forever | The shroud crushes inward before a low pink-black blast spills out beneath it. |
| Light That Burns the Sky | An immense white-gold core blossoms into a solar nova with eight long radial rays. |
| Malicious Moonsault | A low crimson explosion and a tilted fiery cross mark the wrestling impact. |
| Menacing Moonraze Maelstrom | A violet lunar column bursts into a high ghostly plume surrounded by crescent shock arcs. |
| Never-Ending Nightmare | Shadow tendrils close into a dark knot, then release a violet shock shell. |
| Oceanic Operetta | The water orb bursts into a wide pearl-blue dome and a flowering crown of water. |
| Pulverizing Pancake | A massive low dust pancake blasts sideways from the body slam with a fast floor wave. |
| Savage Spin-Out | The cocoon splits into six sweeping silk ribs around a green-white rupture. |
| Searing Sunraze Smash | The solar strike drives a brilliant pillar through a spreading gold-orange explosion. |
| Shattered Psyche | A compressed psychic core shatters into eight broad rotating prism plates and a pink pulse. |
| Sinister Arrow Raid | The converging arrows raise six spectral lances through a turquoise ghost blast. |
| Soul-Stealing 7-Star Strike | Seven spirit rays contract into the final fist before a blue-white star-shaped detonation. |
| Splintered Stormshards | Seven large rock splinters fan out through a rising dust blast after the stone barrage. |
| Stoked Sparksurfer | A rolling electric bow wave breaks outward with teal foam and gold lightning. |
| Subzero Slammer | The ice prison fractures into six large glacial shards through an expanding cold vapour cloud. |
| Tectonic Rage | Six towering fault slabs rise in a ring through a hot dust eruption and ground pressure front. |
| Twinkle Tackle | The fairy comet blossoms into six broad pink light petals around a pearly detonation. |

## Focused verification

- `z_move_cinema_check.tscn`: 35 moves, singles/doubles, all actor slots, hits,
  misses and blocked outcomes, full explosion bounds in five recovery phases,
  native pause, disabled camera motion, weather restoration, natural cleanup and
  weak-reference checks that each new climax instance is released.
- `z_move_choreography_check.tscn`: unchanged source hashes and duration, three
  native clip lengths, contact timing and hit-gated audio markers.
- `z_move_choreography_preview.gd -- --moves --smoke-z`: GPU playback and five
  captures per move, plus reversed miss/block cases. Use `POKEAETHER_STAGE_OUTPUT`
  for a slot-local output directory and `POKEAETHER_Z_PREVIEW_MOVES` for a subset.

Run Godot through `ops/worktrees/slot-env SLOT --` from the workspace root.
Screenshots and logs remain in the assigned slot's ignored runtime directory.
These focused checks do not certify the full release or low-end GPU performance.
The full Z-check/preview can still report two zero-reference `RefCounted` objects
at Godot shutdown. Their origin is unresolved; the new climax instances pass
explicit release checks. No script, shader or assertion errors occurred in the
completed checks. The existing 24-move effects regression also passes.
