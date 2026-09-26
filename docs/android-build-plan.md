# PokeAether Android build plan

Status: Android V1 implementation in slot A; device gates remain open
Target: direct APK distribution from the PokeAether website, with Discord linking to it
Project baseline: Godot 4.6.2, shared client codebase
Last updated: 2026-09-25

Device smoke test (Samsung SM-G780F, Android 13): debug APK installed and
launched, production server status loaded, login entered the world, and party
buttons opened a Pokémon window. A missing desktop-only review JSON initially
caused an Android script compile error; the lazy-load fix removed that error in
the second device run. Initial fixed touch controls moved the player, but
overlapped chat. The floating joystick and world-tap prototype now also runs
on the phone: movement, interaction, chat and UI buttons were confirmed by the
device tester. A 1.25x mobile content scale, larger quick actions, global buff
buttons and chat controls, and touch-specific dialogue input are in the device
build. The tester confirmed a multi-line NPC dialogue and a wild battle. The
left party rail and battle log fit beneath each other, and the post-battle
Android log has no sprite-loading script errors. A small login, Route 1 and
wild-battle music fallback is now bundled. The Android client downloads the
versioned music pack into `user://`, checks its size and SHA-256, validates ZIP
paths and required tracks, then activates it after extraction. The first phone
played login, world and wild-battle music from a local test pack and kept login
and world music after an offline restart. With explicit production access
approval, it then downloaded and activated `music-3f2a6df18793` from the public
updates manifest. A later device build removed an obsolete music directory on
startup while preserving all 16 tracks in the active pack. Current gaps:
Android keyboard and safe-area behavior,
deeper touch coverage across battle menus, and different aspect ratios. This
is not yet a player release or a full mobile UI validation.

Android crash diagnostics now mark a backgrounded app as clean and mark it
active again on resume. This prevents Android's normal background process
termination from producing a false crash prompt on the next launch.

The original July estimates and store-related options below are historical.
Android V1 uses direct APK distribution and must detect and download a newer
APK in-app. Android may still require the player to confirm installation.
No Google Play or Apple App Store release is planned. The app uses 2D sprites
and the immersive battle view; desktop 3D assets are excluded.

## 1. Objective

Build an Android version of PokeAether without creating a separate Android fork.
The desktop and Android clients should remain in the same Godot project, with
platform-specific behavior isolated behind feature checks and small mobile
components.

The first milestone is a closed Android alpha that:

- installs as an ARM64 APK;
- runs in landscape;
- connects to the production HTTPS and WSS endpoints;
- downloads required game assets into app-owned storage;
- supports login, overworld movement, interactions, dialogue and battles using
  only touch input;
- safely handles backgrounding, screen locking and network reconnects;
- preserves the existing Windows, Linux and macOS behavior;
- detects newer Android releases, downloads a verified APK and opens Android's
  installation flow without requiring a fresh website or Discord download;
- passes all existing project checks plus new Android-specific checks.

The first alpha does not need:

- Google Play publication;
- portrait support;
- complete tablet-specific layouts;
- optional Gen 5 animated sprite packs;
- every desktop drag-and-drop convenience;
- silent installation of a replacement APK without Android's confirmation.

## 2. Current baseline

The project is a good candidate for Android because it is a Godot 4.6.2
GDScript project and does not currently depend on desktop-only native
extensions.

The main gaps are outside the core gameplay:

1. The Android export preset is added and the debug APK has run on one phone;
   release signing and broader device coverage remain open.
2. Movement and interaction actions in `project.godot` have keyboard bindings;
   the mobile control scene now generates those same actions from touch.
3. The UI contains mouse-, right-click- and drag-specific interactions.
4. Desktop display code also runs on non-web platforms and therefore needs a
   mobile exclusion.
5. Large sprite and music packs are installed next to the desktop executable.
   Android needs app-owned `user://` storage instead.
6. Realtime services require stronger resume and reconnect handling for the
   Android application lifecycle.
7. The UI targets a 1920x1080 landscape viewport and has not yet been checked
   for safe areas, narrow aspect ratios or the Android software keyboard.

At the time this plan was written, all 112 existing project checks passed.
Those checks protect the existing gameplay but do not yet exercise Android
export, touch input or mobile lifecycle behavior.

## 3. Architectural decisions

### 3.1 Keep one client project

Do not create an `android` copy of the game. Use:

- `OS.has_feature("mobile")` for runtime mobile behavior;
- Android export feature tags when export-specific behavior is required;
- isolated mobile scenes and scripts;
- the existing input actions as the interface between mobile controls and
  gameplay.

Core game systems should not need to know whether an input action came from a
keyboard, controller or touchscreen.

### 3.2 Use Compatibility rendering for the initial build

PokeAether is predominantly a 2D game. The Android build should initially use
Godot's Compatibility renderer for broad device support and lower rendering
overhead.

Forward+ can remain the desktop default. Any renderer-specific visual
difference must be found during the physical-device smoke test.

Official reference:

- <https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html>

### 3.3 Use a normal Android app, not a launcher app

Android updates the application package through a signed APK. The Android
client must never download and execute a replacement game binary inside the
Godot process. It may download a verified APK and invoke the system installer.

The app may download versioned content packs. Application updates and content
updates are separate:

- APK: client scripts, scenes and bundled essential resources;
- asset packs: large Pokémon sprites, music and optional visual content.

The release manifest and APK are hosted on the existing updates domain. For
each release, publish an immutable APK first, verify its size and SHA-256, then
replace `manifest-android.json`. The manifest's `game.buildId` must match the
build ID embedded in the APK; the gateway already selects this manifest for
Android clients. The APK retains the same package name and signing key and has
a strictly increasing Android `version/code`. The updater offers retry and a
website fallback if Android rejects the installation. Neither build automation
nor a GitHub artifact upload publishes a player release without separate
authorization.

The install handoff needs Android integration beyond GDScript: a `FileProvider`
must grant the system installer temporary read access to the verified APK using
a `content://` URI, and the app must declare `REQUEST_INSTALL_PACKAGES`. Check
`canRequestPackageInstalls()` and lead the player through Android's per-app
install permission before opening `ACTION_INSTALL_PACKAGE`. Godot's v2 Android
plugin path uses a Gradle build, so the current template-only export is a
bootstrap step. Test an upgrade from version code N to N+1 on a real phone
with the same release key before distributing the first player APK.

References: <https://developer.android.com/reference/android/content/Intent>,
<https://developer.android.com/reference/androidx/core/content/FileProvider>,
<https://docs.godotengine.org/en/4.6/tutorials/platform/android/android_plugin.html>.

### 3.4 Store downloaded content under `user://`

Use app-owned internal storage and do not request broad external storage
permissions.

Proposed layout:

```text
user://
  asset_versions.json
  assets/
    sprites/
      pokemon/
    audio/
      music/
  downloads/
  staging/
```

Installed asset packs must survive an APK update signed with the same Android
signing key.

### 3.5 Start with a closed alpha

The first distribution should be a signed, sideloadable APK for invited
testers. The website is the sole binary download location; Discord can point
players there.

## 4. Milestone A: Android export bootstrap

Estimated effort: 1-2 focused development days.

### Work

- Install and configure:
  - Godot 4.6.2 export templates;
  - a supported JDK (local bootstrap currently uses JDK 26);
  - Android SDK and platform tools;
  - `adb`;
  - Android SDK packages recommended by Godot 4.6.
- Add an `Android Internal Alpha` preset to `export_presets.cfg`.
- Use package identifier `com.pokeaether.game`, consistent with the current
  macOS bundle identifier unless a different permanent Android identifier is
  explicitly selected before the first external release.
- Export ARM64 only for the initial APK.
- Enable landscape orientation.
- Enable internet access.
- Configure Compatibility rendering for Android.
- Add a stable release signing key and keep it outside the repository. The
  local export currently uses Godot's disposable debug key and cannot be an
  upgrade source for players.
- Make `WindowFit` skip mobile platforms.
- Make `SettingsManager` skip desktop resolution and window-mode operations on
  mobile.
- Hide or disable desktop-only resolution and fullscreen settings on Android.
- Confirm that external links open in the Android browser.

### Expected files

- `export_presets.cfg`
- `project.godot`
- `scripts/core/window_fit.gd`
- `scripts/services/settings_manager.gd`
- `scripts/ui/settings_menu.gd`
- new Android export/build documentation as needed

### Acceptance criteria

- [x] A debug ARM64 APK exports successfully; release signing remains open.
- [x] The debug APK installs with `adb install` on the first test phone.
- [x] The app starts without a native or Godot crash on that phone.
- [ ] The login screen is readable at a comfortable phone scale.
- [x] The production health/API endpoint is reachable.
- [x] Login succeeds on the first physical Android device.
- [ ] Windows, Linux and macOS export behavior is unchanged.

## 5. Milestone B: Mobile control layer

Estimated effort: 2-4 focused development days.

### Proposed components

```text
scenes/interface/mobile/mobile_controls.tscn
scripts/ui/mobile/mobile_controls.gd
scripts/core/platform_capabilities.gd
tests/mobile_controls_check.gd
```

`mobile_controls.tscn` should be an isolated `CanvasLayer` instantiated in the
world scene. Avoid placing the implementation directly in the already large
`ui_overlay.gd`.

### Initial control layout

- A short tap on the unobstructed world sends the existing `interact` action.
- Holding a thumb on the world opens a joystick at that touch position;
  dragging moves in one of the four cardinal directions.
- A second finger can tap the world while the first controls movement.
- Existing menu and context UI remains available through its own touch targets.

The controls should call:

```gdscript
Input.action_press("move_up")
Input.action_release("move_up")
```

and equivalent existing actions. They should not call player movement methods
directly.

### Visibility rules

Accept world touches when:

- the local player can receive overworld movement;
- no blocking modal is active;
- no text input owns focus;
- a battle UI is not consuming the screen.

Release the active touch when:

- the login screen is active;
- a battle is active;
- dialogue blocks movement;
- a full-screen popup is open;
- the Android software keyboard is visible;
- the app loses focus or pauses.

All pressed actions must be released before controls are hidden or the app is
paused. This prevents a direction from remaining stuck after an interrupted
touch.

### Safe-area behavior

- Read the display safe area at runtime.
- Keep controls outside notches, rounded corners and gesture-navigation zones.
- Recalculate margins after viewport size or orientation changes.
- Keep the game landscape-only for the initial alpha.

### Acceptance criteria

- [x] Movement works with the floating joystick on the first test phone;
      precise single-tile and long-hold behavior still needs a focused pass.
- [ ] Direction changes do not create diagonal or skipped tile movement.
- [ ] Multitouch allows holding a direction while pressing interact.
- [ ] World interaction works on the first test phone; NPC, sign, door,
      fishing and surfing scenarios still need separate passes.
- [ ] Opening a modal releases all held movement actions.
- [x] A focused control check confirms pausing the app releases held actions;
      physical-device backgrounding still needs verification.
- [ ] Controls do not overlap critical UI on tested aspect ratios.

## 6. Milestone C: Android asset delivery

Estimated effort: 3-6 focused development days.

This is the highest-risk milestone because the required sprite packs are large
and the current desktop launcher expects to install content next to a desktop
executable.

At the time this plan was written:

- required basic sprite packs total approximately 437 MB as hosted downloads;
- optional Gen 5 animated packs total approximately 1.13 GB;
- music is another versioned pack.

Bundling all packs in the APK is not the preferred production design.

### Proposed components

```text
scripts/services/asset_pack_service.gd
scenes/interface/asset_download_screen.tscn
scripts/ui/asset_download_screen.gd
tests/asset_pack_service_check.gd
tests/android_asset_resolution_check.gd
```

### Reuse from the desktop launcher

Extract or adapt only the portable content logic from
`launcher/scripts/launcher.gd`:

- manifest parsing;
- version comparison;
- download queue construction;
- expected file-size checking;
- SHA-256 validation;
- ZIP extraction;
- installed-version persistence;
- progress reporting.

Do not reuse:

- launching a game executable;
- launcher self-update scripts;
- Windows or Unix shell commands;
- custom installation folder selection;
- desktop uninstall behavior.

Long term, shared manifest and pack validation logic may be moved into small
scripts usable by both the desktop launcher and the Android client. Avoid
making the game depend on the launcher scene.

### Atomic installation flow

For each pack:

1. Check the manifest and installed version.
2. Verify enough free storage when the platform exposes that information.
3. Download to `user://downloads/<pack>.part`.
4. Validate HTTP success and expected byte count.
5. Validate SHA-256.
6. Clear a pack-specific staging directory.
7. Inspect ZIP entries and reject absolute paths or `..` traversal.
8. Extract to staging.
9. Validate required folders or sentinel files.
10. Move the completed pack into `user://assets`.
11. Persist the installed version only after the move succeeds.
12. Delete the temporary download.

On failure, keep the previous installed pack and offer retry. Never mark a
partially extracted pack as current.

### Runtime path resolution

Update:

- `scripts/data/pokemon_assets.gd`;
- `scripts/services/music_manager.gd`.

The resolver should support:

1. current downloaded assets under `user://assets`;
2. bundled `res://` fallbacks;
3. existing desktop external asset roots.

The exact priority must be covered by tests so a newly downloaded version can
replace an older bundled fallback without breaking desktop installations.

### Alpha scope

- Automatically install the six required basic sprite packs.
- Keep Gen 5 animated sprites optional.
- Display required download size before starting.
- Display current file, total progress and retry state.
- Permit cancellation before gameplay begins.
- Keep authentication and asset installation independent so a failed download
  does not corrupt a saved session.

### Acceptance criteria

- [ ] A clean install downloads all required packs.
- [ ] Party, storage, overworld and battle sprites resolve from `user://`.
- [ ] Restarting the app does not redownload current packs.
- [ ] A checksum mismatch never activates a pack.
- [ ] Killing the app during download leaves a recoverable state.
- [ ] Killing the app during extraction leaves the old pack usable.
- [ ] Low-storage and network errors produce actionable messages.
- [ ] Optional Gen 5 assets are not required to enter the game.

## 7. Milestone D: Mobile UI interaction parity

Estimated effort: 4-8 focused development days.

Standard Godot `Button` controls should be tested first. Custom code that
explicitly accepts only `InputEventMouseButton`, right-click, hover or mouse
dragging needs a touch-accessible path.

### Required interaction audit

#### Party

Current relevant file:

- `scripts/ui/party_slot.gd`

Mobile behavior:

- tap selects or opens the Pokémon;
- do not require mouse movement distance to distinguish every action;
- provide explicit actions where desktop uses drag.

#### Bag and hotbar

Current relevant files:

- `scripts/ui/ui_overlay.gd`
- `scripts/ui/player_hotbar_slot_button.gd`
- `scripts/ui/hotbar_bag_item_slot.gd`

Mobile behavior:

- tap selects an item;
- visible buttons offer Use, Give, Register or Remove as appropriate;
- long-press may open a context menu, but no required action may depend only
  on long-press;
- hotbar assignment can use select-item then select-slot.

#### Pokémon storage

Current relevant file:

- `scripts/ui/pc_pokemon_slot_button.gd`

Mobile behavior:

- tap a source Pokémon;
- tap a party or box destination;
- show selected and valid-drop states;
- retain drag-and-drop on desktop.

#### Move reordering

Current relevant file:

- `scripts/ui/pokemon_summary_move_reorder_slot.gd`

Mobile behavior:

- tap the source move;
- tap the destination;
- offer Cancel;
- keep desktop dragging.

#### Trading

Current relevant file:

- `scripts/ui/trade_workspace.gd`

Mobile behavior:

- select party, Pokémon or item;
- press an explicit Add/Remove action;
- do not require window dragging;
- keep confirmation and lock states server authoritative.

#### Remote players

Current relevant file:

- `scripts/world/remote_player_avatar.gd`

Mobile behavior:

- tap or long-press a remote player;
- open the existing player interaction coordinator;
- do not require right-click.

#### Movable windows

Current relevant file:

- `scripts/ui/draggable_subwindow.gd`

Mobile behavior:

- center or dock windows;
- disable dragging unless a touch-safe implementation is genuinely useful;
- clamp all panels inside the safe viewport.

#### Text input

Test:

- login username and password;
- chat;
- mail;
- guild fields;
- market search;
- account settings.

When the software keyboard appears, the focused field and submit action must
remain reachable. Overworld movement controls must be disabled while a text
field owns input.

### Acceptance criteria

- [ ] No essential gameplay flow requires hover.
- [ ] No essential gameplay flow requires right-click.
- [ ] Party and PC management are usable without mouse dragging.
- [ ] Bag items can be used and assigned to the hotbar.
- [ ] A complete trade can be performed using touch only.
- [ ] Chat and form fields remain visible above the software keyboard.
- [ ] Desktop mouse and drag behavior remains available.

## 8. Milestone E: Android lifecycle and realtime recovery

Estimated effort: 2-4 focused development days.

Android may suspend rendering, close sockets, switch networks or terminate the
process while the app is in the background. Focus-in synchronization alone is
not sufficient.

### Proposed lifecycle service

```text
scripts/core/application_lifecycle.gd
tests/application_lifecycle_check.gd
tests/realtime_resume_contract_check.gd
```

The service should expose signals such as:

```text
application_pausing
application_resumed
network_recovery_requested
```

### Pause behavior

- Release every synthetic mobile input action.
- Stop accepting new local gameplay actions.
- Preserve active battle, trade and room identifiers.
- Avoid treating a mobile pause as an intentional logout or trade close.
- Let server-authoritative timers continue on the server.

### Resume behavior

- Check authentication/session validity.
- Reconnect world presence.
- Reconnect chat.
- Reconnect trade only when the trade is still recoverable.
- Reconnect or rejoin an active PvP battle.
- Request a server snapshot or missing event range.
- Resynchronize battle timers.
- Refresh health/status data after network changes.

Realtime services in scope:

- `scripts/services/chat_realtime_service.gd`
- `scripts/services/world_presence_service.gd`
- `scripts/services/pvp_battle_realtime_service.gd`
- `scripts/services/trade_realtime_service.gd`

Reconnect operations must be idempotent. Repeated resume notifications must
not create multiple sockets, duplicate subscriptions or duplicate battle
actions.

### Physical test scenarios

- Switch away from the app for 10 seconds.
- Lock the phone for 2 minutes.
- Switch from Wi-Fi to mobile data.
- Disable and restore connectivity.
- Background during a wild battle.
- Background during PvP turn selection.
- Background during PvP event playback.
- Background during a trade.
- Let Android terminate the process and reopen the app.

### Acceptance criteria

- [ ] The player never continues moving after resume without input.
- [ ] Chat and world presence recover without duplicate messages or avatars.
- [ ] PvP returns to the authoritative current state.
- [ ] Battle timers match the server after resume.
- [ ] No battle action is submitted twice.
- [ ] Trade either recovers safely or closes with a clear server-backed state.
- [ ] Process restart restores the session and valid server game state.

## 9. Milestone F: Automated build and internal distribution

Estimated effort: 2-3 focused development days.

Create a separate Android workflow rather than adding more conditional
complexity to the existing desktop deployment workflow.

Proposed workflow:

```text
.github/workflows/build-android.yml
```

### Workflow responsibilities

1. Check out the repository.
2. Install Godot 4.6.2 and matching export templates.
3. Install JDK 17 and the required Android SDK packages.
4. Import project assets.
5. Run all project checks.
6. Export the Android ARM64 APK.
7. Verify the artifact exists and has the intended package configuration.
8. Upload the APK as an internal workflow artifact.

Later release steps:

- inject the release keystore from GitHub Secrets;
- export a signed release APK for closed distribution;
- attach version metadata and checksums;
- retain the same signing identity for all upgrades.

The workflow must bind the APK `version/code`, `version/name`, and embedded
`application/config/build_id` to one release record. It uploads a private
artifact only. Publishing the immutable APK and then `manifest-android.json`
is a separate, authorized release operation. The manifest includes the APK
URL, byte count, SHA-256, and matching `game.buildId`.

Never commit:

- keystores;
- keystore passwords;
- service-account credentials;
- Android signing environment files.

Official reference:

- <https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html>

### Acceptance criteria

- [ ] Android CI produces a reproducible APK.
- [ ] CI fails when project checks fail.
- [ ] Signing secrets never appear in logs or artifacts.
- [ ] Installing a newer APK preserves `user://` content and session state.
- [ ] An older compatible APK can be retained as rollback evidence.

## 10. Test strategy

### Automated checks

Add checks for:

- platform feature selection;
- mobile-control press and release behavior;
- release of inputs during pause and modal transitions;
- mobile display settings;
- safe-area layout calculations;
- asset manifest validation;
- size and SHA-256 mismatch;
- ZIP path traversal;
- atomic pack installation;
- resolver precedence between `user://`, `res://` and desktop paths;
- lifecycle state transitions;
- idempotent realtime reconnect;
- absence of required mouse-only actions in selected core flows.

Continue running the complete existing project check suite.

### Initial physical-device matrix

Test at least:

- one older or low-end Android phone;
- one current midrange phone;
- one current high-end phone;
- one narrow/tall display with a notch or camera cutout;
- optionally one tablet after the phone layout is stable.

Prefer real devices over relying only on emulators for performance, soft
keyboard, lifecycle and touch behavior.

### Required smoke-test route

1. Fresh install.
2. Required asset download.
3. Login and saved-session restore.
4. Enter world.
5. Walk in all directions.
6. Interact with NPC, sign and door.
7. Use bag and party.
8. Trigger and complete a wild battle.
9. Use chat with the software keyboard.
10. Background and resume.
11. Start or spectate PvP.
12. Background during PvP and recover.
13. Install an upgraded APK and verify retained data.

## 11. Security and release considerations

### Alpha

- App-owned internal storage is sufficient for downloaded public assets.
- Use HTTPS/WSS production endpoints.
- Keep a stable signing key even for closed alpha upgrades.
- Redact tokens and private payloads from Android logs.
- Do not enable verbose production network logging.

### Before public release

- Review how the remembered authentication token is stored.
- Consider Android Keystore-backed protection for persistent session material.
- Add crash reporting or a privacy-conscious diagnostic export.
- Review Android target SDK and sideload installation requirements.
- Review privacy disclosures separately from technical build readiness.

## 12. Delivery sequence

The recommended implementation order is:

1. Android toolchain, preset and platform detection.
2. Compatibility renderer and mobile display behavior.
3. Mobile controls and safe areas.
4. First physical-device overworld smoke test.
5. Asset pack service and first-launch download UI.
6. Asset resolver changes.
7. Lifecycle and realtime reconnect.
8. Touch alternatives for mouse-only critical flows.
9. Android-specific automated checks.
10. CI APK generation and signed closed-alpha distribution.
11. Device matrix and performance pass.
12. Public-beta decision.

Each step should be a small, independently testable change. Do not combine the
asset pipeline, input layer and realtime lifecycle into one large change.

## 13. Estimated schedule

For one focused developer:

| Result | Estimate |
| --- | ---: |
| First installable APK | 1-2 days |
| Touch-controlled overworld prototype | 3-6 days total |
| Asset-complete closed alpha | Approximately 2-3 weeks |
| Public beta with broad feature parity | Approximately 4-8 weeks |

These are engineering estimates, not release commitments. Asset-download
reliability, mobile UI parity and PvP resume behavior are the largest sources
of uncertainty.

## 14. Go/no-go gates

### Gate 1: engine and renderer

Proceed when the game starts and renders correctly on a midrange physical
phone using Compatibility rendering.

### Gate 2: core touch gameplay

Proceed when login, movement, interaction, dialogue and a full wild battle can
be completed without a keyboard or mouse.

### Gate 3: asset delivery

Proceed when a clean install and interrupted download both recover reliably,
and an APK update preserves installed packs.

### Gate 4: realtime lifecycle

Proceed when active PvP can survive backgrounding and reconnect to the
authoritative state without duplicate actions.

### Gate 5: closed alpha

Invite external testers when:

- there are no known account- or battle-state corruption paths;
- the APK uses a stable signing key;
- update and rollback artifacts are retained;
- required storage and download size are clearly shown;
- crash and connection failures provide usable diagnostics.

### Gate 6: public beta

Consider public support only after:

- the physical-device matrix passes;
- essential desktop features have touch alternatives;
- performance and memory are acceptable on the chosen minimum device;
- signing, CI and release procedures are documented;
- support boundaries and known limitations are published.

## 15. Progress checklist

### Bootstrap

- [x] Android SDK and JDK configured locally in slot A.
- [x] Android export templates installed in slot A.
- [x] Android export preset added.
- [x] ARM64 debug APK exported and installed on the first test phone.
- [x] Compatibility rendering displayed login, overworld and a wild battle on
      the first phone; detailed battle touch coverage remains open.
- [x] Desktop window resizing and display settings are excluded on mobile.

### Controls and layout

- [x] Mobile control scene added and tested on the first phone.
- [ ] Multitouch movement and interaction work.
- [x] Focus loss, pause, battle entry and dialogue entry release held movement
      in focused tests; physical backgrounding remains to be tested.
- [ ] Safe-area margins implemented.
- [ ] Android back behavior implemented.
- [ ] Software keyboard behavior validated.

### Content

- [x] Music pack service added; Pokémon sprite pack delivery remains open.
- [x] First-launch music download UI added; other pack UI remains open.
- [x] Music pack size and checksum checks implemented.
- [x] Safe ZIP extraction implemented for music.
- [x] Atomic staging and activation implemented for music.
- [ ] Pokémon asset resolver supports `user://`.
- [x] Music resolver supports `user://`.
- [ ] Interrupted-download recovery tested.
- [x] Old music versions are pruned on the first launch after a successful
      update, once no music stream uses the replaced pack.

### Feature parity

- [ ] Party is touch-usable.
- [ ] Bag and hotbar are touch-usable.
- [ ] PC storage is touch-usable.
- [ ] Move reordering is touch-usable.
- [ ] Trading is touch-usable.
- [ ] Remote-player interactions are touch-usable.
- [ ] Mobile windows do not depend on dragging.

### Lifecycle

- [ ] Central lifecycle service added.
- [ ] Chat reconnect tested.
- [ ] World presence reconnect tested.
- [ ] PvP reconnect and resync tested.
- [ ] Trade recovery behavior defined and tested.
- [ ] Network-switch behavior tested.
- [ ] Process-kill recovery tested.

### Delivery

- [x] Android checks a platform manifest, verifies an APK and blocks outdated gameplay until installation.
- [x] Local debug APK upgraded from version code 1 to 2 through Android's installer; session and music data survived.
- [x] Android APK updater check added to the project test runner.
- [x] Manual Android CI workflow prepares a signed release candidate and a manifest for review; a CI run remains open.
- [x] Local release APK exported with a disposable test key; package, version, certificate and manifest metadata verified.
- [x] Stable alpha signing configured in GitHub Secrets; local release APK verified against the pinned certificate. External backup remains open.
- [x] Permanent-key signed APK upgraded from version code 1 to 2 through the in-app updater and Android installer on an isolated x86_64 emulator; pre-existing app data survived and the downloaded APK was pruned after relaunch. ARM64 release-device coverage remains open.
- [ ] Closed-alpha device matrix completed.
- [ ] Public-beta go/no-go review completed.
