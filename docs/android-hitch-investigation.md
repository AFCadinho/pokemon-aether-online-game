# S25 Ultra action/menu hitch investigation — 2026-10-15

The native follow-up isolates two measured setup costs and a limitation in the
[earlier gameplay smoke](android-quality-gameplay-smoke.md): rebuilding the menu
and loading the router inside its measurement window differ from the ordinary
scene lifecycle. Attack resource preparation is a real remaining cost even when
effect geometry is not drawn. No production renderer, defaults, quality mapping
or automatic warm-up behavior was changed by this investigation.

## Measured setup and menu behavior

The three-window profile completed twelve real-time casts, three reconstructed
Medium forest arenas, and both new and retained menu navigation in every arena.
Diagnostic subclasses wrap the production effect `_process` methods with a
monotonic wall timer. Router markers separate audio/model/effect setup; spans
measure script loading, menu instantiation, `_ready`, opening and closing.
The ordinary production factory's effect script was checked against every
wrapper's base script after measurement, without prewarming the measured trial.

| Synchronous operation, ms | First arena | Second arena | Third arena |
| --- | ---: | ---: | ---: |
| Router script load + construction | 156.60 | 0.07 | 0.04 |
| Menu resource load | 1.26 | 0.64 | 1.24 |
| Menu scene instantiation | 5.32 | 2.29 | 5.53 |
| Add menu to tree / `_ready` | 104.29 | 103.83 | 147.36 |
| First `open("game")` on new menu | 3.40 | 3.65 | 3.88 |
| `open("game")` on retained menu | 16.33 | 22.34 | 24.34 |

The large new-menu spans overlap **132.64 / 127.11 / 176.20 ms** loop
intervals. Closing and reopening the same instance produced smaller but still
above-budget intervals of **36.32 / 42.88 / 45.47 ms**. Retention is therefore
not proof of perfectly smooth menu interaction. Other tab transitions also
occasionally exceeded the 16.67 ms target interval.

The actual `ui_overlay.tscn` owns its SettingsMenu instance. The overlay's
`_on_settings_button_pressed()` calls `open()` on that existing node. The login
scene similarly owns its menu. Menu construction is a scene-loading cost, not
work normally repeated on each settings-button press. The previous private
smoke deliberately destroyed/recreated the menu and therefore cannot establish
that every real settings opening stalls for 175–236 ms.

Likewise, `battle.gd` preloads and creates its router during scene setup. The
private smoke dynamically loaded that script at the start of its first measured
sequence. The **156.60 ms** measured first router load is a diagnostic placement
cost, not proof that a real player's first attack necessarily pays it. The
original timings remain intact; their interpretation is now more precise.

Attack stalls are separate. In this first profile, first Rock Slide reached a
**265.55 ms** loop interval. Its first effect `_process` call took **65.51 ms**;
`effect_start → effect_ready` took **66.22 ms**. First Flamethrower/Draco Meteor
also had expensive lazy effect processing. Pipeline counters changed while
larger first-use stalls occurred. These observations justify isolating resource
creation from drawing; they do not attribute all lost time to GPU compilation.

## Same-APK visibility control

A second APK added four consecutive 30-second windows with effects **visible,
hidden, hidden, visible**. All use Medium, animated v16 Charizard/Dragonite,
both forest passes at **1560×720 / 2× MSAA**, authored shadows, a 60 FPS cap,
fixed camera/noon/wind, real router/audio/recovery, and new/retained menu visits.
Each window reconstructs the arena. Only the effect root's visibility changes.

Hidden effects still run the same clocks, `_process`, geometry/material creation
and impact/recovery logic. Positive active-geometry counts and zero
`render_visible_frames` are required for every suppressed cast. The last window
requires positive visible counts again, and its unmeasured impact captures are
checked separately. This control suppresses effect drawing, **not allocation,
shader/material preparation, resource uploads or all possible driver work**.

| Window | Effects | Whole-window FPS | Rock Slide max interval, ms | Rock `_prepare`, ms | Rock `_wave_mesh`, ms | Pipeline delta: surface / draw |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | Visible | 56.86 | 266.31 | 64.08 | 1.16 | 36 / 12 |
| 2 | Hidden | 58.63 | 74.21 | 52.98 | 6.07 | 26 / 0 |
| 3 | Hidden | 58.56 | 65.11 | 44.24 | 6.04 | 26 / 0 |
| 4 | Visible again | 58.62 | 73.79 | 53.58 | 6.04 | 26 / 12 |

The largest intervals over each *whole* window were **266.31 / 194.22 /
174.69 / 175.07 ms**. Later maxima overlap new-menu initialization, not the
nested Rock Slide cast. Whole-window averages contain idle rendering, both
menu visits and setup; they are not attack FPS or a replacement for the earlier
fixed-scene twenty-minute soak.

The measured Rock Slide main-thread effect-call maxima were **65.15 / 53.93 /
45.14 / 54.55 ms**. Its inclusive `_prepare` span accounts for almost all of
that peak. `_wave_mesh` is nested within `_prepare`; the two durations must not
be added. That particular procedural mesh is only part of the preparation cost,
so optimizing it alone cannot remove the measured stall.

The hidden middle windows still created active geometry, reached impact and
cleaned up, but none of those effect roots was visible in the scene tree. Their
65–74 ms Rock Slide intervals and 44–53 ms preparation spans show that drawing
extra effect pixels is not required for the repeated hitch. Surface pipeline
counters also grew without draw-pipeline growth. Main-pass GPU p50 remained
about **11.83 ms** across the windows; rare GPU peaks still occurred. These
measurements support prioritizing action-time resource preparation. They do not
fully separate script execution, rendering-server synchronization, shader
creation/compilation, allocations or driver scheduling.

## Next implementation work

The next focused optimization should remove repeated immutable shader/mesh
construction from action-time effect setup, starting with Rock Slide and the
other measured lazy effect paths. Keep per-cast materials/uniforms and actor
clocks isolated. Measure preparation time and first/repeated casts again with
the same scene and validate impact visuals, cancellation and memory ownership.
A bounded preparation step behind the existing battle-loading cover is another
candidate, but must be measured together with the extra loading time.

The existing Android move warm-up remains an explicit local feature gate.
It prepares hidden, separately retained effects; the ordinary factory creates
new instances. Enabling it blindly is not an established fix for repeated setup
or first visible draw costs. The visibility control specifically demonstrates
that hidden preparation can still incur resource work. No automatic warm-up or
larger global cache was introduced here.

For future gameplay averages, load/create the router and menu in their actual
scene preparation phase, then retain/reopen the menu during the action window.
Keep constructor timings as separate evidence instead of silently dropping
those costs. Real authenticated world loading and release-build timing still
need their own tests. A thread/driver trace is needed if the remaining first
visible-draw stall cannot be explained after reducing the measured setup costs.

## Verification, conditions and evidence

All seven observations across the two independent runs completed with no engine
or check errors, no measured Android background interruption, the expected
profile/raster/AA, real effects/impacts and effect/audio cleanup. Each profiled
new/retained menu visited all eight tabs; retained instance IDs matched. Neither
run truncated its bounded event arrays. Actual HOME/resume (2 pause/2 resume
notifications each) and opt-out cleanup passed. Seven unique USB-local summaries
satisfied the exact backend `PerformanceReport`/`PerformanceBatch` classes in a
network-disabled Python 3.13 container. No account, authenticated ingestion,
database or production service was used.

Twenty-eight focused Python quality/GPU harness tests passed, including rejection
of truncated/invalid spans, missing effect probes, replacement of the retained
menu, a changed effect-factory mapping, wrong visibility order, hidden effects
that remained visible, or controls without active geometry. Both exported
scripts parsed and both native APK builds completed. First-profile flame and
rock impact images were visually inspected; the final control's visible impact
images passed the clock/geometry checks as well.

Device: SM-S938B / S25 Ultra, Adreno 830, Android API 37, Mobile/Vulkan,
ARM64 debug, game 0.3.110. First profile battery sensor **26.8→29.1 °C**;
control **27.3→29.7 °C**. Both were full 100%, status 5, USB powered, AC false,
power saving off. All native/host thermal statuses were **0**. No fixed CPU/GPU
frequency or controlled room temperature/brightness/background load was used.
Caches from earlier diagnostic runs were retained. There are no causal speedup,
energy or sustained-thermal claims from this short experiment.

Call timers measure wall time on the main thread, including any waits inside
production calls, not scheduled thread CPU time. Slow-loop events, sampled
Performance monitors and GPU queries can have different update/visibility
latencies; pipeline counters are supporting evidence, not exact driver-stack
attribution. Instrumentation, debug overhead and host health queries can affect
the results. Scope remains the private scripted renderer/UI fixture.

Retained in this slot's ignored `.tmp/android-quality-phone/`:

- `hitch-run-1/`: initial profile, raw report/details/telemetry, derived
  `profile-summary.json`, own arena/settings/impact images.
- `hitch-export-1/`: APK/logs from clean `ecf71720f07089817442e618a088d2bb3846d7e5`;
  SHA-256 `e7cec2d5afe404cf37e6acecac6b9defce05b9b494afd4b3cdcb0bea9a9ae958`.
- `hitch-visibility-run-1/`: four-window control and equivalent raw/derived files.
- `hitch-export-2/`: control APK/logs from clean
  `1e8ed1313dfdbb39ee02a722a650649baf6517ff`;
  SHA-256 `db15e2a45395cc18ee5a0cd9ee828a455cc3f833870c3dcb723cc894c5c22081`.

Reproduce with a fresh output folder, the separate Android-quality APK and the
assigned slot environment, adding these options to the existing USB runner:

```sh
--mode gameplay --profile-hitches
# Or the bracketed draw control:
--mode gameplay --profile-hitches --hitch-visibility-control
```

The diagnostic process was stopped and its exact USB reverse removed after each
run. The ordinary game/account/data/settings were untouched. No backend source,
production activation, release certification, promotion, publishing or deployment
was performed.
