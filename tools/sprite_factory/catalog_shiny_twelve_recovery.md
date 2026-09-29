# Twelve held shiny pairs: correction checkpoint

These are review candidates, not approved catalog additions. The existing
671 base species plus Mega Dragonite remain unchanged. The 151-case ledger
still has twelve visual holds until the user reviews these exact candidates.

`catalog_shiny_twelve_recovery.json` pins 24 corrected GLBs and standalone
Godot scenes, their source tables/textures, motion files, reconstruction
scratch recipes and the displayed captures. All 176 skeletal clips and every
geometry/skin/UV accessor match the preceding pair candidates. The capture
reports contain no rendering errors. Four focused UV bake tests pass.

## Corrections

- Doublade, Helioptile, Heliolisk, Marshadow, Meltan and Melmetal: restore
  source mesh visibility per action; alternate eyes and body parts previously
  appeared together. Inkay, Xerneas and Yveltal also receive the matching
  visibility tracks. All nine have exact selected clip clocks and mesh sets.
- Litwick: convert flame colours from linear source values and restore head
  selection. Animated faint clocks match. Other bound head tracks are constant;
  attack 2 explicitly reuses attack 1's constant selection as a review proposal.
  ZA-only eyelid meshes are absent from the original Blend and are excluded.
- Yveltal and Marshadow: bake the second UV set's colour masks onto the existing
  base atlas. The tested masks have no conflicting overlapping samples.
- Xerneas: restore the fifth mask's UV binding and layered emission. Emitting
  coverage suppresses the diffuse contribution to approximate the source's
  emission blend. This is a static PBR translation; full native animated
  emission is not claimed.
- Meltan and Melmetal: use source metallic layers rather than only the zero
  base metallic scalar.
- Inkay: use the matching ZA eye atlas and native repeating UV animation;
  the SCVI atlas has a different expression layout. Complex eye clearcoat
  normal mapping is omitted in this review candidate.
- Inkay, Cosmog and Cosmoem: reconstruct colour/normal/alpha layers. Transparent
  refraction uses the existing reviewed alpha-mix diagnostic path. Full native
  iridescence remains approximated and needs visual qualification.

## Next gate

The browser page is the receipt's `review_url`, with before/after, normal/shiny,
idle, attacks, sleep and faint captures. The local server serves the slot's
frontend on loopback port 8765. After appearance acceptance, run battle
placement/motion qualification for these exact scenes. Only then may catalog
admission and individual bundle validation follow.

Scratch recipes remain under `.tmp/shiny-151-recovery/twelve`, pinned in the
receipt. They deliberately have not replaced production catalog tooling while
visual review is pending. Keep this task slot and those files. Do not overwrite
or regenerate a displayed candidate after recording user approval without
invalidating that approval.
