# Shared model texture runtime

The game and launcher now support a data-only `model-texture-pck-v1` archive
and model-pair manifest schema 3 under optional-asset runtime contract 3.
The active production release remains v15. The new nine-archive Minior pilot
is selected only in debug builds with
`POKEAETHER_SHARED_MODEL_TEXTURE_TEST=1`; its catalog is compiled separately
into both applications. No production revision, release pin or R2 object changes.

## Format and ownership

A schema-3 pair embeds the complete immutable metadata of each texture pack in
`pair_manifest.texture_pools` and lists its asset ID in `dependencies`. The
index requires those bindings to exactly equal its standalone texture assets.
Texture packs have no appearances or dependencies and may contain only bounded,
hash-bound native texture members. Current bounds are 127 files per pack and
16 packs per model pair. Schemas 1 and 2 retain their local dependency rules,
including the existing Dragonite Mega art prerequisite.

A runtime model entry adds `texture_packs`, mapping each required archive SHA
to its absolute installed path. Trusted pair metadata supplies the identities;
local entries cannot substitute a different archive or add dependencies.
`inspect_entry` checks the complete model archive and all required texture
archives. Its fresh receipts travel through the downloader, battle integrity
reader and existing Pokedex/summary preview. Before native resource loading,
`mount_checked` mounts only those exact verified packs and admits external scene
references only to their individually declared texture members. Leaves cannot
import further resources, and the previous namespace collision checks remain.

Portable textures retain their compressed buffers before their first load so
material and scene duplication preserve every texture. The existing bounded
resource LRU still owns at most two scenes and 64 MiB of source admission cost;
its per-scene budget conservatively adds every shared pack's archive size.
A pair's archive SHA binds the complete texture dependency metadata, so the
existing cache identity changes with a texture revision too. Mounted PCK files
remain protected until the process exits; resource eviction does not unmount
an archive.

## Installation and recovery

On-demand downloads use the index's dependency order and reuse an already
verified installed texture pack across later forms. A failed required download
cannot publish a ready model catalog. Corrupt dependencies fail the cached
readiness check and enter the existing immutable-object repair path. Repair of
mounted archives remains deferred until restart.

The launcher uses the same dependency-first collection staging. A generation
cannot activate unless all exact texture dependencies are installed; a pool
cannot be removed while an installed pair depends on it. Its generation
metadata also binds the texture paths passed to the game. Existing game leases
protect launcher archives during game use. Cleanup in the game preserves
texture archives referenced by surviving entries and rechecks them before
removing model history. Download counts continue to count model pairs rather
than their extra texture files.

## Focused qualification

The retained native checks use a newly handwritten isolated project, linked
source files and freshly generated imports, with fake local Settings and a
loopback HTTP fixture. There are no app autoloads, production requests or copied
caches/configuration. An alias for the substitute FBX's exporter-era texture
path is derived from the game's matching source PNG in this probe project.
The capture uses a classic arena; other arena changes are outside this task.

- Eight Minior pairs / 16 appearances reproduce the previously verified source
  scene graphs and all 420 animation samples exactly. Deep scene duplication
  remains exact.
- Both cold and fresh-process restart passes load eight actual battles and 16
  Pokedex/summary preview appearances. Captures show the expected normal and
  shiny models. The restart performs no HTTP requests.
- The loopback server rejects the first shared download with HTTP 503. No model
  catalog activates. The next download succeeds; one later deliberate pool
  corruption is detected and repaired. The pool is not downloaded again for
  the remaining forms.
- Launcher staging rejects a pair before its pool exists and exposes no partial
  generation. Installed pairs prevent pool removal. Its catalog is verified
  and reused by the game; the normal game lease prevents launcher cleanup.
- Substituting a model archive as a texture archive is rejected.
- All 27 distinct source texture paths leave the resource cache after actors,
  previews and the scene LRU are released. Mounted archives remain protected.
  The maximum observed LRU admission is 27,520,701 bytes for two scenes.
- Eight malformed binding/contract cases fail closed. The existing v15 binding
  check passes for all 1,420 pairs / 2,840 appearances, including v14 compatibility.
- Four adversarial native path-writer Python tests pass; UID sidecars and diff
  checks are also required at task completion.

The final receipt is `release/shared_texture_runtime_qualification.json`.
It binds source/driver hashes, all native reports, screenshots and the HTTP log.
It physically reopens the nine generated PCKs and records the final package
composition. Native qualification is Linux, Godot 4.6.2, GL Compatibility on
AMD Radeon Graphics. It is not a full collection/platform release certificate.

## Package size and next release

The schema-3 pilot's eight pair archives plus its texture pack total
9,085,588 bytes, including the new dependency metadata. Replacing only the eight
25,113,880-byte pairs in the previous 7,005,725,658-byte codec prototype gives
**6,989,697,366 bytes**, still below 7 decimal GB. This is a prototype package
composition, before building and qualifying a complete release catalog.

A production release must generate fresh namespaces, scene hashes and matching
compiled catalogs for the complete codec collection; qualify those actual
archives; and then freeze/certify the paired game/launcher release. Publication,
R2 upload and builds are separate authorized release work. Full-collection
Portable buffer memory and physical Android/Windows/macOS checks remain outside
this Linux pilot. No GPU-memory or full-process RAM saving is claimed.

## Reproduction

Read retained source evidence in place. Derive archives in the assigned slot:

```sh
ops/worktrees/slot-env slot-a -- python3 .worktrees/slot-a/frontend/tools/prepare_shared_texture_runtime_pilot.py \
  --output .worktrees/slot-a/frontend/.tmp/shared-texture-runtime-v1
ops/worktrees/slot-env slot-a -- python3 .worktrees/slot-a/frontend/tools/run_shared_texture_runtime_checks.py \
  --pilot .worktrees/slot-a/frontend/.tmp/shared-texture-runtime-v1/configuration.json \
  --output .worktrees/slot-a/frontend/.tmp/shared-texture-checks-final
```

Use fresh output directories; completed and interrupted evidence stays retained.
The generated catalog must match both checked-in pilot catalogs exactly.
