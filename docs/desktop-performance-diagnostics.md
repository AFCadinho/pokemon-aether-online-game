# Desktop performance diagnostics

Native Windows, Linux and macOS clients share the Android collector's bounded
frame accounting and authenticated transport. Browser and other mobile clients
do not run this collector. Android and desktop each run only their own service.

## Player controls and data

Support offers **Share desktop performance diagnostics**, enabled by default for
new profiles or a missing preference. Saved false values and malformed values
remain disabled. The preference is independent from Android. The four catalogs
explain the default, the data and the option to turn sharing off. Turning it off
cancels an upload and clears pending samples; already accepted data follows
server retention. No chat, team, account ID, host name, serial, installation ID
or stable session identifier is included in the report. Authentication uses the
existing native game session, outside the report payload.

Only authenticated, non-impersonated foreground activity is sampled. Focus loss
discards the incomplete frame/loading window rather than recording background
time as a long frame. Account changes/logout discard pending data. Reports
carry a fresh random UUID per window for retry deduplication.

Frame windows close at about 30 seconds, context changes, or 10,000 frames
(important for uncapped desktop FPS). Context and engine graphics allocation /
draw-call peaks are sampled twice per second. A constant-size histogram records
engine-loop intervals each frame; these are not presentation timestamps or
direct GPU/CPU execution times. Loading duration is a coarse observed episode,
not an exact shader, HTTP or map timer. Histogram percentiles are bucket upper
bounds, not exact benchmark percentiles.

Desktop reports include OS family, CPU/GPU model, renderer, packaged build and
version, debug status, selected FPS, VSync mode, quality schema, current scene,
presentation and actual window/3D raster dimensions. The active stage's captured
quality takes precedence over a pending next-battle preference. GPU allocation
estimates are not total process RAM. Desktop PSS, temperature and power-saving
status are **absent**: the collector does not invoke Android JNI or external
hardware-monitoring commands.

Desktop supports FPS 0/30/60/120. Zero means uncapped and remains subject to
VSync. Its `overBudgetFrames` is zero because there is no selected FPS budget;
frame histogram, maximum and counts above 50/100 ms still show stalls. For a
positive cap, over-budget means greater than 1.5 times its frame interval.

## Transport and server

At most eight queued and eight in-flight windows remain in RAM only. One small
batch is sent each minute to `/account/game/client-performance`, with an
eight-second timeout and at most three attempts with backoff. A full queue
evicts the oldest windows. This is diagnostic sampling, not guaranteed archival
of every frame or battle. A 404/410 cancels collection until a settings change
or restart. No screenshot, benchmark CSV or local probe log is uploaded.

Server ingestion remains independently disabled by default through
`DESKTOP_PERFORMANCE_ENABLED=false`; Android retains its existing switch. Both
must be deliberately configured for their respective platforms after deployment.
This implementation does not activate production ingestion. Existing storage
and fourteen-day bounded retention apply to both platforms without a migration.

Staff use `/admin/api/diagnostics/client-performance?platform=desktop` (or
`android`, or omit the filter for both), with the existing `DIAGNOSTICS_VIEW`
permission. The older Android endpoint stays Android-only. Groups separate OS,
CPU, GPU, renderer, version/build, debug/release, profile, FPS, VSync and scene /
raster context; they count windows/frames, not unique players or machines.

## Focused verification

From the workspace, while this task is assigned to slot A:

```sh
ops/worktrees/slot-env slot-a -- godot --headless --path .worktrees/slot-a/frontend --script res://tests/desktop_performance_check.gd
ops/worktrees/slot-env slot-a -- godot --headless --path .worktrees/slot-a/frontend --script res://tests/android_quality_performance_check.gd
```

The desktop check exercises real settings/menu persistence, default-on and
saved opt-out, malformed preferences, immediate request/queue cancellation,
focus/logout/server-disable cleanup, active-stage quality, uncapped accounting
and all four FPS report shapes. It writes
`.tmp/desktop-performance-contract.json` in its own frontend slot.
Supply that path as `DESKTOP_PERFORMANCE_CONTRACT`, and the Android fixture as
`ANDROID_PERFORMANCE_CONTRACT`, to the backend's Python 3.13
`python -m unittest tests.test_client_performance` in an isolated environment.
The suite exercises actual FastAPI requests, strict schemas, independent
switches, deduplication, storage/retention, permission checks and aggregation.

These local checks do not certify exported Windows/macOS builds, fleet load,
the live gateway, real game-session validation or production delivery. Release
exports and an explicitly authorized test environment remain rollout checks.
