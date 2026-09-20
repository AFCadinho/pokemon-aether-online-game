# Desktop Battle UI

Settings → Battle UI (next battle) selects Immersive (default) or Classic.
This is independent of 2D/3D presentation and arena selection. Desktop Immersive
uses the dedicated battle screen even for 2D fallback. Browser/mobile retain
their existing embedded layout.

Immersive gives the arena the full screen, places smaller HP panels above the Pokémon, keeps
moves on the bottom right and the existing party controls near the bottom center.
Battle log is a collapsible floating panel, with a separate calculator button.
The player team preview stays on the left; switch controls sit below the centered
battle message, reserving bottom-left space for future chat. The opponent team
stays visible at the edge. Compact moves and mechanics share the bottom-right area. HP panels
smoothly follow projected actor bounds with screen-edge clamping; 2D fallback
uses the sprite hover bounds. These are presentation-only positions, not combat state.
Classic retains its original scene hierarchy and framed layout. Changes apply
on the next battle, not during an action. Rendering, switching, move signals,
network authority and the overworld return flow remain shared.

The layout is applied before the battle enters the tree: moving an already-live
renderer would invoke its teardown hooks. No duplicate battle or model views
are created. The stage expands its logical width/height on unusual aspect ratios
instead of cropping controls. The host preserves uniform scaling.

## Local forest setup

An explicit forest manifest in Settings always wins, including a missing path
(reported as an error rather than silently substituted). With an unset path,
the editor executable checks only `forest-runtime/forest.json` alongside the
review directory containing the explicitly selected `glb/report.json` catalog.
This supports the existing trusted local review artifacts without copying them.
Exported player builds do not discover or mount such local native extensions.
Release packaging remains a separate task. The known forest load hitch is not
addressed by this layout change.

## Focused checks

- `battle_immersive_layout_check.gd`: Classic/Immersive, four aspect/resolution
  cases, log toggle stability, control bounds and forest discovery/explicit priority.
- Existing `battle_ui_layout_check.gd`: unchanged Classic contracts and controls.
- `battle_screen_host_check.tscn`: screen lifecycle, overworld restoration and
  real switch clicks with hover cards (no network submission).
- `battle_3d_presentation_check.gd`: select `POKEAETHER_TEST_UI_LAYOUT=immersive`
  and `POKEAETHER_TEST_ARENA=stadium` or `forest` for the real replay/action lifecycle.
