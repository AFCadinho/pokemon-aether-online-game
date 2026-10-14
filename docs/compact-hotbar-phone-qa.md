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

## Integrated native page counter and swipe navigation

The task `touch-hotbar-navigation` starts at local development
`00c5e04213d7c654e35914569153f2a54b1368ec`. Native touch HUDs use one
page counter that cycles through the available pages. It is part of the
hotbar's own frame and inherits its visibility and drawing order. The native
footer is 16 dp high with 8 dp minimum text; the visible counter is `1/3›`.
Its dark slot background, muted gold caption and thin blue separator match
the existing HUD palette without increasing the visible footprint.
The existing tiny desktop arrows are retained for desktop and browser layouts.

The 48×48 dp minimum input rectangle extends to the left and below the visible
footer through transparent padding. It does not cover the slots. The hotbar
and its input area fit together beside quick buttons, buffs and the trainer
card; collapse controls fit around that area. The footer follows the hotbar
when dragged and hides when its owner collapses. This avoids the detached
button appearance reported by the player.

On the same Samsung SM-S938B the final offline probe passed **318 checks with
zero failures**, including nine screenshots across 75%, 100% and 150% scales,
page wrapping, touch size, viewport bounds, world-movement blocking, separation
from slots and other HUD controls, and containment of the visible page counter
within its frame. The screenshots were inspected at all three scales. Device
runtime logs contained no script errors. Evidence remains in
`game/.worktrees/slot-b/.tmp/touch-hotbar-navigation-phone/styled-footer/`.
APK SHA-256: `b1a358c693e466bcbbbc90627dee40fc00d33b50f0b06fc0962117c73538c2af`.
The player confirmed manual counter taps and left/right swipes work with the
integrated footer. The final palette polish retained that geometry and passed
the same 94 local assertions and 318 physical-device checks.

A horizontal gesture starting on a slot changes one page after 24 dp. A back
swipe uses the available travel near the right screen edge, with an 8 dp
minimum. Movement below the threshold cancels slot activation when it ceases
being a tap. Stationary taps and long presses keep their existing behavior;
ordinary mouse and unrelated touch controls retain their drag flow. No
automated Android taps or swipes were sent to the physical phone.

Local `player_hotbar_responsive_check` passed 94 assertions, including native
counter taps, wrapping, both swipe directions, back swipes at the screen edge,
cancelled swipes, suppression of slot activation/dragging while paging,
stationary long presses, collapse/reopen behavior, resizing and desktop pager
restoration. The 27 touch-context gesture checks, 34,397 mobile collapse
assertions and Bag/hotbar localization check also passed. The SceneTree phone
probe compiles directly and the exporter compile-checks its generated Node
adapter before building the APK. This remains offline HUD QA.
