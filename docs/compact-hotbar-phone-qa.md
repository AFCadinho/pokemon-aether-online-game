# Compact hotbar — physical Android QA

Tested on 2026-10-14 with the attached Samsung SM-S938B, Android 17,
Compatibility/OpenGL ES 3.2 (Adreno 830), 2340×1080 landscape output and
450 dpi logical density (832×384 Android dp). Source started at local
`development` commit `fc8628359ec4a312728d184c7eb36638b4f0a6b5` and includes
the three-slot hotbar change `a8200a1f7` plus this placement correction.

The first complete geometry run found twelve hotbar/quick-button collisions
at 150% UI scale. An intermediate sideways placement cleared those buttons,
but visual inspection showed the wider buff panel covering the page arrows.
The correction fits the entire compact hotbar beside visible quick buttons,
personal buffs and the trainer card, repeating the fit after a sideways move.
It restores its original column when room returns and preserves dragged positions.

The final offline diagnostic passed **93 checks with zero failures** across
75%, 100% and 150% UI scales and all three pages. All nine screenshots and
geometry samples were retrieved from the diagnostic's own app data. Slots
1–3, 4–6 and 7–8 and the corresponding page labels were verified; every hotbar
rectangle stayed within the screen and clear of all seven bottom-right HUD
controls. Screenshots at 75%, 100% and 150% were visually inspected. At 150%
the full hotbar and its pager now sit to the left of the wider buff tray.

Local checks passed: `player_hotbar_responsive_check` (28 assertions),
`mobile_collapse_touch_size_check` (34,397 assertions), the phone probe's
Godot compile check, Python compilation of the exporter, and whitespace checks.
Existing UID fallback, offline unauthenticated preference and mobile-check
exit-leak warnings remained; no script runtime errors occurred in the final
phone diagnostic.

The separate `com.pokeaether.hotbarqa` debug package has no Android permissions,
including network access. APK/music updating and crash prompts are disabled
only in the diagnostic export. It uses the real HUD with an active quest,
all five quick buttons, personal buffs and the trainer card. It selects test
pages through HUD methods and sends **no automated pointer or Android input**.
Its scale picker and normal page arrows remain available for manual testing.
The player also confirmed that hand-operated paging works, while reporting
that the arrows are very small. Arrow size and touch comfort remain a usability
limitation of the existing pager; this placement correction does not enlarge it.

The normal game package and its data are retained. This is focused offline HUD
QA; logged-in gameplay and release certification were not exercised. No APK or
assets were published. Evidence remains under
`game/.worktrees/slot-b/.tmp/compact-hotbar-phone/final/`, including
`hotbar-details.json`, `hotbar-qa-results.json` and nine screenshots.
Final diagnostic APK SHA-256: `2c2552da949a224363fca51ed3e758797071d74def86d82c702c628ff035bc66`.

## Reproduce

Use an assigned slot and a user-authorized attached device:

```sh
ops/worktrees/slot-env SLOT -- python3 .worktrees/SLOT/frontend/tools/export_battle_entry_web_qa.py --suite mobile-hotbar --platform android --sdk /home/adinho/Android/Sdk --output .worktrees/SLOT/.tmp/compact-hotbar-phone
adb -s SERIAL install --no-incremental -r .worktrees/SLOT/.tmp/compact-hotbar-phone/hotbar-qa.apk
adb -s SERIAL shell am start -n com.pokeaether.hotbarqa/com.godot.game.GodotAppLauncher
adb -s SERIAL exec-out run-as com.pokeaether.hotbarqa cat files/hotbar-details.json
adb -s SERIAL exec-out run-as com.pokeaether.hotbarqa cat files/hotbar-qa-results.json
```

Keep the screen unlocked while the nine rendered samples complete. Require
the expected check count for the current probe, no failures, nine samples and a zero result code; inspect runtime
logs for errors as well. Retrieve the screenshots named in the report through
`adb exec-out run-as com.pokeaether.hotbarqa cat files/NAME.png`. Try the page
arrows manually. Do not run the older automated phone-tap tool.

## Native page button and swipe navigation

The follow-up task `touch-hotbar-navigation` starts at local development
`00c5e04213d7c654e35914569153f2a54b1368ec`. Native touch HUDs now use one
page button that cycles through the available pages. The embedded desktop
pager is hidden only for native touch. The old footer no longer takes up
space in the three-slot bar. The page button follows the bar and fits clear
of HUD surfaces and collapse controls; collapsing the bar hides it.

The initial full 48 dp square was rejected by the player as visually too
large. The final revision draws a **36×22 dp label** inside a **48×48 dp
minimum touch rectangle**, with 11 dp minimum text. Invisible padding accepts
taps while all four button states retain the compact surface. It has no
native hover tooltip. On the same Samsung SM-S938B the updated offline probe
passed **294 checks with zero failures**, including nine screenshots across
75%, 100% and 150% scales, page wrapping, label size, touch size, viewport bounds,
world-movement blocking and separation from the slots and other HUD controls.
The final screenshots were inspected at all three scales. Device runtime logs
contained no script errors. Evidence remains in
`game/.worktrees/slot-b/.tmp/touch-hotbar-navigation-phone/compact/`.
APK SHA-256: `2bd40819b4a89efe0e55ce776d03eef9ddc4eb59d8da0f9e28861eb6e923dbe1`.

A horizontal gesture starting on a slot moves one page after 24 dp. Movement
below that threshold cancels slot activation when the finger has moved enough
to cease being a tap. Stationary taps and long presses keep their existing
behavior; ordinary mouse and unrelated touch controls retain their drag flow.
No automated Android taps or swipes were sent to the physical phone.

Local `player_hotbar_responsive_check` passed 92 assertions, including native
page-button taps, wrapping, both swipe directions, cancelled swipes, suppression
of slot activation/dragging while paging, stationary long presses, collapse/
reopen behavior, large-touch-screen resizing and desktop pager restoration.
The 27 touch-context gesture checks, 34,397 mobile collapse assertions and
Bag/hotbar localization check also passed. This remains offline HUD QA.
