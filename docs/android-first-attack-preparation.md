# Android first-attack preparation — 2026-10-15

The [resource reuse follow-up](android-effect-resource-reuse.md) reduced repeated
setup but left a large first Rock Slide hitch. A new same-APK control shows that
preparing and then **consuming the exact effect instance** can move much of that
work into entry preparation. First Rock Slide's maximum loop interval was
**242.25 ms without preparation, 32.84 ms after hidden preparation, and 33.89 ms
after covered drawing** on the S25 Ultra.

The selected local trial uses hidden preparation. Drawing the samples did not
improve this first-cast result and took more preparation time. Automatic
activation remains disabled: this is a bounded experimental path, not a claim
that ordinary authenticated battles or weaker devices are now verified smooth.

## Ownership and entry behavior

The existing `android_3d_move_warmup` feature gate still requires experimental
Android 3D and the Mobile renderer. Its entry hook now prepares only the five
paths with a checked reset contract: Flamethrower, Thunderbolt, Rock Slide,
Draco Meteor and Tackle. Available own moves take priority; the existing common
set fills remaining candidates. Other renderer families use the ordinary
factory. The older broad hidden-sample diagnostic remains available as the
helper's `legacy` mode and is not handed to real casts.

Each stage retains at most one unused prepared node per reviewed move. On the
first matching cast, `take()` removes that node from preparation ownership and
the ordinary effect lifecycle owns it. A second cast falls back to a new node;
completed effects are never recycled. No actor-keyed or expanding global pool
was added. Deactivation, preparation cancellation and scene exit release unused
nodes; stale, completed or queued-for-deletion nodes cannot be handed out.

Preparation samples charge, flight and impact without playing an actor action,
moving the camera, playing audio or issuing battle commands. Actual resolved
timing and anchors are used when available. Before retention, the effect drops
its temporary callables, hides its geometry and resets its elapsed clock.
Draco's release latch and Rock Slide's captured positions/launch/impact state
are reset. Actual casting supplies its new native clock, outcome, timing,
positions and camera. Materials and geometry instances remain owned by that
single cast; the immutable resource reuse from the previous change is retained.

Work checks the existing 1,500 ms cooperative budget between samples and keeps
the existing eight-candidate ceiling; the reviewed reuse path has only five
keys. An individual synchronous construction/render operation can overrun a
cooperative deadline. Partial effects are cancelled rather than handed out.
Slow but complete diagnostic results are retained as timing evidence.

After the physical comparison, the real entry hook deliberately selects hidden
mode. It continues to run in the existing preparation phase and needs no new
cover/reveal lock because it never draws the sample effects. Covered drawing
is retained only as an explicit private quality-fixture control, under an opaque
full-screen rectangle, using the same battle viewport. The temporary host
drawing/reveal experiment in the measured source commit was removed; it was
not enabled by that APK's feature flags or exercised by the private fixture.

## Same-APK physical control

Three fresh processes ran in fixed order: **off, hidden, covered**. Each performed
three 30-second Medium windows, reconstructing the forest arena each time and
casting Flamethrower, Thunderbolt, Rock Slide and Draco Meteor through the real
router with audio, impact, recovery and cleanup. New and retained settings
menus each visited all eight tabs. Effects in the measured action windows were
visible in every condition. Preparation ran before the three-second settling
period and outside those action windows, with its own recorded duration.

All conditions used animated v16 Charizard/Dragonite, both passes at
1560×720 / 2× MSAA, authored shadows, a 60 FPS cap, fixed camera/noon/wind,
Mobile/Vulkan, ARM64 debug, and the same separate Android-quality APK.

| Condition | Effect preparation, windows 1 / 2 / 3 ms | Total arena + effect preparation, windows 1 / 2 / 3 ms | Rock Slide max interval, windows 1 / 2 / 3 ms |
| --- | --- | --- | --- |
| Off | 0 / 0 / 0 | 5062 / 2483 / 2792 | 242.25 / 38.00 / 41.08 |
| Hidden, same instance | 882 / 882 / 881 | 5959 / 3445 / 3359 | 32.84 / 30.48 / 31.78 |
| Covered drawing, same instance | 1282 / 947 / 914 | 5746 / 3619 / 3658 | 33.89 / 33.82 / 34.03 |

Hidden preparation costs about 0.9 seconds per reconstructed stage in this
fixture. The first covered preparation costs about 1.3 seconds. These isolated
durations are more useful than subtracting total entry times: unrelated arena
preparation varies between processes, and covered total first entry is actually
shorter than hidden total first entry in this sequence. No causal total-loading
speedup is claimed. None of the five sampled effects hit the cooperative budget.

| First process window | Off max / p95 interval ms | Hidden max / p95 interval ms | Covered max / p95 interval ms |
| --- | --- | --- | --- |
| Flamethrower | 149.86 / 48.98 | 141.86 / 17.78 | 141.94 / 17.67 |
| Thunderbolt | 23.58 / 17.35 | 25.85 / 17.43 | 23.57 / 17.28 |
| Rock Slide | 242.25 / 73.45 | 32.84 / 17.61 | 33.89 / 20.76 |
| Draco Meteor | 50.49 / 18.97 | 22.80 / 17.32 | 24.45 / 17.32 |

The first Flamethrower maximum contains the fixture's dynamic router load:
133.74 ms off versus 132.36 ms hidden. Production preloads its router during
battle setup. This fixture placement remains visible in the data and is not
proof of the same first-attack cost for players. First effect-call wall maxima
for flame / electric / rock / meteor are **34.31 / 2.65 / 55.79 / 25.53 ms** off,
and **2.01 / 2.28 / 2.06 / 2.03 ms** hidden. Preparation's per-effect setup and
sample timings are stored separately, rather than mixed into these cast probes.

The first preparation creates 23 surface pipelines in both variants; draw
pipelines increase by 0 hidden and 11 covered. Hidden preparation still performs
resource uploads/material and possible driver work. The large improvement
without drawing supports prioritizing exact-instance preparation and handoff;
it does not isolate a complete script/render-server/driver cause. Pipeline
counters and GPU queries can lag. It also does not prove hidden preparation is
sufficient for every effect, view, render target, shader variant or driver.

Whole-window FPS is **57.37 / 59.00 / 58.93** off, **59.00 / 58.96 / 59.08**
hidden and **58.78 / 59.00 / 59.02** covered. These windows include menus, setup
and idle rendering. New-menu initialization remains a separate hitch. Above
budget attack intervals also remain; 33 ms is not perfectly smooth 60 FPS.
This change does not alter the menu lifecycle, quality policy or presentation.

Per-window PSS is **2057.6–2058.5 MiB** off, **2061.5–2063.4 MiB** hidden and
**2058.4–2060.9 MiB** covered. Render memory stays about **533.36 MiB**. These
short observations do not establish memory savings, leaks or long-term growth.

## Verification, scope and evidence

All three native runs finished `usable: true`, without engine/check errors,
measured foreground interruption or truncated probe arrays. Factories matched
production base scripts. Every prepared measured cast consumed the recorded
preparation instance ID; hidden roots were suppressed and covered samples had
positive active/visible post-draw samples. The three arenas within each process were distinct,
all impacts/audio/effects cleaned up, retained menu IDs matched, and actual
HOME/resume plus opt-out cleanup passed in each process.

Nine unique USB-local reports passed the exact backend PerformanceReport and
PerformanceBatch classes as three batches in a network-disabled Python 3.13
container. This tests serialization and USB transport, not account-authenticated
ingestion, database storage or production telemetry activation.

Focused checks passed in the assigned slot:

- `android_prepared_cast_check.tscn`: five paths, hit/miss/no-impact outcomes,
  120 fresh-versus-prepared geometry/material snapshots, changed action timing,
  side and raised positions, one-time handoff, unsupported-family fallback,
  natural completion, deactivation of unused nodes and cancellation during preparation.
- `android_move_warmup_check.tscn`: existing gated legacy helper, bounded
  retention, no actor/camera actions, reuse and cancellation cleanup.
- `battle_move_effects_3d_check.tscn`: 24 moves across four slots, outcome,
  audio, impact, replacement, cancellation and optional-audio contracts.
- `fullscreen_battle_fade_check.gd`: loading/fade and world handoff checks.
  Its temporary drawing-lock assertion passed before that unused experiment
  was removed; the final host and test are unchanged from the task base.
- 31 focused Python quality/GPU harness tests, including wrong/missing prepared
  instance rejection, missing active/draw evidence, incomplete preparation,
  nonfinite timings, and preservation of slow complete timing evidence.
- Private phone script parse and native APK export.

All four hidden-run impact images and the covered-run Rock Slide/Draco Meteor
images were visually inspected. These images come from the separate unmeasured
evidence pass, not readbacks during the prepared timed casts. Timed casts have
their own active/render-visible geometry and impact checks. The desktop reset
test supplies the direct fresh-versus-prepared state comparison.

Device: SM-S938B / S25 Ultra, Adreno 830, Android API 37, game 0.3.110. Battery
sensor **25.3→27.3 °C** off, **27.6→29.1 °C** hidden, **29.0→30.3 °C** covered.
All runs were full 100%, status 5, USB powered, AC false, power saving off;
native and host thermal statuses stayed 0. Run order, retained caches and
different starting temperature are uncontrolled. Clocks, room temperature,
brightness and background load were not fixed. Main-thread timers include
waits, and debug/instrumentation/host-health queries can affect measurements.
There are no fleet-wide percentages, energy or sustained-thermal claims.

Retained locally in this slot's ignored `.tmp/android-quality-phone/`:
`first-cast-off-1/`, `first-cast-hidden-1/`, `first-cast-covered-1/` each contain
raw report/details/telemetry and nine images. `first-cast-comparison.json` derives
per-window metrics. `first-cast-export-1/` contains the one APK and build logs,
exported from clean **836e28143053bfa8beffc4a427a32d918c9a4e4b**; SHA-256
**aabd9ecb5c5f7f50ca011c3463827d0b5c9fb33f693e87ce8a852e7b366ced26**.
All host launches recorded that same clean source commit. The later entry-mode
selection and completed-node guard were checked locally; no new APK measurement
is attributed to those follow-up changes.

Reproduce using the assigned slot's USB quality runner with a fresh output
folder and `--mode gameplay --profile-hitches`, then separately add
`--first-cast-preparation hidden` or `--first-cast-preparation covered`.
The private process and owned USB reverse were cleaned up after every run.
The ordinary game/account data was untouched.

Before considering automatic activation, test the normal battle host with real
available-move data, covered and early-visible entry, team preview, missing or
changed leads, disconnect/cancellation and release-build timing. Keep bounded
first-use effects and loader cost visible in that evaluation. This fixture does
not authenticate or execute ordinary world/network battles, and only the five
reviewed paths can consume a prepared node. No release certification, main
promotion, publishing, deployment or production activation was performed.
