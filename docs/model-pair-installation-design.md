# Proposed shared-texture installation contract

Status: local research design, **not enabled in the launcher or game**.
The v11 registry, index, publication receipts and exact decoded-stream gate stay
unchanged. A shared scene has a different stream and needs new reviewed
bindings; it cannot be silently admitted as a v11 compression variant.

## Format and identity

Use one immutable PCK per species/form pair. It contains normal/shiny scenes,
shared ImageTexture resources and a manifest. Different species remain
independent, so an encounter never needs the entire collection. Existing form
dependency planning still downloads the anticipated Mega/battle forms.

A new runtime contract must explicitly distinguish this format from v11 ZIPs.
Pin in the trusted release index:

- Asset ID/version, physical object key, complete PCK SHA-256 and byte count.
- Source/recipe namespace, e.g. `res://pokemon-pairs/<recipe-hash>/`. The recipe
  includes both approved source hashes and generator version. A PCK cannot
  contain its own hash in its paths; bind the namespace to its complete hash in
  the index instead.
- Each appearance's virtual scene path, file hash, existing placement/motion
  identity and newly qualified candidate binding.
- Exact file table and sizes/hashes of all scenes/textures. Only the two declared
  models, hash-named texture resources and manifest are permitted. No extra
  paths, duplicate paths, traversal, links or unrelated project files.
- Conservative dependency/cache byte accounting and decoded-resource bounds.

Keep materials, mesh buffers, animation tracks, effect data and image/mip bytes
unchanged. A full resource semantic comparison plus original/candidate rendered
controls qualifies each pair offline. Runtime integrity uses pinned hashes;
it does not repeatedly read GPU textures or compute semantic graphs in battles.

## Installation and mount order

1. Download to an owned staging file; verify length and full trusted PCK hash.
2. Validate its complete PCK file table **before mounting**. `override=false`
   alone is insufficient: a pack could otherwise add new unrelated virtual
   files. The experiment trusts its pinned, locally generated fixture and does
   not yet provide this production PCK table reader.
3. Publish the immutable file atomically in the local object store. Do not
   retain a second extracted copy of all resource payloads.
4. On demand, mount once per verified pack identity with overriding disabled.
   Verify the manifest, member hashes and closed dependency graph, then expose
   its two scenes to the presenter. Mounting and project resource APIs belong
   on the main thread; hashing/download/staging I/O belongs on workers.
5. Thread-load the requested scene. Shared resources use Godot's resource cache;
   no separate permanent Texture dictionary is needed.

Both installation paths need support. The launcher currently only accepts ZIP
keys (`launcher/scripts/asset_bundle_index.gd`) and extracts the manifest and
individual appearances (`asset_bundle_store.gd`). The game's independent
`scripts/services/on_demand_3d_bundle_service.gd` additionally requires exactly
three ZIP entries and writes normal/shiny loose files. Changing only the
launcher would leave on-demand encounters and previews on the old contract.
Prefer a shared, data-only manifest/table validator to divergent rules.

The runtime catalog needs physical `pack_path`/SHA/size, immutable virtual scene
path/hash, namespace and dependency budget. Availability, disk usage, cache
removal, form prefetch, review lookup and cleanup must understand physical packs
instead of treating a virtual `res://` path as a downloaded loose scene.

## Cache and update lifetime

The presenter's `_finish_validation` currently admits only self-contained scenes
to `model_resource_cache.gd`. Keep that guard for v11. For the new contract,
admit only a fully verified, closed pair; include **pack hash + namespace + scene
hash + action timing** in cache and render-warm identities.

Retain the existing **two-entry / 64 MiB source-budget LRU**. Charge scene bytes
and its texture dependencies conservatively (charging shared dependencies again
for each retained entry is safe initially). Do not account only the now-small
externalized scene. Also preserve the qualified original source admission floor
where needed. This budget measures source bytes, not decoded RAM or GPU memory.
Active/retiring actors own resources independently; after their departure and
LRU eviction, weak texture references must expire. Shiny must remain valid if
normal leaves first. Verify repeated encounters, switching and anticipated forms
with the real presenter, beyond this loader-only experiment.

Godot packs cannot generally be unmounted. Released textures do not release the
pack index. Mount only requested pairs, deduplicate repeated mounts and measure
metadata growth across many unique encounters. Never eagerly mount 1,200 pairs
just because the player downloaded them all.

Updates publish new immutable hashes/namespaces. A new battle snapshots the new
catalog; an existing battle finishes with its own resources. Keep mounted files
available until the process exits: removing or replacing an old PCK can break
later lazy reads, and Windows may retain file handles. Delete superseded files
on the next safe startup when no game owns them, rather than retaining model
history indefinitely. User-facing cache removal also needs this lifetime rule.

## Rollout gates

1. Broader exact-source cohort: separate codec savings from sharing, pixel and
   native loader checks, resource release and dependency closure.
2. Implement the new validator/store/catalog format behind a disabled pilot;
   negative table/path/hash tests, interruption/resume, low disk space, updates,
   cleanup and legacy fallback. Run both launcher and on-demand paths.
3. Integrate verified dependency-aware LRU admission and real battle/prefetch
   controls; measure mounted-index overhead and cache lifetime.
4. Windows/macOS install/load checks and Android ARM device qualification.
   Emulator checks establish portability, not phone performance or battery use.
5. Generate and qualify a new approved catalog/index; only then publish assets
   and a compatible release, with explicit release/upload authorization.

The collection's download/storage saving is useful on desktop too. Sharing does
not itself enable Android gameplay, and simultaneous normal/shiny texture
savings do not imply every single-appearance battle saves the same memory.
