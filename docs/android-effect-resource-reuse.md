# Android attack resource reuse — 2026-10-15

The follow-up to the [hitch investigation](android-hitch-investigation.md)
removes repeated immutable resource construction while preserving per-cast
animation state. On the S25 Ultra, repeated Rock Slide preparation fell from
49.84–52.07 ms to 0.10–0.16 ms in the same scripted control. Its first cast
still reached a 233.12 ms loop interval. This change improves repeated setup;
it does not solve first-use hitches or establish performance on weaker phones.

## Implementation and ownership

Eight unchanged inline shader programs are now preloaded `.gdshader` resources:
source sprite/water beam, Flamethrower puff/core, Draco Meteor lava, energy/tail
volumes and Rock Slide stone. Each extracted program is byte-identical to its
former string. A ninth shader preserves the exact former Moonblast runtime
specialization. That subclass previously edited `sprite_shader.code` in place;
it now selects its own program without mutating the shared source shader.
The ground-rock variant already duplicates its shader before modifying it.

Three fixed procedural ArrayMeshes are lazily retained: the Rock Slide boulder
and the two swept volume shapes. Their consumers treat the geometry as
read-only. The cache has no actor keys, scene references or expanding map.
ShaderMaterial instances, uniforms, opacity, clocks, transforms and scene nodes
remain per cast. Cancelling one effect therefore cannot stop or fade another.

Rock Slide now skips the generic cinematic materials, wave and funnel that its
dedicated renderer never uses. Its dedicated drawing path also skips unused
generic material updates. Shape generation, trajectories, timing and shader
math are preserved. Preloading moves some resource work earlier, and lazy mesh
creation still costs time on first use. No automatic warm-up, quality default,
quality assignment or renderer setting was changed.

## Matched physical control

Fresh baseline and candidate runs used the same existing diagnostic runner,
device and four 30-second windows: **visible, hidden, hidden, visible**. Every
window reconstructs the forest arena and casts Flamethrower, Thunderbolt, Rock
Slide and Draco Meteor through the real router with audio, impact, recovery
and cleanup. Both new and retained settings menus visit all eight tabs.
Hidden effects retain their ordinary clocks and active geometry but must have
zero rendered-visible frames; the final window requires visible effects again.

Both runs used Medium, animated v16 Charizard/Dragonite, fixed camera/noon/wind,
both passes at 1560×720 / 2× MSAA, authored shadows and a 60 FPS cap. This is
an offline renderer/UI fixture, without authenticated world/network gameplay.

| Window | Effects | Rock `_prepare`, before → after ms | Rock max loop interval, before → after ms | Whole-window FPS, before → after |
| --- | --- | ---: | ---: | ---: |
| 1 | Visible | 57.597 → 54.736 | 239.107 → 233.117 | 57.09 → 57.09 |
| 2 | Hidden | 52.071 → 0.103 | 72.559 → 34.945 | 58.73 → 59.02 |
| 3 | Hidden | 51.385 → 0.126 | 70.499 → 36.885 | 58.49 → 58.90 |
| 4 | Visible again | 49.839 → 0.159 | 68.744 → 38.881 | 58.39 → 59.06 |

The candidate no longer calls the unused Rock Slide `_wave_mesh`. Repeated
preparation is small, including after destroying/reconstructing the arena.
The first preparation is still expensive: immutable resources are created on
first use. Remaining Rock effect-call maxima are 55.84 / 24.02 / 27.95 / 27.02
ms, so this optimization does not remove all action-time allocation or waits.
The `_prepare` span is nested inside the effect call and must not be added to it.

Other per-cast maximum loop intervals are reported without selecting only wins:

| Move | Window 1, before → after ms | Window 2, before → after ms | Window 3, before → after ms | Window 4, before → after ms |
| --- | ---: | ---: | ---: | ---: |
| Flamethrower | 159.14 → 161.03 | 46.39 → 34.72 | 56.56 → 36.33 | 54.92 → 40.49 |
| Thunderbolt | 25.92 → 22.54 | 35.83 → 23.34 | 34.40 → 25.50 | 32.72 → 19.08 |
| Draco Meteor | 56.11 → 64.03 | 52.84 → 34.22 | 55.18 → 27.66 | 78.15 → 26.32 |

The first Flamethrower interval includes the fixture's dynamic router load
(143.15 → 143.45 ms). Production preloads its router during battle scene setup;
this is not proof of the same cost on the first real attack. Menu `_ready`
still takes 92.78–151.64 ms in the candidate. Later whole-window maxima remain
171.50–182.42 ms around menu construction. Actual retained-menu `open()` takes
18.30–25.16 ms in the candidate and is a separate remaining issue. See the
earlier investigation for the ordinary menu lifecycle.

Whole-window averages include setup, menus and idle frames, rather than only
attacks. Main-pass GPU p50 stays about 11.83 ms. Surface pipeline deltas change
from 36/26/26/26 to 34/24/24/24, and draw deltas from 12/0/0/12 to 11/0/0/11.
These counters can lag and do not identify a complete driver or CPU cause.
The much smaller repeated preparation supports the intended resource reuse;
the small first-cast timing difference does not establish a first-use fix.

Per-window PSS is 2028.9–2031.8 MiB before and 2056.8–2063.0 MiB after. Render
memory is about 533.39 → 533.35 MiB. The candidate's total PSS is higher in this
pair; there is no memory-saving claim. Three retained meshes have a fixed
count, but this short control is not a long-duration memory-growth test.

## Verification and limits

Both accepted runs completed with `usable: true`, no engine/check errors,
matching production effect factories, no measured foreground interruption,
no truncated probe arrays, four unique reconstructed stages, successful
impacts/audio/effect cleanup and correct hidden/visible controls. Actual
HOME/resume and opt-out cleanup passed (two pause/two resume notifications).
Eight unique USB-local reports passed the exact backend PerformanceReport and
PerformanceBatch schema classes in a network-disabled Python 3.13 container.
This validates serialization and USB transport, not authenticated ingestion,
server storage or production telemetry activation.

All four candidate impact images were visually inspected outside measurement;
Rock Slide was also compared with its baseline image. Capture requires an
active effect after its configured impact time. Shader text parity and the
focused motion tests provide additional checks; these are not pixel-identical
golden comparisons across different sampled frames.

Focused checks passed through the assigned slot environment:

- `move_resource_isolation_3d_check.tscn`: five concurrent effect pairs,
  independent materials/clocks, three shared mesh identities, Moonblast/source
  and ground/stone shader isolation, and cancellation without retaining nodes.
- `rock_slide_3d_check.tscn`: 1,026 samples; singles/doubles, outcomes, framing,
  native pause, recovery, raised floors, dodge and cleanup.
- `rock_ground_3d_check.tscn`: 12,204 samples of the corresponding ground moves.
- `draco_meteor_3d_check.tscn`: three clips/outcomes, bounded geometry, fixed
  launch and impact/recovery.
- `source_move_effects_3d_check.tscn`: source move outcomes/bounded geometry;
  historical approved Ember art parity remains unavailable (`false`).
- `batch_four_moves_3d_check.tscn`: ten moves including Moonblast; paired actors,
  outcomes, bounded geometry, flight, pause/orbit, audio and recovery.
- 28 focused Python quality/GPU harness tests; native candidate APK export.

Device: SM-S938B / S25 Ultra, Adreno 830, Android API 37, Mobile/Vulkan, ARM64
debug, game 0.3.110. Battery sensor before **28.3→30.4 °C**, after **27.0→29.1 °C**.
Both runs were 100%, status 5, USB powered, AC false, power saving off; all
native/host thermal statuses were 0. Different starting temperature, retained
caches, fixed run order, uncontrolled clocks/background load and instrumentation
limit causal percentages and generalization. This is one short pair on one
high-end device, not weaker-device, release-build or sustained-thermal proof.
Effect-call timers measure main-thread wall time including waits, not scheduled
CPU execution time. Shader preloading also needs consideration during loading.

## Retained evidence and follow-up

In this slot's ignored `.tmp/android-quality-phone/`:

- `resource-reuse-before-1/`: fresh baseline report/details/telemetry and ten
  images, using the retained `hitch-export-2/` APK in place. APK source
  `1e8ed1313dfdbb39ee02a722a650649baf6517ff`; SHA-256
  `db15e2a45395cc18ee5a0cd9ee828a455cc3f833870c3dcb723cc894c5c22081`.
  Host source was clean `8ad9cbba36fb2534b963b04bb02f4c4d80ca0821` at launch;
  later frontend edits did not change that installed APK or loaded runner.
- `resource-reuse-after-2/`: accepted candidate report/details/telemetry and
  ten images. `resource-reuse-export-2/` holds its APK/build logs, exported
  from clean `e736d87881af9e103edfb79b1ce32eca1d1ee996`; SHA-256
  `2274533fe1ee8bd4cd218a764ab990d7a1c66f7cf2c6e91ebd6617496f0e0074`.
  Host source was that same clean commit at launch.
- `resource-reuse-comparison.json`: derived per-window metrics from both raw
  runs. `resource-shader-parity.json`: the nine shader comparisons/hashes.
- `resource-reuse-export-1/`: superseded unmeasured build before the Moonblast
  isolation fix. `resource-reuse-after-1/`: rejected startup attempt while the
  phone was locked; no accepted measurement. Neither contributes to the tables.

Reproduce the unchanged control with a fresh output directory and the separate
diagnostic APK via the assigned slot's runner using
`--mode gameplay --profile-hitches --hitch-visibility-control`.
The isolated diagnostic process was stopped and its USB reverse removed after
each run. The ordinary game/account data was untouched.

Next, investigate bounded first-use preparation under the existing battle
loading cover and measure loading time as well as the first visible draw.
Resource reuse alone leaves the first Rock Slide hitch largely intact; a
thread/driver trace may be needed to separate its remaining costs. Keep the
existing warm-up feature gated until ordinary factory instances, first visible
draw, loading cost and cancellation are verified together. No production
activation, complete release certification, promotion or deployment was done.
