# Browser fullscreen

The settings toggle calls the shell's Fullscreen API bridge for the game canvas.
The browser's actual fullscreen element, not a saved preference, determines the
toggle state. Exiting outside Godot (including the browser's Escape action)
updates the state; resolution choices stay unavailable in the browser.
Desktop display settings retain their existing behavior.

A request is made immediately without awaiting other work. If user activation
has expired, or the browser rejects the request, a visible `Enter fullscreen`
HTML button offers a fresh explicit gesture. Unsupported fullscreen disables
the settings toggle. Fullscreen is never requested during settings restoration.
Fullscreen changes refocus the canvas and notify the existing resize handling;
the automatic browser camera/zoom policy is unchanged.

Focused checks:

- `web_fullscreen_smoke.cjs`: Chromium's real canvas fullscreen, external exit,
  missing-activation retry, denied-request retry and toggle off.
- `web_fullscreen_game_smoke.cjs`: the real exported Godot preview at
  `127.0.0.1:8061`, using public API/news stubs and no account login. The Graphics
  toggle enters fullscreen, reflects an external exit, re-enters and exits.
  Screenshots confirm the off state after external exit. This test uses fixed
  1440 × 900 coordinates and needs updating when the settings layout changes.
- `settings_interface_revamp_check.gd`: existing native settings checks pass.
- Headless editor import succeeds without GDScript parse/compile errors.

Browser smoke commands require Playwright and Chromium. The engine smoke uses
software WebGL. Native keyboard Escape itself is not exercised by these
headless checks; they exercise the same external `fullscreenchange` exit path.
Safari/Firefox/mobile support and embedded iframe fullscreen permissions remain
manual compatibility checks. No production release or full certification is
implied.
