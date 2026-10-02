# Battle entry platform checks — 2026-10-02

Baseline: local development `41c9afd2e` (sprite wait removal and deferred trainer
vision updates included). Godot 4.6.2. No product code changed for this check.

| Runtime | Result | Rendered fade levels |
| --- | --- | --- |
| Real Chromium Godot Web export, WebGL 2, 1280×720 | PASS | 6 |
| Fresh Chromium context, 844×390 | PASS | 6 |
| Samsung SM-G780F, Android 13, Mali-G77, Compatibility/OpenGL ES 3.2 | PASS | 7 |

Each runtime passed:

- A real `Area2D.body_entered` callback defers the trainer sensor update until
  physics finishes flushing. Disabled vision and subsequent three-tile,
  right-facing vision both work without the reported physics error.
- The fullscreen battle host and actual 2D battle scene render multiple fade
  levels even after a simulated 250 ms loading stall. World snapshot handoff,
  restoration and cancellation checks also pass.
- A cold sprite request uses a local HTTP fixture with a six-second metadata
  delay. Normal encounter prefetch returns within 500 ms, the battle becomes
  fully visible while the download is still pending, and downloaded frames
  subsequently appear in the sprite cache.

The native mobile-control check also passed. The separate debug Android
package `com.pokeaether.battleentryqa` was installed, run and removed. The
existing game package was left unchanged, and the USB reverse port was removed.

These are offline presentation/physics regression checks with real platform
runtimes. They do not test a logged-in server-created encounter, production
asset delivery, full battle gameplay, or device-wide performance. The delayed
sprite uses a small synthetic sheet. Pixel readback used to verify the fade can
itself affect frame timing; the number of blend levels is not an FPS benchmark.
Known UID path-fallback warnings were retained. No Godot runtime errors occurred
in the final browser or Android runs. The Android diagnostic disables automatic
music/APK update checks so it never needs production access.

## Repeat in an assigned slot

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/export_battle_entry_web_qa.py --output .worktrees/slot-c/.tmp/web-battle-entry
ops/worktrees/slot-env slot-c -- env NODE_PATH=/home/adinho/.npm-global/lib/node_modules node .worktrees/slot-c/frontend/tests/web_battle_entry_smoke.cjs .worktrees/slot-c/.tmp/web-battle-entry
```

For Android, use the same export tool with `--platform android --sdk SDK_PATH`
and an Android output directory. It supports `--java` and `--templates` for
machine-specific build tools. Export runs through `slot-env`, uses a separate
application ID and restores temporary project, preset and slot editor settings.
The diagnostic adapters wrap existing SceneTree checks as Node checks without
changing their assertions; generated adapters are removed after export.

Start the local HTTP fixtures with the Node command above plus `--serve`, then
use `adb reverse tcp:8091 tcp:8091`. Install the exported debug APK using
`adb install --no-incremental`, and launch its MAIN/LAUNCHER intent. Read only
this diagnostic package's `files/battle-entry-qa-results.json` and Godot log
through `adb shell run-as com.pokeaether.battleentryqa`. All three result codes
must be zero, with no runtime errors. Stop and uninstall the diagnostic package,
remove the reverse port and stop the fixture server after testing.

Local reports were generated under the slot's `.tmp/web-battle-entry` directory;
these are diagnostic artifacts, not a deployable candidate or certification.

## Full game USB update — 2026-10-02

The same Samsung SM-G780F received the full `com.pokeaether.game` development
client from source commit `742cc50f7929a6242ac900a690ab090e829a6766` by USB.
Its display version is `0.3.90-usb-742cc50`, Android version code 8 and local
build ID `usb-742cc50f7929-20261002`. This includes the battle fade, removal of
the normal-encounter sprite wait, and deferred trainer vision updates.

The release certificate matched the installed 0.3.90/code 7 game. The full
Gradle export passed package/version/certificate checks and the Android
on-demand asset partition check. The seven Android release tooling tests also
passed. `adb install --no-incremental -r` succeeded; package metadata confirmed
code 8, the intended display version, the unchanged signature and the same
existing app data directory identity after installation.

This first USB candidate retained the installed 0.3.90 candidate's asset build
ID and declared compatibility with that build; no assets or APK were published. It was
not automatically launched for a logged-in encounter. Installation verification
does not establish the full game's battle behavior or performance; the player
can now try those changes in the installed game.

### Login compatibility correction

Player testing found that login still required an update to 0.3.89. The public
gateway Android version endpoint requires build
`bf5d0bbc63e1e99575891c8558329d4e2f63b6ca-36708144268-1`, rather than the
installed 0.3.90 candidate's identity. The installed APK's signature/version
checks did not establish which build the gateway accepts. USB candidates must
use the gateway's required identity for compatibility and independently verified
published assets, while retaining their own source/build/version identity.

The 0.3.89 build does not expose the new Android mobile asset catalog. The
0.3.90 candidate's published catalog is available with 4,025 entries under
`4166209c9ad0a7b10afaabe0b40443421d9fb61a-36723315492-1`. The corrected USB
candidate therefore uses the required 0.3.89 identity for login compatibility
and the verified 0.3.90 identity for assets. Both IDs remain explicitly pinned;
candidate compatibility is not broadened to arbitrary server requirements.

The replacement full game uses display version `0.3.90-usb-fix2-875441a`,
Android code 10 and local build ID `usb-875441a40436-20261002-fix2`. APK
inspection confirmed both pinned IDs inside the exported `project.binary`;
the compatibility ID was compared with the current public gateway response
and the asset catalog was fetched successfully before USB installation.
The full export, certificate/version checks, seven Android release tests and
Godot `client_version_contract_check` passed. In-place USB installation
succeeded and package metadata confirmed code 10 and unchanged app data
directory/signature. Logged-in gameplay remains for the player to verify.

## Native Android layout restoration — 2026-10-02

The mobile-browser responsive layout is now selected independently from touch
input. Native Android keeps its original login split, settings navigation,
expanded HUD panels, independent panel toggles, chat sizing/tabs, 50-unit quick
buttons and 1500-unit immersive battle design. Keyboard avoidance still uses
touch capability; fullscreen battle fading remains enabled.

`mobile_browser_ui_check` now checks the native touch layout before exercising
the compact browser layout. It passed, as did `mobile_keyboard_avoidance_check`
(41 checks) and `fullscreen_battle_fade_check`. The signed full export passed
package/version/certificate and asset partition checks.

The full client from `b50337e5cffe8c6ba0673597f75396ccb0a08a23` was installed
over the existing game on the Samsung SM-G780F by USB. Display version:
`0.3.90-usb-ui-b50337e`; Android version code: 11. Package metadata confirmed
the intended version and retained signature/app data directory. The login
compatibility and available asset IDs from the corrected candidate remain
explicitly pinned and were checked inside the APK before installation.
Automated layout checks use real scenes in the desktop Godot runtime; the
player can now verify the presentation in the installed Android game.

## Keyboard avoidance in the original Android layout — 2026-10-02

Device testing reproduced that the field position from
`CanvasItem.get_screen_transform()` omitted the root viewport stretch. With
Android's 125% content scale, the helper shifted the field insufficiently even
though the reported Samsung keyboard height (594 physical pixels) was correct.
The helper now combines the viewport screen transform with the control's
global canvas transform, both for measuring the field and converting the
required movement back to parent coordinates.

The expanded keyboard regression runs at viewport factors 1, 1.25 and 1.5 and
multiple parent scales. It produced 24 failures with the previous helper and
passed all 101 checks with the fix. The native/browser UI layout check passed.

An isolated, offline Android probe (`com.pokeaether.keyboardqa`) used the actual
helper on the Samsung SM-G780F with its native keyboard. The corrected field
occupied physical y=395..470 while the keyboard began at y=486: the full field
was visible with a 16-pixel margin. Synthetic typing succeeded. Closing the
keyboard restored the original position and zero translation. Screenshot
inspection confirmed the visible field. The diagnostic was stopped and removed;
the existing game data was not accessed or cleared. The probe tests the real
Android transform/keyboard behavior; it is not a logged-in chat gameplay test.

The full signed game from `c690519e0de1` was installed in place by USB as
`0.3.90-usb-keyboard-c690519`, Android code 12. Export/certificate/version and
on-demand partition checks passed; exported compatibility/asset IDs were
verified before installation. Package metadata confirmed the intended version,
unchanged signing identity and the retained app data directory. No app data was
cleared, and no APK or assets were published.

## Start the arena before wild encounter requests — 2026-10-02

Normal wild encounters previously saved the position and awaited battle creation
before mounting the arena. The shared entry path now mounts a prewarmed arena
and starts its fade before either request. Prewarming covers fullscreen desktop
and browser layouts as well as Android. A layout/presentation change invalidates
the cached screen. Unknown combatants, party cards, status and actions remain
hidden; authoritative preparation restores their visibility. Input stays locked
while the response is pending. Server rejection tears down the pending arena and
restores the overworld. Trainer/PvP/co-op entry paths are unchanged.

Focused checks:

- `wild_entry_before_response_check`: passed headless and in the rendered Linux
  desktop client (Immersive 2D). The real world entry method reuses its prewarmed
  scene and starts fading while the position request is deliberately blocked.
  The arena remains fully visible through the subsequent blocked battle request;
  authoritative preparation clears pending state and rejection restores the world.
  Screenshots inspected after the final visibility change show the arena and
  local trainer portrait without default Pokémon/party cards or action controls.
- `fullscreen_battle_fade_check`: passed headless and rendered, with nine actual
  intermediate pixel levels after a simulated 250 ms loading stall.
- `wild_encounter_transition_check`: passed, including Classic overlay coverage.
- Offline Chromium diagnostics passed all four entry checks at 1280×720 and
  844×390, without external requests or Godot/browser runtime errors. That export
  preceded the final hiding of the pending utility/status/party containers; the
  final visibility behavior was verified in the rendered desktop check.

An additional `battle_arena_kind_integration_check` hit its existing line-41
expectation: the test requests 2.5D but expects environment-specific 3D arenas.
The unchanged renderer in the task base intentionally returns `classic` for
2.5D. This unrelated test contract was not changed as part of the entry fix.

The phone was not connected; the player requested desktop testing first. No
Android APK was built or installed for this change. These offline checks do not
certify logged-in gameplay or guarantee zero CPU/GPU stalls on every device;
they verify that position/battle responses no longer gate the wild arena fade.

## Final element sizes from the first fade frame — 2026-10-02

The early arena reveal exposed a layout issue: `ImmersiveHud` skipped all work
while entry was pending, so platforms/sprite boxes and HUD controls retained
their original scene scales until the response arrived. The HUD now computes
geometry during pending entry while combatants/actions remain hidden. The host
also settles the stage's margin layout and transform, portraits, HUD and fonts
synchronously before reveal; pending setup and authoritative wild preparation
refresh that geometry before controls become visible. No timer or network
readiness gate was added. Classic presentation is unchanged.

The expanded `wild_entry_before_response_check` reproduced 21 scale failures
with the task base. With the fix it passed headless and rendered on Linux. It
checks final component scales before the first frame, across the first fade
frames and after authoritative setup; global scales for the battle, stage,
platforms, sprite boxes, HP panels and moves remain unchanged throughout.
Rendered pending/after-setup screenshots were inspected: platforms retain their
final size and position when the hidden HUD is restored.

`fullscreen_battle_fade_check` passed headless and rendered, observing ten
intermediate pixel levels after a 250 ms loading stall.
`wild_encounter_transition_check`, `battle_immersive_2d_hud_check`, and
`battle_immersive_layout_check` passed. The layout check covers Classic and
Immersive at six desktop dimensions. Existing asset UID fallback warnings and
the layout check's exit-time ObjectDB warning remain.

This follow-up was tested first on desktop as requested. Browser/Android and
logged-in player encounters were not rerun; no APK was installed or published.

## NPC battle entrance latency — 2026-10-02

The trainer path still had a fixed 350 ms pause after closing intro dialogue,
then awaited position saving and battle creation before mounting the screen.
Normal NPC setup also held the screen behind two sequential automatic lead
requests. Metadata/dialogue retrieval and a fresh co-op admission check happen
earlier; those authority/story checks remain unchanged. This investigation
identified the code gates, rather than measuring live server timings.

The fixed post-dialogue pause is removed. Fullscreen solo trainer entry now
reuses the prewarmed arena, sets the real trainer/environment context and begins
fading before position/battle responses. Known trainer portraits stay visible.
During automatic leads, combatants, party/action/status controls and mechanical
preview layers remain hidden and transparent; response-driven `show()` calls
cannot expose them prematurely. Pending visibility/alpha is restored when the
lead flow finishes, including lead errors. Configured interactive Team Preview
leaves pending state before its input phase. Classic trainer transition styles,
co-op admission, server request ordering, lead choices and summon animations
remain intact.

`trainer_entry_before_response_check` passed headless and in the rendered Linux
desktop client. Controlled fixtures block position, battle creation, player
lead and NPC lead requests; the arena is visible during those waits. They check
cached scene reuse, trainer context/portrait, action locks, alpha protection
against intermediate response visibility, failed-start cleanup and interactive
preview readiness. Lead tests use the real default lead orchestration with
fixture transport responses; they do not measure actual AI/network latency.
The rendered creation-pending and leads-pending screenshots were inspected and
are pixel-identical, retaining both trainer portraits and final platform sizes.
The X11 window manager reported a transient BadMatch during some diagnostic
window resizing runs; the fixture assertions and captured images passed.

`wild_entry_before_response_check`, `wild_encounter_transition_check`,
`npc_battle_team_reveal_check`, `dialogue_metadata_service_check` and
`trainer_dialogue_cleanup_check` passed. Browser/Android and logged-in NPC
gameplay were not rerun. No APK was installed, and no build was published.
The co-op state/admission request can still cause a short wait before entry;
this change moves the longer creation/automatic-lead waits into the visible arena.

## Classic NPC entry — 2026-10-02

Classic NPC entry now opens the real arena above the overworld before position
save and trainer battle creation, and keeps it visible during automatic lead
requests. It uses the same immediate dimming overlay as Classic wild battles;
ordinary and special NPCs no longer wait behind the cinematic cover. The arena
retains its scale during authoritative setup. Actions and unknown combatants
remain hidden until ready; interactive Team Preview still opens before selection.
Classic trainer art retains its existing command-only presentation.

The trainer entry regression now runs real world entry and lead orchestration
in both Classic and Immersive. The old Classic path failed the early arena,
transparent transition, dimming and pending creation checks. The fixed test
passed headless and in the rendered desktop runtime. Pending creation and lead
screenshots were inspected; no Godot runtime errors occurred in the final run.
The wild entry, encounter transition and NPC team reveal regressions passed.

The offline Web diagnostic now includes the trainer regression and its two
fixtures. Real Chromium/WebGL exports passed all five diagnostic checks in
fresh contexts at 1280×720 and 844×390, with no external requests, failed
resource requests or Godot/browser runtime errors. Reports are retained under
`.tmp/classic-battle-web-qa/` in the task slot. Intentional fixture rejection
warnings are expected. Android and authenticated NPC gameplay were not rerun.
The co-op admission refresh still precedes the early arena. No full release
certification, publication or deployment was performed.

## Classic initial battlefield scale — 2026-10-03

The pending mask hid the Classic ActionsDock, removing its 120-unit space from
the same VBox as the battlefield. The viewport expanded while requests waited,
then shrank when authoritative setup restored the dock. A reproduced headless
case changed the stage scale from 1.123457 while waiting to 0.984375 afterward.
The first synchronous entry geometry was also still the scene's default scale.

Classic now retains the dock in layout while keeping it transparent and its
subtree's processing/input disabled. Original opacity and processing mode return
when pending entry finishes. Classic entry synchronously sorts its outer row,
central column and stage margin before calculating the stage transform; final
restoration also refreshes that geometry before rendering.

The extended wild-entry regression checks actual global scales of the stage,
platforms, sprite boxes, HP panels and move grid before the first frame, through
blocked position/create requests, and across authoritative setup plus later
frames. Both open and closed battle-log layouts pass. The NPC regression also
checks the first Classic frame and scale through automatic lead requests and
interactive preview. The old code failed the new scale checks; the fix passed
headless and in the rendered desktop wild-entry run. Before/after screenshots
were inspected and retain identical battlefield bounds and platform sizes.
The encounter transition and battle UI layout regressions also pass.

Fresh Chromium contexts at 1280×720 and 844×390 passed all five offline Web
battle-entry diagnostics, including the expanded wild and NPC checks, without
Godot/browser runtime errors, failed resource requests or external requests.
Reports are in `.tmp/classic-scale-web-qa/` in the task slot. Intentional fixture
rejection warnings remain expected. These tests do not cover an authenticated
server encounter; Android was not rerun. No release certification, publication
or production deployment was performed.
