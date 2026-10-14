# Shared textures across forms: Minior prototype

This offline study builds a shared texture PCK and eight complete rewritten
Minior pair PCKs. It starts from the smallest complete candidates in the full
v15 texture audit. It changes no production loader, catalogs, launcher pins,
R2 objects or release configuration.

## Actual complete package sizes

| Measurement | Bytes |
| --- | ---: |
| Pinned v15 collection | 8,795,326,138 |
| Previous complete texture-codec prototype collection | 7,005,725,658 |
| Eight Minior pairs before sharing | 25,113,880 |
| Eight rewritten pairs **plus** their shared PCK | 9,059,828 |
| Shared PCK, already included above | 2,961,432 |
| Additional net saving | **16,054,052** |
| Combined prototype collection, with every other pair unchanged | **6,989,671,606** |
| Total saving from the same v15 collection | **1,805,654,532 (20.5297%)** |

This is 10,328,394 bytes below 7 decimal GB. It is a measured package
composition: the complete previous collection minus those eight selected
packs plus the eight actual rewritten packs and the actual pool. It includes
PCK tables, alignment and embedded manifests. It is not a production release
size or a projection from duplicate-payload totals. Future release catalog
objects, installation receipts and any additional format overhead are separate.

The pool contains 12 exact texture-state groups, replacing 79 texture members
across eight forms. Other textures remain specific to their form/appearance.
The tracked evidence is `release/shared_form_texture_study_v15.json`; its
private report and native evidence are retained in the assigned slot's
`.tmp/shared-form-texture-v2`. The independently run summarizer reopens all
17 packs (eight before, eight after, one pool), verifies their physical hashes,
member tables and content, and recomputes the totals.

## Preservation and admission

Each group uses the smallest existing texture payload with exactly the same
full decoded state: every image byte and authored mip, dimensions, format,
resource name, locality and metadata. No images are reencoded in this study.
Cold native probes compare every original texture reference against its
previously verified full-audit state.

Every pair receives a fresh namespace and binds the exact shared-pack SHA and
size. Scene hashes and embedded appearance records are updated. The narrowly
scoped native writer changes only equal-length external resource path strings
in Godot 4.6 binary v6. It preserves external types, invalid UID sentinels,
internal offsets and every resource body byte. Unsupported layouts, named
UIDs, unbound dependencies and path-size changes fail closed. Unchanged leaves
also retain their exact compressed bytes.

The private probe accepts only the individually pinned pool members and each
pair's exact local closure. The production pair loader rejects the pool and
rejects the external-pool dependency in all eight rewritten pairs. There is
no relaxation of production admission.

## Native results

Godot 4.6.2, actual Linux GL Compatibility renderer, AMD Radeon Graphics:

- All 16 normal/shiny scene graphs match the before-sharing graphs exactly,
  including materials and decoded textures.
- All 420 animation samples, including RESET, match at fractions 0, 0.5 and 0.999.
- Every texture and PackedScene passes deep duplication with exact state.
- Sixteen simultaneous actors contain 158 references to the same pooled
  texture objects; scene-local material mutation remains isolated.
- Freeing one actor preserves the surviving actors' textures and pose.
- All 12 pooled resources leave the ResourceLoader cache after all owners are
  dropped; weak references become null. Reloading every texture and complete
  model reproduces the original states and animation samples.
- A fresh process repeats those checks with all eight packs loaded in reverse
  order. Both runs reject the eight pair dependencies in the production loader.

The probe enables `set_keep_all_compressed_buffers(true)` before any texture
load. The pooled Portable textures retain 2,952,400 codec-buffer bytes in this
configuration. This is only a pool buffer measurement, not total process RAM,
GPU memory, or a production cache measurement.

Four adversarial Python tests cover body/metadata preservation, UID redirect
rejection, unbound/unequal-size paths and malformed versions/offsets. Native
source, cold and restart runs and the independent physical summary passed.
The retained first attempt's reverse-order ownership test assumed its first
form had a scene-local material; that assumption was corrected to select an
actual eligible material in the group. Only the completed second attempt is
bound as successful evidence.

## Next qualification

This proves a small shared-texture composition can cross below 7 GB without
changing the tested resources. Production still needs a versioned dependency
format and game/launcher admission, installation/download ownership and repair,
actual battle/Pokedex/summary presenter and cache-eviction tests, and memory
measurements for the full Portable texture runtime. Linux is the tested
platform; this study does not certify Windows, macOS or physical Android.
Do not upload these private packs as replacements for the current revision.

## Reproduction

Read retained full-audit packs in place; generate outputs only in an assigned
slot. No existing project configuration, assets, caches or logs are copied.
The driver creates a new handwritten minimal project with source-script links.
A fresh output directory is required; interrupted attempts remain retained.

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/study_shared_form_textures.py \
  --output .worktrees/slot-c/frontend/.tmp/shared-form-texture-v2
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/summarize_shared_form_textures.py \
  --study .worktrees/slot-c/frontend/.tmp/shared-form-texture-v2 \
  --output .worktrees/slot-c/frontend/release/shared_form_texture_study_v15.json
```
