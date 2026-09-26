# R2 update download retention

The `pokeaether-update-downloads` Worker preserves the six desktop `latest/`
download links plus the Android APK link on both update hostnames. It reads the
platform manifest directly from R2, checks that the immutable archive exists and
matches its size, then returns an uncached 302 redirect. Android's
`manifest-android.json` and immutable APK are served directly from the R2 custom
domain; `/game/latest/PokeAether-android.apk` redirects to that versioned APK.
The Worker only reads R2. There are no download ZIP copies under `game/latest/`
or `launcher/latest/` after migration.

Deploy the reviewed Worker with explicit Cloudflare deployment authorization:

```sh
npx wrangler deploy --config infrastructure/updates/wrangler.jsonc
python3 tools/verify_latest_download_redirects.py --remote
```

The deployment needs Workers script edit and route edit permissions for both
update zones. Do not remove legacy ZIP aliases until all twelve hostname/path
combinations return the expected redirect and the archive is reachable.

Desktop publication no longer uploads duplicate aliases. Its cleanup protects
every currently published game, asset and launcher reference, retaining one
older archive per family/platform. Browser cleanup runs only after successful
Pages verification and manifest publication. It protects both the manifest
build and the build in the live browser HTML, retaining one complete older
release bundle. A newer failed/uploading release cannot replace the older
rollback candidate. All cleanup retains uploads younger than 24 hours, ignores
unknown paths and browser sprite catalogs, defaults to dry-run, and refuses an
oversized deletion plan or changed active release.

Preview either plan with existing R2 environment variables; never print them:

```sh
python3 tools/prune_r2_release_objects.py builds/launcher
python3 tools/prune_r2_release_objects.py builds/web-r2 --scope web --max-delete 20000
```

The account storage goal is below 10,000,000,000 bytes, including backups and ML
datasets in other buckets. Retention bounds release history; it cannot guarantee
that goal if retained assets or other buckets grow. Measure all bucket object
sizes periodically and keep headroom. Backup and dataset retention is separate
and must not be changed by the release cleanup.

To roll back routing, first restore the six legacy ZIP objects from the current
immutable archives, verify them, then remove these four Worker routes. Keep the
current and previous immutable builds throughout migration.
