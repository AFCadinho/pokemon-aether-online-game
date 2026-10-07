# Physical Galaxy Tab A7 diagnostic — 2026-10-07

This extends [the lossless shared-texture cohort](model-pair-cohort.md) and
[the emulator presentation budget](android-battle-budget.md). The separate,
ARM64 debug package is `com.pokeaether.androidtabbenchmark`, displayed as
**PokeAether 3D Tablet Test**. Production Android remains 2D. No production
application, asset index, model source, arena pack or release was changed.

## Device and interpretation

Samsung SM-T500, Android 12, Adreno 610, Vulkan 1.1.128, approximately 3 GB RAM.
The vendor Vulkan driver reports build date 2021-10-08. The tablet is connected
and charging over USB. These conditions and background system activity belong
to this measurement; one tablet does not qualify other Android GPUs or phones.

The complete **16-pair / 32-case model-only qualification passed** on the
physical tablet, including both appearances in every case. Original/candidate
native semantic graphs match exactly; all 32 cases finish with zero texture
weak references and no engine/script errors. Candidate cases share 1–18 real
texture object IDs. Settled texture-counter savings with both appearances
loaded range from **1.01 to 79.30 MiB**; these are Godot counters, not per-battle
process RAM savings. Sampled peak process PSS was **534.27 MiB**, maximum
battery temperature 32.5°C and maximum reported thermal status 0. Twelve packs
were reused after full hash verification; twenty streamed packs transferred
210,836,632 bytes over the diagnostic USB fixture service.

The earlier 320 exact host captures still establish visual equivalence for the
cohort. This physical model-only run did not produce arena frames, pixel
comparisons or a sustained performance/thermal approval. It does not adopt the
shared PCK format in production. Portable results and artifact hashes are in
`tools/sprite_factory/android_tab_a7_results.json`.

The complete forest workload has **not passed** on this device. The original
Mobile/Vulkan setup failed while building/rendering its arena pool, before a
timed actor observation. The native log reports an Adreno command submission
deadlock, lost Vulkan device, and fatal signal on the Vulkan thread. This is
not an FPS result or proof that reducing model files fixes the arena.

The smoke isolation with MSAA disabled also lost the Vulkan device at the
forest-pool stage. Thus MSAA alone does not explain the failure. The original
and isolation failures remain distinct evidence; the latter is not a pass for
the original appearance. A GPU/renderer compatibility cause is a hypothesis,
not an established faulty shader or out-of-memory diagnosis.

With only `SharedForestGrass` hidden, the same 4× MSAA/two-pass setup completed
all **13 smoke phases** and produced actual 3D actor/effect captures. Observed
time was 143.81 seconds; average FPS per phase was **1.79–1.84**, with p95 frame
times **548–732 ms**. Sampled peak process PSS was 645.47 MiB, battery temperature
33°C and reported thermal status 0. The preceding six pinned model checks
reused all six cached packs with zero model downloads. This is a successful
isolation/compatibility smoke run with **unacceptable interactive speed**, not
a performance pass or a complete forest-quality approval.

This implicates the grass rendering path under this device/configuration, but
does not distinguish its shader, instance count, driver interaction or combined
load. Hiding grass is an isolation experiment, not the proposed player fix.
The original grass/4× MSAA control was repeated with the same APK immediately
after the successful grass-hidden run. It again lost the Vulkan device at
`forest-pool`, with zero observed actor phases. This same-binary control removes
the earlier collector/export differences from the isolation comparison.
The complete 20-minute run was not started after the original workload crashed;
the short altered workload cannot substitute for it. First isolate/repair the
grass issue and profile arena/presenter frame costs, then repeat the original
quality workload before enabling Android 3D or publishing Android asset packs.

[Godot's renderer guidance](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html)
recommends Compatibility for older mobile devices. A different renderer would
require a separately labeled trial and visual review, rather than relabeling
this failed Mobile run or changing the model quality checks.

## Qualification and workload

The model qualification uses the existing 16-pair receipt's exact PCK pins.
It checks complete file tables, dependency closure, original/candidate native
semantic digests, actual shared texture objects, independent shiny lifetime
and zero remaining texture weak references after each case. Authored images,
meshes, animation data and materials are unchanged. No native hash exception
is added for the physical GPU.

Tablet-only downloads stream to a partial file, verify length and SHA-256,
then rename and mount. Exact hash-addressed files are reused on later runs.
Transport failures can retry three times; HTTP/content/hash failures do not
become successful retries. This diagnostic USB delivery is not a CDN speed or
production installer benchmark. The succeeding model check retains its exact
fixture for the presenter instead of fetching a second potentially different
fixture. Fresh run IDs bind all collected reports.

The normal timed suite retains the actual production presenter and environment
pool, both main/irradiance passes at **960 × 540**, 4× MSAA, lights, shadows,
terrain, plants and wind. It observes original and candidate, normal and shiny,
with order alternating by species. Twenty-second phases include physical and
special attacks, a real Flamethrower effect, sleep/wake and faint. The diagnostic
also calls the anticipated-form preload/reveal API with an arbitrary candidate;
it does not test gameplay rules for legal Mega transformations.

The candidate-only bridge admits resources only after the preceding complete
qualification and exact per-scene hash/length checks. Placement/motion come
from the checked-in original's reviewed hash, then bind to the verified
candidate. Both original/candidate arms disable the prepared-model LRU. This
does not implement production admission, dependency-aware LRU accounting or
the new installer format.

The collector samples process PSS/RSS, battery temperature, Android thermal
status, foreground and screen state. Sustained acceptance requires at least
20 minutes of measured phases, the expected phase and model sets, a fresh
completed report, no errors, one dedicated foreground app process and an awake
screen. FPS has no hidden pass threshold: average, p50/p95/max frame duration,
long frames and preparation time are reported for interpretation. Smoke runs
and model-only runs explicitly cannot qualify sustained rendering.

This is a presentation workload, not a complete network battle, HUD/input test,
visual approval or final Android release gate. It preserves ordinary physical
frame pacing and shader disk caching. No emulator workaround is used.

## Reproduction

Run every command through the assigned `ops/worktrees/slot-env`. Export with:

```sh
python3 tools/export_battle_entry_web_qa.py \
  --suite android-tab-benchmark --platform android --architecture arm64-v8a \
  --android-renderer mobile --sdk /path/to/Android/Sdk --output .tmp/tablet-apk
```

`tools/run_android_tab_benchmark.py` requires an explicitly selected physical
Tab A7 serial, the same slot's audited cohort fixture directory, the pinned
ETC2 arena PCK, the separate APK and a fresh owned output directory. It serves
only whitelisted fixture files over its own USB reverse port. It installs and
stops only its dedicated debug package, and leaves its verified cache installed.
It never transfers normal-player userdata or clears system/shader caches.

Use `--smoke --phase-seconds 10` for Garchomp, Charizard and Mega Dragonite;
`--models-only` checks the full 16-pair set without building the arena. Isolation
flags `--disable-msaa` and `--disable-grass` require smoke mode and cannot
qualify the original sustained workload. The tablet must remain unlocked with
the test app visible. The app holds the screen on once running.

Owned evidence is under `.tmp/tab-a7-benchmark/`. Failed attempts (including
USB authorization, sleep, transport and collector failures) remain available
and are not counted as passing render measurements.
