# Local Android emulator

## Ordinary phone APKs and updates

For playing the normal signed ARM64 release, use the **Pixel 6 / Android 15
Google Play** profile, `PokeAether_Pixel6_Android15`, on `emulator-5582`.
The Google Play x86_64 image (API 35, revision 9) includes
`libndk_translation.so` and advertises both `x86_64` and `arm64-v8a`.
The Android 13 Google APIs image below advertises only `x86_64`: changing its
Samsung/Pixel screen profile cannot make the phone APK install.

A hardware profile specifies the screen and sensors; it does not reproduce a
phone's physical processor, GPU, vendor drivers or Samsung One UI. Pixel 6 is
a standard Android SDK profile with the same 1080×2400 screen used by our phone
layout checks. Prefer the verified image/renderer combination over a different
phone label. Use the host GPU and KVM on this x86_64 Linux machine; full ARM
system emulation does not get the same VM acceleration.

Create an independent AVD (do not overwrite the Android 13 device or copy its
userdata):

```sh
/home/adinho/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --install 'system-images;android-35;google_apis_playstore;x86_64'
ANDROID_AVD_HOME="$HOME/.local/share/pokeaether/android-emulator/avd" /home/adinho/Android/Sdk/cmdline-tools/latest/bin/avdmanager create avd --name PokeAether_Pixel6_Android15 --package 'system-images;android-35;google_apis_playstore;x86_64' --device pixel_6
```

Set `hw.ramSize=3072`, `hw.cpu.ncore=4`, `hw.lcd.width=1080`,
`hw.lcd.height=2400`, `hw.lcd.density=480`, `disk.dataPartition.size=6G`,
`hw.gpu.enabled=yes`, `hw.gpu.mode=host`, `hw.keyboard=yes`,
`hw.keyboard.lid=no`, `hw.initialOrientation=portrait`
and `showDeviceFrame=no` in this new AVD's `config.ini`. Start it once with
`-port 5582 -gpu host -no-snapshot`, install a verified ordinary release APK
using `adb -s emulator-5582 install --no-incremental -r /PATH/TO/APK`, then use:

```sh
python3 tools/open_android_emulator.py --profile phone
```

The launcher checks the exact AVD identity and ARM64 support before opening the
game. Closing and reopening retains this device's own apps and settings.
This is a separate virtual phone: sign in manually; existing Android 13 login
data is not transferred.

Keep `--profile native` (the CLI default) for the existing Android 13 diagnostic
device on port 5580. Its x86_64 diagnostic APKs and pinned QA runners remain
available independently of the phone profile.

Sources: [AVD hardware profiles and system images](https://developer.android.com/studio/run/managing-avds),
[emulator VM and GPU acceleration](https://developer.android.com/studio/run/emulator-acceleration),
[Google's ARM translation announcement](https://android-developers.googleblog.com/2020/03/run-arm-apps-on-android-emulator.html).

### Phone-profile checks (2026-10-08)

The ordinary ARM64 0.3.102/code 19 APK installed and rendered the login screen.
Its unmodified in-app updater downloaded and verified the public 0.3.103/code
20 APK, opened Android's source-permission and confirmation screens, and
installed the upgrade. After reboot, `primaryCpuAbi=arm64-v8a`, version 0.3.103
and code 20 were confirmed; the data directory and first-install time were
unchanged. The visible emulator survived three further app restarts.

The initial **headless** host-GPU trial suffered an emulator SIGSEGV during
the app's update shutdown. The upgrade had completed and survived restarting
the AVD. Use the visible launcher; do not treat the headless configuration as
qualified. Android 11 Google APIs/revision 16 was also rejected: it installed
the APK but its older ARM translator crashed in a SIMD instruction (SIGILL).

The machine-local desktop control bar follows the new AVD on port 5582. It
matches Android's display rotation and fits both portrait and landscape into
the monitor work area. The Pixel profile defaults to `hw.keyboard=no`; enable
the keyboard as above and cold-start the AVD to pass laptop typing into the
game. `show_ime_with_hard_keyboard=1` can also retain the on-screen keyboard.
The old Android 13 AVD, including its apps and data, remains separate.

These are installation, update and startup checks, not sustained 3D, battle,
thermal or physical Pixel-device certification. No account was signed in.

## Native Android 13 QA device

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
