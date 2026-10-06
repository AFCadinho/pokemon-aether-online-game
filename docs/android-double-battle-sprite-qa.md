# Android double-battle sprite check — 2026-10-06

PASS in the native Android 13 x86_64 emulator `PokeAether_Android13`, using the
1080×2400 / 480 dpi screen profile and a landscape viewport. Godot 4.6.2,
Compatibility renderer, OpenGL ES 3.1. Product source includes sprite fix
`ed154bc09`, integrated by `369b38b12`.

The separate debug package `com.pokeaether.coopspriteqa` mounts the real
`battle.tscn`, calls `setup_coop_battle()`, and applies four-position snapshots
through the existing co-op presenter. It uses the regular sprite downloader,
Android disk cache, HOME icon loader and `AnimatedSprite2D` rendering. The
fixture server reads the slot's existing Pokémon sheets and HOME PNGs; it does
not replace the downloader or supply synthetic battle frames.

Each case starts with the first Pokémon on each side already downloaded. The
second Pokémon starts as a shiny HOME icon. Its animation metadata response is
delayed by six seconds. The battle becomes visible before those downloads
complete, and repeated snapshots preserve the pending requests.

| Presentation fixture | Player side | Opponent side | Final idle frame counts |
| --- | --- | --- | --- |
| Wild double battle | Pikachu, shiny Bulbasaur | Geodude, shiny Golbat | 35, 41, 50, 59 |
| Trainer double battle | Pidgey, shiny Charmander | Rattata, shiny Squirtle | 27, 69, 26, 29 |

Both native sprite boxes enable downloads. All four sprites end visible,
playing, with multiple animation frames and no `home_fallback` metadata.
Animation frame/progress advances for every position. Before/after screenshots
were retrieved from the diagnostic package and visually inspected. All 27 local
HTTP requests returned 200. The successful run has no Godot script/runtime errors.

Evidence is retained under
`game/.worktrees/slot-b/.tmp/coop-sprites-emulator/`: result JSON, per-case JSON,
HTTP request log, Android logcat and four screenshots. An initial run lacked a
working ADB reverse connection and was discarded; the passing run starts with
only the diagnostic package's data cleared.

This is an offline native presentation test using fixture snapshots. It does
not cover a logged-in server-created battle, production asset delivery or
physical-device GPU behavior. Automatic APK/music checks and crash dialogs are
disabled only in the exported diagnostic; mobile asset URLs use loopback. The
installed game package is not updated or launched by this check.

## Repeat in an assigned slot

Start the dedicated Android emulator, then use the SDK's ADB consistently.
The examples assume `slot-b` is already assigned to this verification task:

```sh
ops/worktrees/slot-env slot-b -- python3 .worktrees/slot-b/frontend/tools/export_battle_entry_web_qa.py --suite coop-sprites --platform android --architecture x86_64 --sdk /home/adinho/Android/Sdk --output .worktrees/slot-b/.tmp/coop-sprites-emulator
python3 .worktrees/slot-b/frontend/tools/serve_coop_sprite_qa.py --log .worktrees/slot-b/.tmp/coop-sprites-emulator/http-requests.jsonl
```

In a second terminal, use `/home/adinho/Android/Sdk/platform-tools/adb` with
`-s emulator-5580` to install `coop-sprite-qa.apk`, clear only
`com.pokeaether.coopspriteqa` for a cold repeat, reverse TCP port 8091, and launch
its MAIN/LAUNCHER intent. Keep the local server and ADB connection alive until
`files/coop-sprite-qa-results.json` is available through `run-as`. Its sole result
must be zero; `files/coop-sprite-platform-details.json` must report Android,
`mobile: true`, zero failures, and both four-sprite cases. Retrieve the four
`files/coop-sprites-*.png` captures and review the final frame of each case.

After collecting evidence, force-stop and uninstall only the diagnostic
package, remove the TCP reverse mapping, and stop the local fixture server.
Project, export preset and slot editor-setting changes are temporary and
restored by the export tool.
