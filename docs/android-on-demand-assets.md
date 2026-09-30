# Android on-demand assets

Android now keeps all native maps and the small HOME placeholder in the APK,
while HOME icons, normal Pokémon cries and the original login-world Theora video
load individually from the immutable browser asset release. Unused anime cries
are excluded. Desktop loading and browser trade restrictions are unchanged.

`MobileAssetService` reads the active `web-release-config.json`, then downloads
`web/releases/BUILD_ID/mobile-assets/catalog.json`. The manifest records exact
byte sizes and SHA-256 checksums for the existing `home-icons/` and
`browser-audio/assets/audio/sfx/pokemon_cries/` objects, plus
`login-media/world.ogv`. Browser MP4 playback remains unchanged; native playback
uses the original Theora file, preserving resolution, frame rate and quality.

The app-owned `user://mobile-assets-v1` cache has a 256 MiB payload limit. It
coalesces concurrent downloads, verifies checksums, commits completed files
atomically, removes corrupt files and evicts the least recently used unpinned
files. An active login video is pinned until the login screen exits. Immutable
battle sprite sheets and metadata use the same cache; their existing content
validation remains in place. A cached release configuration allows cached
assets to be used if refreshing the configuration fails. Music continues using
its existing persistent pack service.

HOME icons use mutable placeholders and load when visible. Cries are prefetched
with queued battle sprites; a slow first cry download is retained but not played
more than 1.5 seconds after the triggering action. The login form stays usable
while the video downloads and retains the existing static fallback on failure.
The video must finish downloading before native playback can begin.

## Building and release ordering

Before Android import/export, run `python3 tools/prepare_android_assets.py` to
create the bundled cry availability index. The Android workflow does this and
checks both the cache/media behavior and actual APK contents.

For a local asset review payload, run:

```sh
python3 tools/prepare_android_assets.py --asset-output builds/android-demand-assets
```

The normal web build now also prepares the native Theora file and mobile asset
manifest. `package_web_release.py` puts both in the immutable R2 payload. Publish
a matching web asset release before distributing an Android APK that relies on
it. No assets or APK are published by the preparation or check scripts.

Keep the current Android map files bundled. Browser map packs are exported for
a different target; using them on Android requires a separately verified native
pack pipeline and transition tests.

## Focused verification

Run Godot and local fixture checks through the assigned slot environment:

- `tests/mobile_asset_cache_check.gd`: restart, integrity, budget and pinned files.
- `tools/check_mobile_assets.py`: real loopback HTTP, coalescing, restart, failed
  responses, size limits and standalone Ogg/Theora decoding.
- `tools/check_android_demand_export.py FILE.apk` (or an Android-target PCK):
  verify that raw assets and their native imports are absent, while the
  placeholder, cry index and Route 5 remain available.

The same-source Android-target export comparison for this change measured
299.99 MiB before and 151.24 MiB after. These are uncompressed Godot PCK sizes,
not APK download sizes. A newly signed APK and physical-device testing remain
release checks; this workstation has no available Android SDK on its configured
paths or attached device tooling.
