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

An intermediate revision drew native collapse/reopen and chat-resize controls
as centred 28 dp surfaces inside their 48 dp minimum input rect. Its arrows and
resize icon were smaller too. Hover/pressed surfaces stayed compact, and
transparent padding accepted taps and blocked movement. Desktop surfaces and
the labelled browser navigation retained their layout. That regression passed
33,506 assertions, including presses outside the visible surfaces; a rendered
844×390 native preview passed 541 assertions and was visually inspected.
That revision's app also passed 541 assertions on the same Samsung phone at
75%, 100% and 150%. All six samples had 28 dp visible surfaces and at least
48.125 dp touch targets. The independent ADB check passed another 18 actual
Android taps in the transparent padding at 75%; 75% and 150% device screenshots
were visually inspected. Evidence is retained in the slot's
`.tmp/mobile-collapse-phone-compact` directory.

The player still found 28 dp surfaces too large. The current revision restores
the original 28×28 HUD/resize and 28×32 quest surfaces in UI units, with the
original 18-unit HUD arrow, 16-unit quest arrow and 16-unit resize icon. Their
visible appearance now follows the chosen UI scale; only the transparent input
padding retains the 48 dp minimum. The restored-size revision passed 34,397 local
regression checks and 541 rendered-preview checks at 800×360, simulating
Android's 1.25 platform scale factor in dp screen units. The inspected previews
had 8.75 dp visible HUD buttons at 75%, 11.667 dp at 100% and 17.5 dp at 150%,
with at least 48.125 dp touch rects throughout. These are local simulations,
not new physical-device results.

After the intermediate physical test, the player reported that their phone's
touchscreen stopped responding. Stopping the app and removing the diagnostic
package did not immediately restore touch. A normal Android reboot restored
screen input, as confirmed by the player. The cause has not been established.
Subsequent phone checks use screenshots and manual player testing only; no
automated touch input is sent to this device.

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
finger testing. The diagnostic package was subsequently removed; the normal game and its app
data were retained. This is offline HUD QA, not logged-in gameplay or a
release certification. No APK or assets are published.

## Native top-right layout correction

Manual testing of the full signed game update `0.3.92-usb.1` (code 14) exposed
unstable placement around the Pokédex row and quest tracker. A read-only phone
screenshot was inspected; no phone input was automated. Large transparent
input rectangles were being relocated independently around densely spaced
rows, separating the small arrows from their owners.

Native right-side rows now reserve at least 48 dp of input height with a 4 dp
minimum gap. Their arrows stay beside the owning row, including while
collapsed. The quest arrow stays beside its tracker too. The small visible
surfaces are aligned against the row, with extra transparent input space to
the left. These controls receive placement priority and keep their panel space
reserved after collapsing. The global-buff tray fits clear of these controls
and the location/options panels, including at 150% scale.

The focused `mobile_top_right_collapse_check` passed 720 checks across 75%,
100% and 150% scale and every combination of the three panels' collapsed
states. Local viewport presses on both the visible arrow and transparent
padding reach the intended panel and keep the arrow position stable. The
broader mobile check passed 34,397 checks; the rendered native preview passed
541 checks and its expanded/collapsed screenshots were inspected. These are
local checks, not automated physical-device results or release certification.
The original small UI-scaled visuals and 48 dp minimum input areas remain.
The desktop side-layout contract passed. The quest-journal contract retained
two pre-existing assertions about English objective/title strings; running
the same check with the original three UI source files restored reproduced
exactly those failures. All its tracker layout/collapse assertions passed.

## Previous physical QA workflow

These commands document the earlier run, not an instruction to repeat
automated touch tests on this phone.

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
checks for the original Android density fix with normal project configuration
restored; current revision results are listed above.
