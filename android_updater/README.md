# Android APK updater

The Android client checks `https://updates.pokeaether.com/manifest-android.json`
at startup. It offers a release only when `game.versionCode` is greater than
`application/config/android_version_code`. The APK is downloaded into private
`user://downloads`, checked against `sizeBytes` and SHA-256, and passed to
Android's system installer through Godot's `FileProvider`. Android can require
the player to allow installation from PokeAether and confirm the upgrade.

The release manifest contract is:

```json
{
  "game": {
    "buildId": "android-immutable-build-id",
    "version": "0.3.84",
    "versionCode": 2,
    "url": "https://updates.pokeaether.com/game/game-0.3.84-android.apk",
    "sizeBytes": 12345678,
    "sha256": "64 lowercase hex characters"
  }
}
```

`buildId` must equal the exported `application/config/build_id` used by the
gateway. `versionCode` must equal the Android export preset's `version/code` and
the exported `application/config/android_version_code`. Each release needs a
strictly higher code and the same package ID and signing key. Upload the
immutable APK, verify it on the server, and only then replace the manifest.
Publishing is a separate release operation.

The ignored `android/build` directory is generated from Godot 4.6.2's
`android_source.zip`. Before a Gradle export, run:

```sh
python3 android_updater/setup_build_template.py \
  /path/to/godot/export_templates/4.6.2.stable/android_source.zip
```

Use JDK 17 for the slot's Godot Android export setting. The script adds the
install permission and Java handoff to the generated template. Do not commit
the generated template, APKs, or signing credentials.

For an isolated phone test, a debug build may place
`http://127.0.0.1:PORT/manifest-android.json` in
`user://android_apk_manifest_url.txt` and use `adb reverse` to a local fixture
server. Release builds ignore this override.
