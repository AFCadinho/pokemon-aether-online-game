# Optional desktop battle presentation

The default remains **2.5D — sprites**. The overworld, battle rules, networking,
HP state and replay event renderer are unchanged. The experimental 3D layer
observes SpriteBox presentation actions and provides projected effect anchors.

## Try it

In Settings → General, choose **3D — experimental desktop** under Battle
presentation. Use **Choose local 3D preview report…** to select the generated
PBR GLB `report.json`. The file chooser saves its path, so subsequent client
launches need no environment variable. For developer testing only,
`POKEAETHER_3D_STAGE_REPORT` supplies a fallback path when no path is configured.

The current local study report is:
`/home/adinho/Desktop/pokemonaetheronline/game/.worktrees/slot-c/.tmp/battle-stage-pbr-01/glb/report.json`

Normal Dragonite and Roaring Moon are supported. Test a single battle with
those active species. Unsupported species, shiny variants, doubles, substitutes,
and visible field hazards/screens use the existing 2.5D presentation for both
sides. A temporarily empty slot during a switch can remain in 3D. Selecting
2.5D restores the sprites and releases imported model references.

## Scope and limitations

- This is a desktop opt-in prototype, not the production catalog or delivery
  system. It performs no downloads and bundles no GLBs or outdoor demo assets.
- The integrated arena is original simple geometry with a fixed perspective
  camera. The separate outdoor camera study remains available; it is not the
  production arena. Camera choreography and 3D move VFX are future work.
- Models are imported synchronously on first use of a selected report. A
  first-use loading hitch remains possible. At most the two supported species
  are retained. Existing sprite resources remain available underneath for
  fallback; this prototype is not a final memory or download optimization.
- Current source material translation is not a visual-parity guarantee.
  Hover bounds are conservative projected bounds, and existing battle event
  waits still control transitions. Faint/capture/switch polish needs live review.
- Android and web keep 2.5D. No support or performance claim is made for 3D on
  those platforms.

## Focused checks

Run `tests/battle_3d_presentation_check.gd` through `ops/worktrees/slot-env`.
Without a report it checks the default and missing-report fallback. With
`POKEAETHER_3D_STAGE_REPORT` it also checks model loading, actions, an empty
slot, shiny/substitute fallback, projected anchors, teardown and a recorded
Dragon Pulse/damage response through the real replay renderer. This is a
synthetic replay fixture, not a live backend battle test.

Related regression checks: `settings_interface_revamp_check.gd`,
`battle_animation_anchor_check.gd`, and `battle_substitute_presentation_check.gd`.
