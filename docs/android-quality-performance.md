# Android quality and performance diagnostics

This first implementation provides explicit presets and opt-in measurements.
It does not assign a hardware tier, run a startup benchmark, enable experimental
3D on ordinary builds, or automatically change a player's quality/presentation.

## Player controls

Android Graphics offers these budgets for the next 3D battle:

| Preset | Maximum short render edge | MSAA | Shadows |
| --- | ---: | ---: | --- |
| Low | 540 px | Off | Off |
| Medium | 720 px | 2× | Authored |
| High | 1080 px | 2× | Authored |
| Ultra | Native | 4× | Authored |

Aspect ratio is retained in landscape and portrait; small screens are never
upscaled. Both arena passes use the same profile. Ultra preserves the previous
native raster and authored appearance. Existing and new profiles default to
Ultra pending real-device evidence for automatic advice. Presets do not change
models, textures, gameplay effects, battle rules, UI size, or the 2D/3D choice.
The quality selector is disabled on builds without 3D presentation support.
The separate 30/60 FPS limit applies immediately to the Android engine. These
are target limits, not a promise of sustained performance.

A borrowed environment retains its profile for its entire battle. Changing
quality discards idle/prewarmed worlds and marks a borrowed pool for release
after its battle. Prewarmed UI metadata includes quality to prevent stale reuse.
Desktop/browser rendering remains on its existing path.

Android Support offers **Share Android performance diagnostics**, initially off.
The client samples only while opted in, authenticated, foreground and outside
impersonation. Opt-out cancels the request and clears all pending samples.
An already accepted report remains subject to server retention.

## Collection and transport

- Constant-size histogram, one monotonic engine frame interval per frame.
  Bounds in milliseconds: 8, 12, 17, 25, 34, 50, 100, 250, 1000, 600000.
  No per-frame dictionaries, sorting or network requests.
- Foreground windows close after approximately 30 seconds or a context/profile
  change. Context is sampled twice per second: overworld, battle, loading, menu.
  Effective 3D raster/profile is taken from the visible presenter, not a pending
  next-battle preference. 2D fallback is reported as 2D.
- Frame counts, summed duration, maximum interval, histogram, intervals above
  50/100 ms, and intervals above 1.5× the selected frame budget are included.
  This tolerance prevents ordinary 30/60 FPS pacing jitter being called a stall.
- Scene timing is coarse. `loadingDurationMs` measures a completed, observed
  foreground loading episode, including consecutive 30-second windows. It is
  not an exact map/HTTP/shader timer. Focus loss discards the unfinished window
  and loading episode, so background time cannot enter frame or load timings.
- Render/texture counters and draw calls are sampled twice per second. The
  native bridge samples API level, process PSS, thermal status and power-saving
  mode at most once per five seconds. Missing native fields stay absent.
  Godot static-memory counters are excluded because they are unavailable in
  release exports. GPU counters are engine estimates, not process RAM; do not
  add process PSS and render/texture allocations together.
- Reports include model/GPU, actual packaged build/version, renderer, debug
  status, preset schema, screen/raster size and foreground session age. They do
  not include account IDs, installation IDs, Android IDs, chat, maps, teams,
  battle identities, free-form logs or stable session identifiers.
- At most eight queued and eight in-flight reports, in RAM only. A fresh random
  UUID per window supports deduplication without installation tracking.
  Upload uses normal game authentication to
  `POST /account/game/client-performance` once per minute, with an eight-second
  timeout. Up to three attempts use exponential backoff; queues evict oldest
  windows when full. 404/410 stop collection until settings change or restart.
  Account switches/logouts clear pending data.

These are engine-loop intervals, not display presentation timestamps or direct
CPU/GPU work durations. A frame cap therefore limits what a fast-device sample
can reveal. Use the existing explicit USB probe for detailed renderer diagnosis.
Histogram percentiles are bucket upper bounds, never exact p95 measurements.

## Focused local checks

From the workspace, with this task assigned to slot A:

```sh
ops/worktrees/slot-env slot-a -- godot --headless --path .worktrees/slot-a/frontend \
  --script res://tests/android_quality_performance_check.gd
ops/worktrees/slot-env slot-a -- godot --headless --path .worktrees/slot-a/frontend \
  --script res://tests/android_3d_platform_check.gd
ops/worktrees/slot-env slot-a -- godot --headless --path .worktrees/slot-a/frontend \
  --script res://tests/android_move_camera_settings_check.gd
```

The first check writes `.tmp/android-performance-contract.json` in its own
frontend slot. Pass its mounted path as `ANDROID_PERFORMANCE_CONTRACT` to the
paired backend's `tests.test_client_performance` for an actual serialization
contract check. All network-capable collection stays disabled on desktop.

## Physical follow-up

On a separately authorized test build, compare the same world/battle journey
on the S25 Ultra and a weaker physical device. Run each relevant preset through
loading, busy overworld, menus and effects, then a sustained 20-minute session.
Record FPS limit, charging state, power-saving mode, renderer, installed assets
and warmth. Compare equivalent workloads; changing Low on the S25 does not
simulate a slow phone. Check UI sharpness, shadows, both arena passes, touch,
app background/resume, opt-out and capped offline retry behavior.

No physical-device performance gain, sustained FPS, power-use reduction or
visual approval is established by the headless checks. Automatic recommendations
and an admin dashboard remain subsequent work once these measurements exist.

References: [Godot Performance monitors](https://docs.godotengine.org/en/4.6/classes/class_performance.html),
[Android thermal API](https://developer.android.com/reference/android/os/PowerManager#getCurrentThermalStatus()).

## Local validation result (2026-10-15)

- Five focused Godot checks passed: Android quality/performance, Android 3D
  platform, Android camera settings, settings interface, and headless battle
  raster sizing at 720p/1080p/1440p. Both actual cave pool passes were checked
  with Low MSAA/shadows, and actual settings persistence/opt-out were exercised.
- Native desktop UI captures of Graphics and Support were visually checked.
- The Java bridge compiled against Android API 35 and the actual AndroidX core
  library. Forty-one paired Account tests passed with the Godot-emitted report
  validated through HTTP, stored and deduplicated.
- One migration head remains; PostgreSQL upgrade SQL generated successfully.
  Migration upgrade/downgrade was exercised against SQLite, not a live database.
- The optional windowed desktop raster check fails when the window manager
  constrains requested 1920×1080 to actual 1920×1008. The unchanged baseline
  presenter reproduces that same failure; no acceptance threshold was relaxed.
  The standard headless check passes all three requested sizes.

Those local checks did not include a phone test. The subsequent isolated
[S25 Ultra smoke test](android-quality-phone-smoke.md) records physical preset,
native telemetry and lifecycle results. A subsequent
[20-minute Ultra soak](android-quality-soak.md) measured sustained behavior of
the fixed forest renderer. A later [Medium duration test](android-quality-medium-soak.md)
completed twenty minutes near 60 FPS on that S25 under recorded USB-power
conditions. Full gameplay and weaker-device behavior remain to
be measured. No release certification, deployment or
production collection was performed.
