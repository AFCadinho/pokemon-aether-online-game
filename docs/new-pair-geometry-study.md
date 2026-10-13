# Geometry-sharing study of the 220 new v14 pairs

This is an offline investigation of the 220 pairs added in model release v14.
Their approved complete archives total 1,334,349,732 bytes within the current
8,993,498,070-byte collection. Every input is read in place and checked against
the published v14 SHA-256, length, pack manifest and member checksums. No
production catalog, profile, index, R2 object or player installation changes.

## Structural qualification

All 220 pairs are inventoried using the existing strict geometry audit.
Hierarchy, authored transforms, skeleton properties, mesh/skin bindings and
animation-library bindings must agree exactly between normal and shiny.
Materials retain their appearance-specific values. Resource names are not
relaxed to force a match. Scene-local or externally dependent components are
not admitted. Mesh/material/method animation tracks retain their existing guard.

**111 pairs qualify for the existing geometry-sharing producer. 109 are held.**
All 109 have sensitive animation tracks; four also contain scene-local or
externally dependent components. The counts overlap. Examples include
Landorus Therian, Rapid Strike Urshifu and Zygarde 10%, whose eye/body UV tracks
address `surface_material_override` properties. Such paths may eventually be
supportable, but this study does not reinterpret or bypass that guard.

Of the 109 held pairs, **98 have only UV scale/offset tracks** on per-instance
surface material overrides. The remaining 11 also animate textures, effect
phase, emission or colour: Sandy/Trash Burmy and Wormadam, Dawn Wings/Dusk Mane
Necrozma, the four Ogerpon Tera masks and Zygarde 10%. The four component holds
are the Sandy/Trash Burmy and Wormadam pairs. This classification identifies
future investigations; it does not qualify any of those 109 for conversion.

The same audit derives standalone component sizes at the historical Zstd level
9 setting. Those diagnostic sizes are not the final saving. The complete-pack
measurement below compares the real v14 input with fully assembled schema-2
PCKs using **Zstd level 19 / 256 KiB**, matching the current compression setting.

## Complete-pack experiment

The producer reuses the established scene/material, pose and ownership checks.
Normal and shiny retain separate scene actors, materials, skeleton nodes and
AnimationPlayers. Strictly matching meshes, Skins and AnimationLibraries become
shared leaf resources. Images, mipmaps, UVs, vertices, normals, weights,
blendshapes, animation keys and timing are not downscaled or quantized.

Each candidate is saved under a fresh private resource namespace and incremented
immutable version. Every recompressed decoded native member remains byte-exact
with its derived standalone input. The persisted complete archive is reopened
and independently checked. It must stay within the current 127-native-member
and namespace/dependency budgets. Source-profile/cache-floor bindings are retained.

Actual native actors use Linux Godot 4.6.2 with **Compatibility/OpenGL**. This
does not rely on Dummy/headless actor instantiation. After assembling each pack,
a separate process installs it through the production pack validator, loads both
appearances cold, compares their complete effective geometry/material state and
all authored clips at 0%, 50% and 99.9%, including RESET. It verifies shared
resource identity, separate skeletons, independent pose/animation state and
survival of shiny after normal retires. Only strictly smaller successful complete
packs contribute to savings; held and non-smaller pairs retain their originals.

The first Alcremie Caramel Swirl control saves **1,754,376 bytes**. Its normal and
shiny original/repeated-original/candidate GPU controls pass **20 pixel-exact
candidate frames**. The pilot build is explicitly incomplete for the whole
cohort and does not establish a catalog-wide saving.

The completed run builds **all 111 eligible pairs**, and **all 111 are smaller**.
Cold native installation/effective-state checks and **5,274 sampled animation
states** pass. All **2,537 derived native members** survive exact decoded-byte
compression comparisons and complete persisted-container checks. No candidate
exceeds the member budget; the largest has 44 native members.

| Scope | Current complete archives | Selected complete archives | Saving |
| --- | ---: | ---: | ---: |
| 111 eligible pairs | 615,841,324 B | 417,669,392 B | 198,171,932 B / 32.18% |
| Complete 1,420-pair collection | 8,993,498,070 B | 8,795,326,138 B | 198,171,932 B / 2.20% |

This is **8.99 GB → 8.80 GB**, using actual complete candidate packs and retaining
every other v14 archive. It is not an extrapolation or the separate cross-form
303 MB opportunity. It is selected download archive size, not billed R2 storage,
filesystem allocation, update headroom or a runtime RAM/VRAM estimate.

## GPU controls and limits

`new_pair_geometry_render.gd` uses the existing raw-model review stage and native
material response. For each selected appearance it captures front/back idle,
physical attack, special attack, sleep and faint poses at 512×512/MSAA4. Camera
framing comes from the source and is reused for both controls and the candidate.
Each candidate must equal a complete original or repeated-original frame,
using the existing `qualify_shared_model_catalog.compare` acceptance rule.
Pixelwise mixing of controls and numeric pixel tolerances are not allowed.
Python independently reopens every PNG and verifies its dimensions, data hash
and decoded pixel equality.

Two host-audio startup failures stalled the first resumed run before native
validation. Those attempts remain unqualified; the failed packs were rebuilt
and passed with `geometry_godot_no_audio.sh`, which disables only host audio
while preserving real Compatibility rendering. The first full GPU run also
rejected unstable repeated-source Gourgeist frames. The v2 renderer applies the
existing catalog renderer's review-time control to every shader declaring
`review_time`, including older fire shaders without effect-schema metadata.
Original/candidate model bytes and the frozen successful build recipe remain
unchanged. The wrapper's explicit `POKEAETHER_GEOMETRY_CLOCK_V2=1` selects that
diagnostic renderer; its source SHA-256 is bound in the raw render report and
the committed receipt. Clock control alone did not remove Gourgeist's source
variation: material inspection found standard materials and two differing pixels
in a repeated faint frame, while the candidate equalled the first source exactly.
The final run uses the established whole-frame original-or-repeat rule rather
than requiring both original runs themselves to be identical.

The final four-pair/eight-appearance GPU run passes **80 exact candidate frames**
for Unown Exclamation, Masterpiece Sinistcha, Large Gourgeist and Artisan
Poltchageist. Two repeated-source frames differ; every candidate still matches
one complete reference frame exactly. All 240 original/repeated/candidate PNGs
are independently decoded and hash-checked by
`tools/check_new_pair_geometry_pixels.py`. Four focused verifier tests include
rejecting a pixelwise mixture matching neither complete control frame. Neither
failed stricter source-repeat run counts as qualification.

This is a focused raw-model GPU comparison, not compiled runtime profile
activation, complete battle/presenter integration, every animation time, native
Windows/macOS testing or physical Android performance certification. Publishing
requires new pinned client catalogs and the normal release/installation checks.
The current live collection remains 8.99 GB until a separately authorized rollout.

## Reproduction and retained evidence

Use the assigned slot and retained v14 source map. Inputs are frozen by SHA-256.
The diagnostic project lock temporarily omits this slot's autoloads/plugins and
restores the exact project file in `finally`; no other checkout is altered.
Each native process owns its local logs and derived resources. Build checkpoints
are independently rehashed before resuming. Failed attempts remain on disk and
cannot count as completed candidates.

The complete run resumes verified serial checkpoints with
`tools/resume_new_pair_geometry.py`, using two isolated native workers. Its
separate execution-driver SHA-256 is recorded in the final report; all native
production/installation checks and the original frozen recipe stay identical.
The interrupted attempt is retained and receives no checkpoint qualification.
GPU PNG comparisons run sequentially after the complete build.

```bash
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/study_new_pair_geometry.py audit \
  --sources /absolute/retained/model-release-v14/sources.json \
  --output .worktrees/slot-c/frontend/.tmp/new-pair-geometry-v1/audit

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/study_new_pair_geometry.py build \
  --sources /absolute/retained/model-release-v14/sources.json \
  --audit .worktrees/slot-c/frontend/.tmp/new-pair-geometry-v1/audit \
  --output .worktrees/slot-c/frontend/.tmp/new-pair-geometry-v1/build

# Optional: resume that same frozen complete build with two native workers.
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/resume_new_pair_geometry.py \
  --sources /absolute/retained/model-release-v14/sources.json \
  --audit .worktrees/slot-c/frontend/.tmp/new-pair-geometry-v1/audit \
  --output .worktrees/slot-c/frontend/.tmp/new-pair-geometry-v1/build

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/study_new_pair_geometry.py render \
  --sources /absolute/retained/model-release-v14/sources.json \
  --collection .worktrees/slot-c/frontend/.tmp/new-pair-geometry-v1/build \
  --output .worktrees/slot-c/frontend/.tmp/new-pair-geometry-v1/render
```

The default GPU selection spans four complete-pack size ranks. `--asset ID`
selects explicit controls; `--limit N` is build-only and a limited report never
claims full-cohort completion. Run unit checks from the frontend slot with
`python3 -m unittest discover -s tools -p test_study_new_pair_geometry.py`.
The final renderer command uses the no-audio wrapper with
`POKEAETHER_GEOMETRY_CLOCK_V2=1` and the frozen `render-v2/input.json`, writing
to `render-final`. This explicit final render uses the restored project and
slot environment, while audit/build use the diagnostic project lock. For a
fresh final render, put the wrapper on the task-local PATH as `godot`, set
`POKEAETHER_GEOMETRY_GODOT_BIN` to the actual Godot executable and run:

```bash
POKEAETHER_GEOMETRY_CLOCK_V2=1 /absolute/game/ops/worktrees/slot-env slot-c -- godot \
  --path /absolute/game/.worktrees/slot-c/frontend --rendering-method gl_compatibility \
  --resolution 640x480 --position -1600,-1600 \
  --log-file /absolute/game/.worktrees/slot-c/frontend/.tmp/final-render-engine.log \
  --script res://tools/sprite_factory/new_pair_geometry_render.gd -- \
  /absolute/game/.worktrees/slot-c/frontend/.tmp/new-pair-geometry-v1/render-v2/input.json \
  /absolute/game/.worktrees/slot-c/frontend/.tmp/new-pair-geometry-v1/render-final
```

Verify it from the frontend slot with:

```bash
python3 tools/check_new_pair_geometry_pixels.py \
  --directory .tmp/new-pair-geometry-v1/render-final \
  --input .tmp/new-pair-geometry-v1/render-v2/input.json \
  --output .tmp/new-pair-geometry-v1/gpu-receipt.json
python3 -m unittest discover -s tools -p test_new_pair_geometry_pixels.py
```

Reports, all 220 structural records, held track paths, candidate packs, fresh
installation objects, PNGs and logs remain under the assigned slot's
`.tmp/new-pair-geometry-v1*`; the compact committed receipt binds their hashes.
