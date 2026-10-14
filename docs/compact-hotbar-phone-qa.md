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
93 checks, no failures, nine samples and a zero result code; inspect runtime
logs for errors as well. Retrieve the screenshots named in the report through
`adb exec-out run-as com.pokeaether.hotbarqa cat files/NAME.png`. Try the page
arrows manually. Do not run the older automated phone-tap tool.
