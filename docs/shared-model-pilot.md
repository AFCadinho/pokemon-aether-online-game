# Lossless shared-model installation pilot

Implemented locally in `development`, behind the disabled debug opt-in
`POKEAETHER_SHARED_MODEL_PILOT=1`. Normal releases still use the existing approved
v11 catalog. No public index, downloaded production model, publication receipt
or release descriptor has been replaced.

## Measured collection

The pilot contains the previously qualified 16 normal/shiny pairs: Pikachu,
Garchomp, Azumarill, Charizard, Arcanine, Magnemite, Palkia, Dondozo, Mega
Dragonite, Darmanitan Standard, Mega Diancie, Mega Greninja, Mega Zygarde, Mega
Golisopod, Articuno Galar and Moltres Galar. Its index retains ordinary Dragonite
as a v11 ZIP dependency of Mega Dragonite, so there are 17 index entries.

The 16 shared PCKs total **163,044,268 bytes**. Their actual v11 ZIPs total
268,580,204 bytes: **39.29% less transfer** in this cohort. The earlier
equal-codec controls total 210,429,184 bytes; sharing accounts for **22.52%**.
Mega Dragonite's formerly uncompressed scenes account for much of the extra
codec saving. Neither percentage is a measured saving for all 1,200 pairs.
Physical installation retains one pack plus a small metadata sidecar, rather
than an additional extracted copy of all scenes and textures.

Original archives are read in place and checked before/after derivation. Every
input matches its v11 decoded-stream binding. All 32 newly generated semantic
fingerprints match the original, qualified cohort. Authored images, mipmaps,
geometry, animations, material parameters and effects are preserved. Normal
and shiny remain separate scenes; only exactly matching textures are shared.

## Installation and runtime

`model_pair_pack.gd` is a data-only validator, duplicated byte-for-byte for the
independent game/launcher exports and checked for parity. Runtime contract 2
permits a new `model-pair-pck-v1` asset alongside legacy ZIP entries. v11's
contract 1 still rejects PCKs and externally dependent scenes.

Before mounting, the validator verifies the entire SHA-256, bounded standalone
Godot 4.6 PCK v3 header, flags, complete file table, namespace, unique paths,
non-overlapping ranges, every member's SHA-256/MD5, embedded manifest, native
codec and declared decoded sizes. Only two scenes, hash-named texture resources
and the manifest are allowed. No scripts, unrelated virtual paths, encryption,
patches, sparse packs or undeclared files are admitted. The PCK layout follows
Godot's [native reader](https://github.com/godotengine/godot/blob/4.6/core/io/file_access_pack.cpp)
and [packer](https://github.com/godotengine/godot/blob/4.6/core/io/pck_packer.cpp).

The launcher stages immutable packs transactionally, resumes completed objects,
and activates a complete generation atomically. The on-demand service has its
own installation path using the same validator. Hashing and copying run on
workers; mounts occur on the main thread. Only requested packs are mounted.
After mounting, external dependencies must close over declared textures in that
same namespace; unreferenced texture files are rejected. Repeated encounters
reuse the verified mount and dependency closure rather than mounting again.

The actual presenter verifies physical packs before and after threaded scene
loading. Only checked-in candidate/source bindings can obtain the original
reviewed placement and animation profiles. Cache keys include pack hash,
namespace, scene hash and timing. The existing two-entry / 64 MiB LRU remains;
each appearance is charged its scene plus texture dependencies and at least
its previously qualified original source cost. This is conservative admission,
not a decoded RAM/VRAM estimate.

Pokédex and inherited summary previews also verify packs on a worker before
mounting/loading, including canceled selections. Resource data is not hashed
back from the GPU in gameplay. Normal and shiny keep independent actors and
materials while their identical texture resources share ownership.

Mounted files remain available until process exit. Game leases protect launcher
objects; the on-demand service protects its mounted objects and defers cache
removal until restart, with a localized Settings explanation. A corrupt,
unmounted owned pack can be replaced after the replacement is fully staged and
verified. Unknown/linked object contents and packs currently in use are not
overwritten. Interrupted generations retain the previous active state.

## Focused validation

Host Godot 4.6.2, Linux, NVIDIA RTX 3070 Laptop; actual rendering uses Mobile
Vulkan. These are local checks, not complete release certification.

- All 16 pairs / 32 native scenes: complete source semantic equality, actual
  shared texture objects, independent shiny lifetime and expired texture weak
  references after both scenes leave.
- Both installation paths: exact checksums, unsafe header/flags/path/size
  rejection, partial transaction isolation, resumed installation, restart with
  no new downloads, verified corrupt-pack repair and deferred mounted cleanup.
- Actual launcher release adapter: pinned pilot descriptor, 16 PCK jobs plus
  one legacy dependency, installed handoff, reuse and unknown/disabled binding
  rejection. Existing v10 planning still validates all 1,200 bundles.
- Actual presenter: nine battle rounds across Pikachu, Charizard and Palkia;
  normal/shiny swaps, sleeping, one actor leaving, prepared scene reuse and the
  existing cache bounds. No captured engine/script errors.
- Pokédex and summary: eight normal/shiny previews and canceled asynchronous
  selection checks, with no captured engine/script errors.
- All 320 rendered candidate frames match an unchanged-original capture exactly:
  317 match the first source and three match its repeat-source control. Twenty-seven
  source/repeat-source frames vary even without rewriting; no tolerance is used.
  The three repeat-only matches are Garchomp front idle/physical attack and
  Darmanitan Standard front idle. This passes the existing source-or-repeat-source
  comparator, not a claim that every first-source frame is repeatable. Complete
  image receipts and failed attempts remain retained separately.

The first renewed render attempt exposed a stale diagnostic `ProbeSettings`
missing `is_android_3d_experimental()` after a later renderer change. That run
was stopped and retained. The fixture now explicitly returns false for the
desktop reference; camera, 512x512 resolution, MSAA4, lighting and pixel-equality
requirements are unchanged.

## Reproduction

From `game`, using an assigned frontend slot:

```sh
ops/worktrees/slot-env slot-a -- python3 .worktrees/slot-a/frontend/tools/prepare_shared_model_pairs.py \
  --archives .worktrees/slot-a/frontend/.tmp/lossless-catalog-v1/archives.json \
  --output .worktrees/slot-a/frontend/.tmp/FRESH-SHARED-PILOT
```

This prepares candidates and receipts, without registering them in a public
release. The checked-in game/launcher pilot metadata pins the measured pack
hashes. `POKEAETHER_MODEL_PAIR_PACKS=/absolute/pilot/packs` supplies local packs
to the explicitly enabled debug pilot; normal downloads do not use that path.

Run `shared_model_installation_check.gd`, `shared_model_battle_check.gd` and
`shared_model_preview_check.gd` from the frontend, and
`shared_model_release_check.gd` from the launcher, passing the absolute pack
directory after `--`. Run every Godot command through `slot-env`. Battle and
preview checks require a real renderer. The installation fixture also needs the
retained v11 dependency ZIPs under the slot's lossless preparation directory.

## Before production activation

The broader catalog still needs newly generated, reviewed candidate bindings
and a complete size/quality audit. Native Windows/macOS installation, update,
repair and cleanup checks remain; the previous Android cohort qualification
does not certify this new installer/presenter integration. Mounted index growth
across long sessions and interrupted replacement recovery need broader platform
qualification. There is no claimed FPS, physical phone RAM or all-catalog size
improvement from these local checks. Full paired certification, publication and
release promotion require their separate explicit authorization.
