# Desktop 3D battle quality — 2026-10-15

Desktop now offers Low, Medium, High and Ultra for the 3D battlefield, with an
independent frame limit. The first-attack preparation implementation is shared
with Android, behind a separate default-off desktop trial gate.

## Profile behavior

| Desktop profile | Arena resolution | MSAA | Shadows |
| --- | --- | --- | --- |
| Low | 50% per dimension | Off | Off |
| Medium | 75% per dimension | 2× | Authored |
| High | Native arena size | 2× | Authored |
| Ultra | Native arena size | 4× | Authored |

The actual arena/window transform determines native size. Both the main and
material-response passes use the selected budget. UI and 2D sprites retain their
normal raster. These are rendering budgets, not texture/model simplification or
hardware ranks. Android retains its existing short-edge budgets and preferences.

Desktop quality and FPS are saved independently from Android. A quality change
discards an idle pool, or marks a borrowed pool for disposal after its current
battle. The current stage retains its captured profile. Frame limits apply
immediately and offer 30, 60, 120 and Unlimited; Unlimited remains subject to
VSync. Defaults remain Ultra and the previous uncapped desktop engine setting.
The titles and Unlimited explanation are localized in en/nl/pt_BR/zh_CN.

Wild, trainer and player PvP hooks use shared preparation methods. Compatibility
wrappers retain the existing Android diagnostic API. Desktop preparation needs
the explicit desktop_3d_move_warmup feature and Forward+ or Mobile; it remains
off in normal builds. The same five reviewed effects, single-use ownership,
cooperative 1,500 ms deadline, hidden samples, request/generation idempotence and
cancellation guards apply. No automatic quality assignment or telemetry upload
for desktop was added.

## Matched native profile matrix

All twelve profile windows passed. At the fixed 60 FPS cap, averages are nearly
identical on this machine; this does not imply identical GPU cost or establish
headroom at higher resolutions/frame limits.

| Profile | Both passes | FPS range, 3 runs | Frame p95 range ms | Frame p99 range ms | Largest interval ms |
| --- | --- | --- | --- | --- | --- |
| Low | 800×450 | 59.94–60.00 | 16.71–16.76 | 16.84–17.77 | 48.75 |
| Medium | 1200×675 | 59.94–60.00 | 16.75–16.79 | 16.86–18.14 | 49.88 |
| High | 1600×900 | 60.00 | 16.71–16.75 | 16.78–16.85 | 29.06 |
| Ultra | 1600×900 | 59.94–60.00 | 16.71–16.75 | 16.79–17.74 | 49.15 |

Rare first-use intervals remain despite good averages. High never starts a
fresh process in these three fixed orders; its smaller maximum is not proof
that High is intrinsically cheaper than Low. GPU clocks also vary: main-pass
GPU p95 ranges are 1.61–1.65 ms Low, 2.53–2.57 Medium, 2.03–2.51 High and
2.12–2.24 Ultra. These are lagged per-pass timings under changing clocks,
not a controlled measure of energy or a universal cost ranking.

Three fresh processes each ran the same four profiles, in these fixed orders:
Low/Medium/High/Ultra, Ultra/High/Medium/Low, Medium/Low/Ultra/High. Each profile
reconstructed the real battle host and scene, entered the covered wild intro,
then measured 30 seconds. Every window used Flamethrower, Thunderbolt, Rock Slide
and Draco Meteor through the ordinary preloaded router, with real animation,
visible effects, audio, impact, recovery and cleanup. The retained battle-host
settings menu visited all eight tabs. These whole-window averages include idle
and menu rendering and must not be presented as attack-only FPS.

All accepted measurements use a 1600×900 native window, a 60 FPS cap with VSync
disabled only in the fixture, the same pinned v16 Charizard/Dragonite models and
forest art, fixed noon/wind/camera, Linux/X11 Forward+/Vulkan and the same production quality/preparation code. Each profile has three observations; p95/p99 ranges describe individual
windows, not pooled percentiles. Render memory and process PSS include retained
caches. Their history/order dependence remains visible in the raw results.

## Preparation comparison

The final fixed order was **on A, off, on B**, each in a fresh process with the
same clean fixture/source. Both on runs passed without engine/check errors,
including unused-effect retirement and final cleanup. First Rock Slide's maximum
interval was **56.37 ms off, 17.42 ms on A and 17.69 ms on B**. The five-effect
preparation costs **831–862 ms** per intro in these two on runs.

| Scenario | Readiness off / A / B ms | Effect preparation A / B ms | Rock Slide maximum off / A / B ms |
| --- | --- | --- | --- |
| Covered wild | 2317 / 3205 / 3173 | 862 / 849 | 56.37 / 17.42 / 17.69 |
| Early-visible wild | 1817 / 2631 / 2665 | 833 / 833 | 18.93 / 17.55 / 18.09 |
| Trainer, changed lead | 9238 / 7128 / 7140 | 831 / 832 | 17.51 / 17.48 / 25.99 |

Total readiness also includes unrelated asynchronous lead/model/intro work;
the baseline trainer total is longer despite having no effect preparation.
Use the separately measured warmup cost, rather than subtracting entry totals,
to estimate this added work. No total-loading-speedup claim is made.

| First process window | Off maximum ms | On A maximum ms | On B maximum ms |
| --- | --- | --- | --- |
| Flamethrower | 26.35 | 17.56 | 18.40 |
| Thunderbolt | 17.79 | 18.08 | 18.11 |
| Rock Slide | 56.37 | 17.42 | 17.69 |
| Draco Meteor | 50.05 | 18.62 | 18.84 |

Whole-window FPS is 59.92–60.00 off and 59.99–60.00 on. This primarily reduces
first-use stalls, not average capped FPS. Thunderbolt did not become faster,
and a later prepared Rock Slide still reached 25.99 ms. Automatic preparation
remains off; the extra roughly 0.85 seconds is a real tradeoff.

Three fresh processes, on/off/on, measure the covered wild, early-visible wild
and trainer Team Preview paths. Slot 2 is selected through the ordinary party
signal, changing the lead to Dragonite before the active move request arrives.
The fixture verifies actual move IDs, ready/input/hidden-sample conditions,
preview behavior and exact prepared-node handoff to each measured cast.

Entry duration ends at first-turn readiness. UI and effect PNG readbacks are
outside the measured windows. The four impact images are a separate evidence
pass, not captures of the timed prepared instances. Timed instances have their
own visibility/impact/cleanup and identity evidence. Cached shader/driver and
filesystem state is retained: fresh process does not mean an empty cache.

## Ten-minute Ultra run

The run completed **600.22 measured seconds**, all twenty windows on the same
stage, without engine/check errors. FPS stayed **59.95–60.06**, frame p95
**16.71–16.81 ms**, with a largest interval of **48.82 ms**. Reported render
memory stayed exactly **1025.40 MiB** at every window end.

The first host PSS sample in windows 0 / 1 / 19 was
**2220.3 / 2245.4 / 2249.8 MiB**. Most observed growth was early; this is
consistent with bounded warming in this session and is not a leak-freedom
proof. These host samples occur up to five seconds into their marked windows;
health logging also covers untimed preparation, captures and cleanup.

Twenty consecutive 30-second windows retain one battle/stage and repeat the same
four-cast/eight-tab workload. New preparation or stage recreation is forbidden.
The first and final windows have separate ordinary UI captures. This checks a
bounded ten-minute session, not indefinite leak freedom or sustained behavior on
other machines.

## Verification and fixture boundaries

Focused checks passed in slot A:

- desktop_battle_quality_check.gd: saved UI choices, independent Android
  preferences, native/relative/portrait/4K sizing, malformed frame-limit fallback,
  both render passes, Low shadows, retained borrowed arena and next-battle swap.
- desktop_battle_entry_preparation_check.gd: ordinary covered/early/trainer and
  late-request entry, changed shiny lead, one-time handoff/idempotence and both
  host-owned/post-host cancellation paths with desktop gates. It reuses the
  Android integration assertions and generated local sphere model fixtures;
  it is not a real-art/performance check.
- Android quality/performance, Android entry preparation, platform support and
  fullscreen battle fade/world-handoff regressions passed.
- 40 focused Python Android/GPU/desktop harness tests passed, including rejection
  of the wrong GPU/renderer, incorrect pass dimensions, incomplete work, missing
  visible host menu, nonfinite frame/GPU timings, wrong prepared instances and
  a recreated or truncated soak.

The seven selected native runs passed the current result validator with clean
launch provenance, no engine/check errors and all required images. They contain
**41 timed windows / 1230.51 seconds / 164 real casts**: 12 profile windows,
9 entry-control windows and 20 soak windows. The two prepared entry processes
verified 24 exact first-use instance handoffs. Each window completed all eight
visible tabs in the host-owned menu. Every window ended focused; focus was not
continuously audited.

Low and Ultra ordinary entry images, both reviewed graphics-menu captures,
the final soak battle, the changed-lead trainer UI and all four final on-run
impact images were visually inspected. The final images show the actual
settings overlay above the battle, crisp HUD, the chosen lead and visible
effects. Existing invalid imported-texture UID path-fallback warnings remain
in logs; accepted runs have no script/engine errors.

The initial smoke fixture wrote an object instead of the runtime catalog array,
causing a 2D fallback and an invalid viewport access. The corrected array passes
the normal model pack inspectors, with an explicit active-3D readiness guard. Later visual
review caught a root-mounted menu behind the fullscreen battle: profiles-1/2
and the interrupted profiles-3 plus old smoke captures are excluded by explicit
review notes. Corrected runs use the actual retained host menu and its overlay,
not just a Control.visible check. No rejected windows are stitched into the
accepted matrix. The final visible host-menu smoke was inspected before reruns.
Two initial intro comparisons stopped at the early arena. The local catalog
had been marked as manually selected, bypassing the host's normal
pending-response gate. A two-render-frame observation wait alone did not fix
that. The fixture now uses the launcher-managed catalog route and retains the
post-entry observation wait outside recorded entry/action durations.

Two subsequent warmup-enabled runs each logged eight native Forward+ material-null
errors around the third, trainer scenario; both full runs are rejected,
including their earlier complete windows. Waiting only after immediate
host/world free did not resolve this. A sprite-material lifetime probe and a
single fresh trainer trial did not reproduce it, so no speculative production
material change was made.

The fixture was immediately freeing the world while cancelled unused prepared
effects still awaited queue_free(). It now calls host.release(), drains queued
child deletion through two rendered frames, then frees the owner, and keeps
logging active through final cleanup. This boundary also runs before the next
arena is allocated. The normal world queues host deletion after release; the corrected fixture
also lets queued effect cancellation finish first. Both full final warmup runs
passed. The final comparison uses that fixture and repeats the warmup condition. These observations do not certify every engine/driver or
unused-effect cancellation path; automatic desktop preparation remains off.

Lead/API data is local. The fixture replaces the on-demand model boundary with
locally pinned, inspected public packs; the real presenter still validates and
loads their entries. The forest archive and extracted art pack match compiled
hash/size pins. Account-only decoration and damage-calculator prefetch are
excluded by the shared offline entry fixture. No authentication, game commands,
production service, server-side storage or desktop diagnostics upload is used.

## Hardware, evidence and limits

AMD Ryzen 7 5800H, NVIDIA GeForce RTX 3070 Laptop GPU (8 GiB), driver 610.57.04,
Godot 4.6.2-stable, Manjaro Linux kernel 6.18.49-1-MANJARO, X11. The renderer
reported the NVIDIA adapter in every accepted process; the integrated Radeon
was not substituted. The fixture records GPU temperature, utilization, driver
memory, power and clocks plus per-process PSS every five seconds. GPU telemetry
is system-level and can include other processes. It is not an energy benchmark.

GPU temperature over complete process health logs ranged 37–52 °C / 42–53 °C /
41–51 °C for the profile processes, 36–58 °C for the soak and 37–43 °C /
40–44 °C / 41–44 °C for the final on/off/on control. Health logs include
startup, measured windows, untimed captures and cleanup. CSV GPU fields are
adapter, temperature °C, utilization %, driver memory MiB, power W, SM clock
MHz and memory clock MHz. Their readings can lag and are not attack-only costs.

This is an editor/debug Linux/NVIDIA test, not an exported release measurement,
a weaker-PC result or certification of Windows/macOS/Compatibility/Mobile.
Clocks, temperature and background activity were not fixed; process order was
fixed rather than randomized.
No causal universal FPS gain, automatic tier assignment, 4K performance claim,
energy saving or authenticated-world/PvP claim follows from this one machine.

Evidence remains in this slot's ignored .tmp/desktop-battle-quality/: raw
report/details/fixture JSON, phase markers, stdout/engine logs and PNGs for each
accepted process. details includes the complete measured rows and exact move
instance IDs; report records clean source provenance and hardware health.
comparison.json derives only the accepted runs. Rejected trials retain their
original logs/results and separate review.json notes. Development smokes are
not included in performance tables.

Production quality/preparation code is from `1efb4f511b39b8321e86472c85c24551437cf00a`.
The selected profile matrix was launched from clean
`aac2beea192c82d7ff987cae52f8d688ee88bb3e`, the soak from clean
`b7a2eb21d349bd21e17b477406a2dc285c226ae9`, and all three final entry controls
from clean `5343e75d14e0ce32d9b6f02bd5644a8da265967b`. The intervening commits
change only the benchmark's entry/catalog/retirement observation boundaries;
the production profile code and measured four-cast/eight-tab workload are
unchanged. The matrix and soak do not claim measurements of the later fixture
cleanup change. Final entry controls use identical code apart from the
explicit process-local warmup feature.

The selected folders are `profiles-v2-1/`, `profiles-v2-2/`, `profiles-v2-3/`,
`soak-ultra-1/`, `entry-on-3/`, `entry-off-5/` and `entry-on-4/`. Earlier complete
off controls are retained as exploratory baselines; the matched final table
uses only `entry-off-5/`. Failed or superseded folders remain excluded from the
derived comparison.

Reproduce from the assigned frontend slot through its slot-env:

```bash
python3 -m tools.run_desktop_battle_benchmark --mode profiles --repeat 0 --output .tmp/NEW
```

Use repeats 1 and 2, then --mode entry with and without --warmup, and --mode soak.
Each output must be fresh. The visible benchmark harness currently requires
Linux, an NVIDIA adapter and nvidia-smi; the in-game controls are not tied to that
harness. Run one Godot benchmark at a time. Godot stays in the slot's isolated
userdata/cache/configuration, and each normal completion restores its saved
settings file. The normal game/account data is untouched. No complete paired
certification, main promotion, publishing, deployment or production activation
was performed.
