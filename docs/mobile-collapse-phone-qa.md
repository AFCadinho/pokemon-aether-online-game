# Mobile collapse controls — physical Android QA

Tested on 2026-10-05 using the Samsung SM-G780F, Android 13,
Compatibility/OpenGL ES 3.2 (Mali-G77), 2400×1080 landscape output and Android
logical density 480 dpi. Source started at local development `14d87501a`.

The original touch helper used `DisplayServer.screen_get_scale()`. On this
phone Godot reported 1.8 although Android dp requires a factor of 3.0.
The original targets therefore measured only 29.0625 Android dp at their
smallest. Godot 4.6.2
[clamps its Android scale by the output dimensions](https://github.com/godotengine/godot/blob/4.6.2-stable/platform/android/display_server_android.cpp#L315).
The helper now uses Android's uncapped `screen_get_dpi() / 160` density.

The physical-device probe uses the real HUD and quest-tracker scenes. It checks
native layout, minimum sizes, viewport bounds, separate targets, movement-input
blocking and collapse/reopen clicks near the enlarged edge at 75%, 100% and
150% UI scale. The corrected probe passed 433 assertions. All six expanded/
collapsed samples had at least 48.125 Android dp targets. Expected density was
also checked independently using `adb shell wm density`, rather than relying
on the helper's own density calculation. All 18 actual Android edge taps (two
per HUD/quest target at 75%) also passed and restored the original panel states.
Rendered 75% and 150% screenshots were inspected; no Godot runtime errors
occurred. The unauthenticated toggle-preference warning is expected offline.

The separate `com.pokeaether.mobilecollapseqa` debug app has no Android network
permissions. Music/APK update checks and crash prompts are disabled only in its
export. Its scale picker remains available after automatic checks for manual
finger testing. The installed `com.pokeaether.game` version 0.3.92/code 13 and
its app data are retained. This is offline HUD QA, not logged-in gameplay or a
release certification. No APK or assets are published.

## Repeat

Use an assigned task slot and substitute its name and the attached serial:

```sh
ops/worktrees/slot-env slot-b -- python3 .worktrees/slot-b/frontend/tools/export_battle_entry_web_qa.py --suite mobile-collapse --platform android --sdk /home/adinho/Android/Sdk --output .worktrees/slot-b/.tmp/mobile-collapse-phone
/home/adinho/Android/Sdk/platform-tools/adb -s SERIAL install --no-incremental -r .worktrees/slot-b/.tmp/mobile-collapse-phone/mobile-collapse-qa.apk
/home/adinho/Android/Sdk/platform-tools/adb -s SERIAL shell am start -n com.pokeaether.mobilecollapseqa/com.godot.game.GodotAppLauncher
```

Wait for the scale picker. Read the diagnostic's own
`files/mobile-collapse-qa-results.json` and `files/mobile-collapse-details.json`
using `adb exec-out run-as com.pokeaether.mobilecollapseqa cat PATH`.
The first file must contain a zero result; the second must have no failures.
Its six `collapse-SCALE-STATE.png` files contain rendered HUD screenshots.

With this app foreground and automatic checks finished, exercise actual Android
edge taps and independently verify the density:

```sh
python3 .worktrees/slot-b/frontend/tools/check_mobile_collapse_device.py --adb /home/adinho/Android/Sdk/platform-tools/adb --serial SERIAL --output .worktrees/slot-b/.tmp/mobile-collapse-phone/android-edge-taps.json
```

The tool sends two Android touches to each of the nine HUD/quest targets and
checks that the intended panel toggles and returns to its previous state. It
refuses to send input while another app is foreground. Avoid touching the phone
until it finishes. Afterwards try the three scale buttons and the HUD arrows
manually. Stop/remove only the diagnostic package when device QA is finished.

Local APKs, screenshots and reports remain under the assigned slot's `.tmp`
directory. The desktop `mobile_collapse_touch_size_check` also passed 28,152
checks with the final helper and the normal project configuration restored.
