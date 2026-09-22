# Summary preview regression review — 2026-09-22

The summary preview now reuses the existing animation MenuButton above the
level badge and the existing zoom toggle. It no longer creates a second toolbar.
Framing uses skinned idle geometry rather than a static mesh bounding sphere.
The summary-only artificial platform is hidden; it clipped native poses below
world Y=0. The Pokédex platform and battle placement are unchanged.

Playback restores node transforms and skeleton poses, samples RESET/idle, then
starts the selected action. Selecting faint_loop first samples the end of
faint_start. No shared animation resources or model hashes are changed.

## Remaining Garchomp source issue (not fixed by UI changes)

The current runtime Garchomp SCN has SHA-256
`ed744834e77386e45a805f66095e5353c831ab6dfa9dac707ebc0b67366110a8`.
Its export provenance in slot-b's
`.tmp/catalog-100-identity-final/catalog.json` records:

- idle: `pm0445_00_00_00001_battlewait01_loop`
- physical_attack: `pm0445_00_00_20400_attack01`
- special_attack: `pm0445_00_00_00450_rangeattack01`
- damage: `pm0445_00_00_20500_damage01`
- faint_start/loop: `pm0445_00_00_20520_down01_start` /
  `pm0445_00_00_20521_down01_loop`

Rendered inspection shows upright idle but horizontal damage, even after a
complete pose reset. The regression test verifies identical damage bone/node
transforms before and after faint_loop, ruling out previous-pose contamination
as the explanation for that remaining shape change.

The inventory lists corresponding 00-series attack/damage/down alternatives.
`scvi_batch.source_entry` ranks each action independently by suffix and prefix;
it does not require a coherent motion family relative to idle. This is a likely
generic selection problem, not evidence that Garchomp needs a custom offset.
The family meaning still needs confirmation by rendering the alternate sources.

Next: compare the 00-series damage/down alternatives with idle, correct motion
family selection with fixtures for mixed-family and single-family sources, then
re-export/review Garchomp and update its hash-bound catalog entry through the
existing workflow. Do not silently rewrite reviewed SCNs or approve a replacement
based only on successful conversion. No source mapping/catalog change was made
as part of this UI correction.

## Focused verification

`tests/summary_model_preview_check.gd` exercises the real card play menu, all
available Garchomp clips, replay, zoom, faint-to-damage pose determinism,
refresh reuse, hidden rendering, independent Azumarill playback, and shiny
sprite fallback. Optional SUMMARY_CAPTURE saves idle/faint/damage screenshots.
