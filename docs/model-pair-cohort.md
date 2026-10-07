# Shared-texture cohort — 2026-10-07

Follow-up to [the three-pair prototype](model-pair-textures.md). This is research
tooling and local debug evidence; production assets, installer and Android's
2D presentation policy are unchanged.

## Size result

Sixteen pairs cover small/common species, large actors, fire/water effects,
Mega forms and Galar birds. Ten pairs were freshly derived from hash-pinned
approved ZIPs on the external drive; six used previously retained sources in
this same slot. Every original/decoded hash is bound to the current v11 release.
No raw dump was reconverted, source edited or checkout cache copied.

| Pair | Current v11 control PCK | Shared PCK | Saving versus v11 | Sharing at equal codec |
| --- | ---: | ---: | ---: | ---: |
| Pikachu | 16,215,660 | 11,485,784 | 29.17% | 29.17% |
| Garchomp | 14,987,756 | 11,533,928 | 23.04% | 23.04% |
| Azumarill | 19,533,452 | 16,981,288 | 13.07% | 13.07% |
| Charizard | 16,820,428 | 12,966,336 | 22.91% | 22.91% |
| Arcanine | 15,184,844 | 10,583,392 | 30.30% | 30.30% |
| Magnemite | 3,619,884 | 2,907,052 | 19.69% | 19.69% |
| Palkia | 35,362,572 | 21,088,808 | 40.36% | 40.36% |
| Dondozo | 12,615,532 | 10,986,856 | 12.91% | 12.91% |
| Mega Dragonite | 67,184,748 | 7,306,004 | 89.13% | 19.07% |
| Darmanitan Standard | 1,323,276 | 1,189,724 | 10.09% | 10.09% |
| Mega Diancie | 9,725,068 | 8,535,952 | 12.23% | 12.23% |
| Mega Greninja | 6,454,604 | 5,245,456 | 18.73% | 18.73% |
| Mega Zygarde | 8,692,556 | 7,626,988 | 12.26% | 12.26% |
| Mega Golisopod | 9,045,356 | 7,587,764 | 16.11% | 16.11% |
| Articuno Galar | 15,318,380 | 13,115,636 | 14.38% | 14.38% |
| Moltres Galar | 16,501,804 | 13,893,364 | 15.81% | 15.81% |

All sizes are actual complete PCK bytes, including member tables and manifests.
Combined: **268,585,920 → 163,034,332 bytes**, saving **105,551,588 / 39.30%**.
The equal-codec controls total 210,429,184 bytes, so sharing alone saves
**47,394,852 / 22.52%**. Controls and candidates use v11 Zstd level 9/262,144-byte
blocks, except the current-v11 control deliberately preserves its exact
approved bytes.

Mega Dragonite is an outlier: v11 retained its original uncompressed RSRC files.
Its equal-codec, self-contained control is 9,027,644 bytes. Its 89% total result
therefore includes a large **codec** gain; sharing alone is 19%. The codec control
is decoded byte-for-byte against the original. It is a size control, not a third
native loader case. Other control-container differences of a few bytes come
from the longer `codec-control` namespace/manifest. No sample extrapolation is
made to the whole collection. The existing v11 binding has four unchanged
appearances (Mega Dragonite and Toucannon pairs); this is not evidence that all
1,200 pairs still have similarly large uncompressed savings.

## Quality qualification

CPU semantic graphs before/after sharing are exact, including complete image
dimensions/formats/mips/pixels, mesh buffers, animations, effects and independent
materials. Baseline scenes are byte-exact to current approved v11 hashes.

**320/320 captures are byte-exact against the first original capture**, with no
pixel tolerance: 32 appearances × front/back × idle, physical/special attack,
sleep and faint. An independently reloaded original control is also retained.
The production material presenter is used, schema-1 clone poses synchronize,
and scene weak references expire after each presentation. A source-derived
camera covering all sampled motion is reused unchanged for candidate/control,
so wide actors such as Dondozo remain visible. The contact sheet was inspected.
Host: Godot 4.6.2 Mobile Vulkan, NVIDIA RTX 3070 Laptop.

The first render run failed because Darmanitan's legacy source lacks
`faint_loop`. The corrected diagnostic samples the end of its existing
`faint_start`, matching the presenter's retained final pose. No source animation
or gameplay code was changed. The first run is retained as failed evidence.

The first Android run exposed a cross-renderer shader default, including in the
unchanged original Charizard. A property-level trace established that the only
hash-changing field is `shader_parameter/review_time`: dummy returns null;
Mobile Vulkan exposes the shader's declared **-1.0**. Shader code hashes and all
other property hashes match. Normal/shiny candidates have exactly the same
complete native semantic digests as their original controls.

The loader check therefore retains the strict headless golden digest **and**
compares every candidate's full native graph against the hash-pinned original
loaded on the same runtime. No property is excluded, normalized or tolerated.
This separates engine default exposure from changes to authored model data.
The targeted failing trace is retained rather than relabeled as a successful
old check.

## Native Android result

All **32 baseline/shared cases** pass on the dedicated debug package
`com.pokeaether.androidmodelpairs`, Android 13 x86_64/software llvmpipe,
Godot 4.6.2 Mobile Vulkan. Full pinned PCK download/install, manifest/member
hashes, dependency closure, threaded load, exact original/candidate resource
graphs and post-load hashes pass. All 32 cases finish with **zero texture weak
references**, and shiny remains valid after normal leaves. There are no native
script/engine errors. The collector verifies a fresh run ID and the exact
species/variant set; the owned emulator was closed after collection.

Candidates share 1–18 actual texture object IDs between appearances; controls
share none. Settled native texture-counter differences range from 1.00 MiB
(Darmanitan) to 78.18 MiB (Palkia), with both variants simultaneously loaded.
These are engine-counter observations on this emulator, not physical phone
RAM/VRAM or per-encounter savings. Peak guest PSS was 565,539 KiB for the whole
debug run, including its app/engine; it is not a production memory budget.
The 32 loaded control/candidate packs contain 427 file-table entries; mounted
index memory growth was not separately measured.

The host headless loader independently passes all 32 cases and their CPU golden
digests. Negative contract fixtures reject traversal, duplicate/missing files,
corruption, altered manifests and escaping dependencies. Existing texture
regressions preserve alpha/mips/dimensions/name/metadata/local ownership.
No complete release gate, physical phone test, upload or release was performed.

## Installation work

See [the proposed installation contract](model-pair-installation-design.md).
Both launcher ZIP installation and game on-demand installation need a new
explicit format, full PCK table/closure validation, virtual/physical catalog
identity, dependency-aware two-entry LRU accounting and update/cleanup lifetime
rules. Mounted packs cannot generally be unmounted; weak texture release does
not establish zero file-table overhead. No production gate was loosened here.

Diagnostic exporters and render probes now serialize their temporary project
edits using an exclusive lock. Both refuse a concurrent writer without changing
project/preset bytes. The pair exporter also checks its generated runner and
avoids unrelated sprite-service globals. These guard the experiment's temporary
configuration; they do not change a player's build.

## Reproduce

Use `ops/worktrees/slot-env` for every invocation. `prepare_model_pair_cohort.py`
accepts an archive root, optional retained-input manifest and explicit species;
it derives fresh input scenes only under the assigned slot's `.tmp`. It fails
on missing/mismatched sources and preserves v11's unchanged RSRC baselines.
Then run pair generation and packaging as in the original prototype.
Packaging now includes a separate `codec-control` size fixture.

`model_pair_bundle_check.gd` and `run_android_model_pairs.py` accept a nonempty
cohort and require exactly twice its pair count. The Android collector also
checks the exact species/variant set, fresh run ID, debug package and renderer.
`compare_model_pair_renders.py --render <owned-render-directory>` checks every
PNG's raw pixel hash and all candidate frames against original controls.
Larger render/generation runs can use an explicit bounded `--timeout`.

Owned artifacts: `.tmp/model-pair-cohort/sources-v3/`, `generate-v1/`,
`packages-v1/`, `render-v2/`, `load-v2/`, `apk-v5/`, `native-v3/` and
`shader-default-diagnosis.json`. Earlier failed attempts remain separate.
The tracked `model_pair_cohort_results.json` pins successful receipts and packs.
