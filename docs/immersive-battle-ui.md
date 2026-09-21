# Desktop Battle UI

Settings → Battle UI (next battle) selects Immersive (default) or Classic.
This is independent of 2D/3D presentation and arena selection. Desktop Immersive
uses the dedicated battle screen even for 2D fallback. Browser/mobile retain
their existing embedded layout.

Immersive gives the arena the full screen, places smaller HP panels above the Pokémon, keeps
moves on the bottom right and the existing party controls near the bottom center.
Battle Log and Chat share a resizable bottom-left panel. Damage Calculator has
its own button above the tabs; Reset camera is a separate top-right button.
The player team preview stays on the left; switch controls sit below the centered
battle message, with the existing chat in the bottom-left space. The opponent team
stays visible at the edge. Compact moves and mechanics share the bottom-right area. HP panels
smoothly follow projected actor bounds with screen-edge clamping; 2D fallback
uses the sprite hover bounds. These are presentation-only positions, not combat state.

The dedicated screen temporarily exposes only chat controls from the existing
UIOverlay in place, so channels, PMs, mute rules, history and submission callbacks
remain the same. It creates no socket and does not replay received messages.
Other overworld panels and shortcuts remain suspended. Enter focuses chat when
not already typing; Enter in the input follows the existing send handler once.
Escape or a click outside chat releases typing; battle hotkeys ignore text focus.
Each new battle selects Battle Log, regardless of the previous battle's tab.
Chat retains its channel tabs and draft; Enter switches to Chat and focuses input.
Release restores panel geometry,
visibility, opacity, layer and input processing without clearing the draft.

`battle_chat_bridge_check.gd` exercises the real screen and battle with a synthetic
chat UI: focus, one submission signal, battle-shortcut isolation, simultaneous
log/chat bounds and idempotent restore. It does not send live chat messages.
Classic retains its original scene hierarchy and framed layout. Changes apply
on the next battle, not during an action. Rendering, switching, move signals,
network authority and the overworld return flow remain shared.

The layout is applied before the battle enters the tree: moving an already-live
renderer would invoke its teardown hooks. No duplicate battle or model views
are created. The stage expands its logical width/height on unusual aspect ratios
instead of cropping controls. The host preserves uniform scaling.

## Immersive typography

Immersive also supports the sprite renderer. While realtime 3D is inactive, its
sprite/platform groups are composed at 82% of the original size, centered at
38%/65% of stage width and 59%/46% of stage height. Relative platform/sprite-box
offsets, local animation motion and hazard children are preserved. HP panels
track the sprite bounds. Camera reset is visible only for an active 3D presenter.
Classic is unchanged; this does not modify native 3D camera or actor placement.

The calculator uses frame bounds converted into drawer-local coordinates.
Immersive uses a 60/40 results/settings workspace with independent scroll areas.
Below 1500 pixels it switches to Results/Settings tabs. Recalculation preserves
the selected workspace tab and scroll positions. Existing calculations and
requests are unchanged. Chat/log is temporarily hidden while the calculator is
open. Classic keeps its original two columns.
Stat/ability badges are positioned after the moving HP panels by the Immersive
HUD controller, not the legacy sprite-position helper. Side effects follow below.
Overlapping HP panels are separated vertically.

`immersive_typography.gd` uses a private MSDF font with a CJK fallback, and
compensates font sizes for inherited screen transforms. Existing layout geometry
and render targets are unchanged. Main text uses 16 screen pixels, move names and
the current message 18, secondary details 14, and switch slots 12–13. Hover cards
also cancel their inherited scale. Overworld chat font overrides are restored on
release; Classic does not install this helper.

`battle_typography_check.gd` checks effective text sizes and hover bounds at
1280×720, 1920×1080 and 2560×1440, with optional rendered screenshots.
It also checks badge tracking, HP-panel separation, calculator frame bounds and
four-move results, independent panes and compact-tab persistence. The chat bridge
test checks calculator occlusion.
The existing `battle_calcdex_matchup_check.gd` still reports two SampleSetField
assertions: both were reproduced with the calculator script reverted to the
pre-change version. HP-scale and stat-stage operation checks pass separately.

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

### Resizable chat and user camera

Battle Log and Chat are now primary tabs; channel tabs only appear under Chat.
The top grip changes panel height (saved in `immersive_chat_height`), constrained
to the lower-left area below the team rail. Height changes never scale the text.
Channel-tab fitting is independent of content font scaling. Small windows retain
the existing proportional UI fit. Chat drafts and original send handlers survive
tab changes. The central prompt now sits directly above the switch slots.

Left-button dragging over the free arena orbits the 3D camera, with bounded pitch
and unrestricted yaw. HUD/chat/resize controls do not initiate a drag. Release
or focus loss stops dragging; `Reset camera` in the tools menu restores baseline.
Attack/switch animation shots temporarily block orbit input because existing
screen-space effects capture anchors. Gentle motion remains the baseline and
the material-response camera follows the same transform. Camera input is only
installed for Immersive and only operates with an active 3D presenter.

The Immersive refinement adds corner portraits from existing appearance state
(NPCs use existing trainer art), mirroring the existing timed trainer commands.
Wild opponents have no trainer portrait. Spectator/replay identities never fall
back to the local player's avatar. Original command routing is unchanged.

The temporary Battle Log chat tab mirrors the authoritative formatted log buffer,
marks unseen updates and preserves the original chat draft/history/send path.
Selecting another chat tab returns to chat; Enter from the log returns to typing.
Release removes the temporary controls and connections and restores chat bounds.
Without an overworld chat (offline fixtures), Battle Log remains in the tools menu.
Damage Calc is also available there. The old debug arena label is hidden only in
Immersive. Central battle messages remain visible independently of the log tab.

- `battle_chat_bridge_check.gd`: draft preservation, one send, unread indicator,
  tab switching, keyboard focus, temporary tab cleanup and restored chat bounds.
- `battle_immersive_combat_preview.gd`: real 3D offline visual fixture with corner
  portraits, command callouts, moves, modifier and non-overlapping switch controls.

- `battle_immersive_layout_check.gd`: Classic/Immersive, four aspect/resolution
  cases, log toggle stability, control bounds and forest discovery/explicit priority.
- Existing `battle_ui_layout_check.gd`: unchanged Classic contracts and controls.
- `battle_screen_host_check.tscn`: screen lifecycle, overworld restoration and
  real switch clicks with hover cards (no network submission).
- `battle_3d_presentation_check.gd`: select `POKEAETHER_TEST_UI_LAYOUT=immersive`
  and `POKEAETHER_TEST_ARENA=stadium` or `forest` for the real replay/action lifecycle.
