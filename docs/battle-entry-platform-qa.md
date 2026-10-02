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

This USB candidate retains the installed official asset build ID and declares
compatibility with that official build; no assets or APK were published. It was
not automatically launched for a logged-in encounter. Installation verification
does not establish the full game's battle behavior or performance; the player
can now try those changes in the installed game.
