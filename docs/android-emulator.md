# Local Android emulator

Use the official Android SDK emulator for mobile UI work before physical-device
testing. The dedicated `PokeAether_Android13` AVD uses Android 13 (API 33),
x86_64, KVM, the host GPU, 3 GB RAM, 1080×2400 pixels and 480 dpi. In
landscape its 2400×1080 resolution/density match the Samsung SM-G780F test
phone. This does not reproduce Samsung firmware or touchscreen hardware.

The AVD is persistent local machine state, separate from game task slots:
`~/.local/share/pokeaether/android-emulator/avd`. Create it locally; never copy
phone/slot credentials, sessions, userdata, caches or builds into another slot.
Close its window to stop it. Restarting it retains installed apps and app data;
the launcher never wipes data or uses snapshots.

## One-time SDK/AVD setup

The Android SDK command-line tools are sufficient; the Android Studio IDE is
optional. Install the official packages and create the dedicated device:

```sh
/home/adinho/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --install emulator 'system-images;android-33;google_apis;x86_64'
mkdir -p "$HOME/.local/share/pokeaether/android-emulator/avd"
ANDROID_AVD_HOME="$HOME/.local/share/pokeaether/android-emulator/avd" /home/adinho/Android/Sdk/cmdline-tools/latest/bin/avdmanager create avd --name PokeAether_Android13 --package 'system-images;android-33;google_apis;x86_64' --device pixel_6
```

Set `hw.lcd.width=1080`, `hw.lcd.height=2400`, `hw.lcd.density=480`,
`hw.ramSize=3072`, `disk.dataPartition.size=6G`, `hw.gpu.enabled=yes`,
`hw.gpu.mode=host`, `hw.initialOrientation=landscape` and
`showDeviceFrame=no` in that AVD's `config.ini`. KVM must be available to the
current user (`emulator -accel-check`). SDK downloads and AVD creation do not
run Godot or change project source.

## Build and install in an assigned slot

Godot's phone export defaults to ARM64. Add `--architecture x86_64` to
`tools/build_android_usb_candidate.py` for this emulator. Keep the normal
signed-game package, current public gateway compatibility/asset identities,
and a distinct local version/build ID as described in
`android_updater/README.md`. The helper checks the actual APK native libraries
and records their architecture. Project, export and editor settings are
restored after export. No release is published.

For the separate offline HUD playground use, for example:

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/export_battle_entry_web_qa.py --suite mobile-collapse --platform android --architecture x86_64 --sdk /home/adinho/Android/Sdk --java /PATH/TO/JDK17 --output .worktrees/slot-c/.tmp/android-emulator-workflow/ui-qa
```

This app is `com.pokeaether.mobilecollapseqa`, needs no login or network
permission, runs the HUD checks and leaves a 75/100/150% scale picker for manual
testing. It uses the actual Android HUD and quest-tracker scenes. It is separate
from the full game, which opens at its login screen; sign in manually if wanted.

Install either APK using an explicit **emulator** serial:

```sh
/home/adinho/Android/Sdk/platform-tools/adb -s emulator-5580 install --no-incremental -r /PATH/TO/APK
python3 tools/open_android_emulator.py
python3 tools/open_android_emulator.py --package com.pokeaether.mobilecollapseqa
```

The launcher reserves port 5580, checks the AVD identity, and addresses only
`emulator-5580`. It never chooses a connected phone. Desktop shortcuts can
call this launcher from the normal `development` checkout; creating or testing
new exports still belongs in an assigned slot.

Sources: [Android emulator command line](https://developer.android.com/studio/run/emulator-commandline),
[SDK manager](https://developer.android.com/tools/sdkmanager),
[AVD manager](https://developer.android.com/tools/avdmanager).

## Verified local setup (2026-10-05)

The Android 13 AVD with host graphics passed 541 native HUD checks at
75/100/150% scale, followed
by 18 actual Android edge taps on `emulator-5580`. Independently reported
Android density was 480 dpi and the smallest input target was 48.125 dp. The
first-use Android fullscreen tutorial was dismissed before OS-level input
checks; it otherwise intercepts taps over the centre of the app.

Both exported APKs were checked for x86_64 native libraries. The offline UI
package has no Internet permission. The full signed game
`0.3.92-emulator.1`/code 16 passed package, certificate and demand-asset export
checks and was installed on the emulator. Its game source commit is
`ac25906b2`. Its login screen was visually checked after enabling host
graphics; no account was signed in. Cold-start and already-running emulator
launches were exercised. This is a local development build, not release
certification.

Desktop/application-menu launchers are named **PokeAether Android** and
**PokeAether Android knoppen-test**. No physical-phone input, installs, app
data transfer or tests are part of this emulator setup.

The full game needs host graphics on this machine. Software/SwiftShader hit
a GLES fragment-uniform limit and could not render the login scene. The
launcher defaults to `--gpu host`; use `--gpu software` only for UI-only
diagnostics if host rendering is unavailable. Changing GPU mode requires
closing and reopening the virtual device.

## Laptop viewing size

When starting the dedicated AVD, the launcher writes `window.scale = 0.700000`
to its local `emulator-user.ini` and rotates the emulator's presentation three
clockwise quarter-turns (90° counterclockwise) before opening the app. One
clockwise turn leaves Godot's fixed landscape image upside down in the host
window. This displays the upright landscape game at 1680×756 desktop
pixels on the 1920×1080 laptop panel. Use `--window-scale 0.5`, for example, for
a smaller view on the next cold start. An already-open emulator is left alone.

The AVD retains its portrait 1080×2400 framebuffer: the game's landscape
viewport remains 2400×1080 at 480 dpi, with independent game UI scale. Forcing
a `2400x1080` framebuffer skin instead puts the Pixel camera cutout along the
long edge and reduces the usable viewport to 2400×952; do not use that shortcut.
The obsolete emulator `-scale` option is ignored by current SDK versions.
The emulator resets its stored viewing scale on exit, so the launcher applies
the preference before each cold start. App data is retained.

Verify orientation using a capture of the actual emulator desktop window.
An ADB screenshot shows only Android's framebuffer and cannot reveal the
host-window rotation.

This viewing configuration passed 541 native UI checks and Android edge taps.
An occasional first app launch after a cold boot runs before Android resolves
the installed activity, or exits during its late resource configuration change.
Reopening the same desktop shortcut works; the host-window size, orientation
and installed apps are retained.
