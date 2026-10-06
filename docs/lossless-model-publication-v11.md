# Smaller 3D collection publication

The desktop/launcher v0.3.100 publication selects `approved-pokemon-3d-v11`.
Its 1,200 bundles contain the same 2,400 approved normal/shiny appearances as
v10. Full collection transfer is 12,857,317,549 bytes instead of
19,863,374,075 bytes: 7,006,056,526 bytes less (35.27%). Decoded scene bytes,
model detail, textures, animations and battle profiles are unchanged.

## Publication evidence

`release/approved_3d_bundles_v11_r2_receipt.json` is the authority for completed
immutable publication. Every bundle and the content-addressed index must pass
full public GET SHA-256 and public HEAD size verification. The publisher checks
that the active desktop manifest did not change during that upload. Four
concurrent workers keep the upload bounded; any failed object prevents a
successful collection result and index activation. Existing matching immutable
objects can be reused after an interruption.

The receipt is committed before release certification. The desktop workflow is
then dispatched with `release_version=0.3.100`, `approved_3d_release=v11`,
`build_launcher=true` and `build_macos=true`. It rechecks the publication evidence
and public objects before producing and activating the manifests. macOS follows
the existing unsigned distribution policy.

The initial v0.3.99 desktop run stopped at the missing-publication guard. Its
successful retry deliberately selected v10. Model preparation and native
qualification did not themselves upload the production collection.

Browser and Android retain their v0.3.99 releases and 2D assets. Client version
enforcement resolves the platform's own manifest, so this desktop update does
not require rebuilding those clients or changing the backend.

The smaller figures describe the new download and active collection. Devices
may retain a previous installed generation for rollback; total disk usage does
not immediately drop by the full saved amount while both generations remain.

## Browser retention recovery

The browser cleanup after v0.3.99 refused a 41,752-object plan because its
normal safety limit is 20,000. The one-time recovery reviewed all 62,628 objects
under `web/releases/` in the dedicated `pokeaether-web` bucket and deleted only
four complete obsolete immutable release prefixes. It freed 2,083,928,009 bytes.

`release/browser_release_cleanup_20261006.json` records the completed Cloudflare
jobs and subsequent fully paginated verification. The active browser release
and previous complete release each retain all 10,438 objects and their original
total sizes. Both public release markers remain accessible. The browser and
Android update manifests remain byte-for-byte unchanged. Browser sprite
catalogs, desktop model objects and Pages deployments were not modified.

The normal workflow's 20,000-object guard remains in place. With the accumulated
backlog cleared, a normal one-release cleanup contains approximately 10,438
objects and fits that limit.

## Release test fixture

Certification encountered the mount-switch check's existing 180-second watchdog.
The fixture now captures each fresh target reference once and sets the origin
through the same live loadout callback used for the target. The character's
unchanged appearance is prepared once per gender. Immutable frame pixels are
read once per transition; all visibility, dimensions, pixels and resource-reuse
assertions remain. Coverage still includes 46 mounts, 4,232 origin/target
transitions across both genders, local and remote avatars, and all 20 direction,
idle and moving-frame samples per avatar. The watchdog remains 180 seconds.
